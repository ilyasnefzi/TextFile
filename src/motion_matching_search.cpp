#include "motion_matching_search.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <limits>
#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;


// ==================================================
// CONFIGURATION
// ==================================================

static constexpr double TRAJECTORY_WEIGHT = 2.0;
static constexpr double FACING_WEIGHT = 2.0;
static constexpr double ROTATION_WEIGHT = 2.0;

static constexpr double FUTURE_TIMES[3] = {
    0.2,
    0.4,
    0.6
};

static const Vector3 UP_AXIS(0.0, 1.0, 0.0);


// ==================================================
// QUATERNION DATA
// ==================================================

struct QuaternionData {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    double w = 1.0;
};


// ==================================================
// ANIMATION ELIGIBILITY
// ==================================================

static bool has_tag(
    const std::vector<String> &tags,
    const String &target
) {
    for (const String &tag : tags) {
        if (tag == target) {
            return true;
        }
    }

    return false;
}


static bool is_steady_locomotion_eligible(
    const std::vector<String> &tags
) {
    bool supported_family =
        has_tag(tags, "locomotion_walk") ||
        has_tag(tags, "locomotion_run") ||
        has_tag(tags, "locomotion_sprint");

    if (!supported_family) {
        return false;
    }

    static const char *excluded_tags[] = {
        "start",
        "stop",
        "pivot",
        "turn",
        "reface",
        "shuffle",
        "spin",
        "transition",
        "arc"
    };

    for (const char *excluded_tag : excluded_tags) {
        if (has_tag(tags, String(excluded_tag))) {
            return false;
        }
    }

    return true;
}


// ==================================================
// CONSTRUCTOR
// ==================================================

MotionMatchingSearch::MotionMatchingSearch() {
}


// ==================================================
// VELOCITY COST
// ==================================================

double MotionMatchingSearch::calculate_cost(
    Vector3 current_velocity,
    Vector3 desired_velocity
) {
    return current_velocity.distance_squared_to(
        desired_velocity
    );
}


// ==================================================
// ANGLE UTILITIES
// ==================================================

static double wrap_angle(double angle) {
    return std::atan2(
        std::sin(angle),
        std::cos(angle)
    );
}


static double interpolate_angle(
    double from,
    double to,
    double alpha
) {
    double difference = wrap_angle(to - from);

    return wrap_angle(
        from + difference * alpha
    );
}


// ==================================================
// QUATERNION NORMALIZATION
// ==================================================

static QuaternionData normalize_quaternion(
    const QuaternionData &q
) {
    double length_squared =
        q.x * q.x +
        q.y * q.y +
        q.z * q.z +
        q.w * q.w;

    if (length_squared < 0.000001) {
        return QuaternionData();
    }

    double inverse_length = 1.0 / std::sqrt(length_squared);

    QuaternionData result;

    result.x = q.x * inverse_length;
    result.y = q.y * inverse_length;
    result.z = q.z * inverse_length;
    result.w = q.w * inverse_length;

    return result;
}


// ==================================================
// QUATERNION MULTIPLICATION
// ==================================================

static QuaternionData multiply_quaternions(
    const QuaternionData &a,
    const QuaternionData &b
) {
    QuaternionData result;

    result.x =
        a.w * b.x +
        a.x * b.w +
        a.y * b.z -
        a.z * b.y;

    result.y =
        a.w * b.y -
        a.x * b.z +
        a.y * b.w +
        a.z * b.x;

    result.z =
        a.w * b.z +
        a.x * b.y -
        a.y * b.x +
        a.z * b.w;

    result.w =
        a.w * b.w -
        a.x * b.x -
        a.y * b.y -
        a.z * b.z;

    return result;
}


// ==================================================
// QUATERNION INVERSE
// ==================================================

static QuaternionData inverse_quaternion(
    const QuaternionData &q
) {
    QuaternionData result;

    result.x = -q.x;
    result.y = -q.y;
    result.z = -q.z;
    result.w = q.w;

    return result;
}


// ==================================================
// PARSE QUATERNION FROM JSON
// Format: [x, y, z, w]
// ==================================================

static QuaternionData parse_quaternion(
    const Variant &value
) {
    if (value.get_type() != Variant::ARRAY) {
        return QuaternionData();
    }

    Array values = value;

    if (values.size() < 4) {
        return QuaternionData();
    }

    QuaternionData result;

    result.x = (double)values[0];
    result.y = (double)values[1];
    result.z = (double)values[2];
    result.w = (double)values[3];

    return normalize_quaternion(result);
}


// ==================================================
// CONVERT RELATIVE ROTATION INTO PARENT SPACE
// ==================================================

static QuaternionData convert_rotation_to_parent_space(
    const QuaternionData &initial_rotation,
    const QuaternionData &relative_rotation
) {
    QuaternionData first = multiply_quaternions(
        initial_rotation,
        relative_rotation
    );

    QuaternionData inverse_initial = inverse_quaternion(
        initial_rotation
    );

    QuaternionData result = multiply_quaternions(
        first,
        inverse_initial
    );

    return normalize_quaternion(result);
}


// ==================================================
// EXTRACT PARENT-SPACE YAW
// ==================================================

static double extract_parent_yaw(
    const QuaternionData &q
) {
    double sin_yaw =
        2.0 * (q.w * q.y + q.x * q.z);

    double cos_yaw =
        1.0 - 2.0 * (q.y * q.y + q.x * q.x);

    return std::atan2(
        sin_yaw,
        cos_yaw
    );
}


// ==================================================
// PARSE VECTOR3
// ==================================================

static Vector3 parse_vector3(const Variant &value) {
    if (value.get_type() != Variant::ARRAY) {
        return Vector3();
    }

    Array values = value;

    if (values.size() < 3) {
        return Vector3();
    }

    return Vector3(
        (double)values[0],
        (double)values[1],
        (double)values[2]
    );
}


// ==================================================
// CONVERT VECTOR INTO SAMPLE FACING SPACE
// ==================================================

static Vector3 to_local_facing(
    const Vector3 &vector,
    double yaw
) {
    return vector.rotated(
        UP_AXIS,
        -yaw
    );
}


// ==================================================
// POSITION INTERPOLATION
// ==================================================

bool MotionMatchingSearch::interpolate_position(
    const std::vector<MotionSample> &samples,
    double time,
    Vector3 &result
) const {
    if (samples.empty()) {
        return false;
    }

    if (
        time < samples.front().time - 0.000001 ||
        time > samples.back().time + 0.000001
    ) {
        return false;
    }

    auto it = std::lower_bound(
        samples.begin(),
        samples.end(),
        time,
        [](const MotionSample &sample, double target) {
            return sample.time < target;
        }
    );

    if (it == samples.end()) {
        result = samples.back().position;
        return true;
    }

    if (it == samples.begin()) {
        result = it->position;
        return true;
    }

    if (std::abs(it->time - time) < 0.000001) {
        result = it->position;
        return true;
    }

    const MotionSample &next = *it;
    const MotionSample &previous = *(it - 1);

    double interval = next.time - previous.time;

    if (interval <= 0.0) {
        return false;
    }

    double alpha = (time - previous.time) / interval;

    result = previous.position.lerp(
        next.position,
        alpha
    );

    return true;
}


// ==================================================
// YAW INTERPOLATION
// ==================================================

template <typename SampleContainer>
static bool interpolate_yaw(
    const SampleContainer &samples,
    double time,
    double &result
) {
    if (samples.empty()) {
        return false;
    }

    if (
        time < samples.front().time - 0.000001 ||
        time > samples.back().time + 0.000001
    ) {
        return false;
    }

    size_t low = 0;
    size_t high = samples.size();

    while (low < high) {
        size_t middle = low + (high - low) / 2;

        if (samples[middle].time < time) {
            low = middle + 1;
        }
        else {
            high = middle;
        }
    }

    if (low >= samples.size()) {
        result = samples.back().yaw;
        return true;
    }

    if (low == 0) {
        result = samples.front().yaw;
        return true;
    }

    const auto &next = samples[low];
    const auto &previous = samples[low - 1];

    if (std::abs(next.time - time) < 0.000001) {
        result = next.yaw;
        return true;
    }

    double interval = next.time - previous.time;

    if (interval <= 0.0) {
        return false;
    }

    double alpha = (time - previous.time) / interval;

    result = interpolate_angle(
        previous.yaw,
        next.yaw,
        alpha
    );

    return true;
}


// ==================================================
// DATABASE LOADER
// ==================================================

bool MotionMatchingSearch::load_database(String file_path) {

    database.clear();

    total_samples = 0;
    valid_search_samples = 0;

    eligible_animation_count = 0;
    eligible_search_samples = 0;

    last_error = "";

    if (!FileAccess::file_exists(file_path)) {
        last_error = "Database file does not exist: " + file_path;
        return false;
    }

    String json_text = FileAccess::get_file_as_string(file_path);

    if (json_text.is_empty()) {
        last_error = "Database file is empty.";
        return false;
    }

    Variant parsed_data = JSON::parse_string(json_text);

    if (parsed_data.get_type() != Variant::ARRAY) {
        last_error = "Invalid database format. Expected a JSON array.";
        return false;
    }

    Array animations = parsed_data;

    // ----------------------------------------------
    // LOAD ANIMATIONS
    // ----------------------------------------------

    for (int i = 0; i < animations.size(); i++) {

        Variant animation_value = animations[i];

        if (animation_value.get_type() != Variant::DICTIONARY) {
            continue;
        }

        Dictionary animation_data = animation_value;

        MotionAnimation animation;

        animation.name = animation_data.get(
            "name",
            String("Unknown")
        );

        animation.duration = animation_data.get(
            "duration",
            0.0
        );

        Variant tags_value = animation_data.get(
            "tags",
            Array()
        );

        if (tags_value.get_type() == Variant::ARRAY) {

            Array tags_array = tags_value;

            for (int tag_index = 0; tag_index < tags_array.size(); tag_index++) {

                if (tags_array[tag_index].get_type() == Variant::STRING) {
                    animation.tags.push_back(
                        (String)tags_array[tag_index]
                    );
                }
            }
        }

        animation.eligible_steady_locomotion =
            is_steady_locomotion_eligible(animation.tags);

        if (animation.eligible_steady_locomotion) {
            eligible_animation_count++;
        }

        QuaternionData initial_rotation = parse_quaternion(
            animation_data.get(
                "root_initial_rotation",
                Array()
            )
        );

        Variant samples_value = animation_data.get(
            "trajectory_samples",
            Array()
        );

        if (samples_value.get_type() != Variant::ARRAY) {
            continue;
        }

        Array samples = samples_value;

        for (int j = 0; j < samples.size(); j++) {

            Variant sample_value = samples[j];

            if (sample_value.get_type() != Variant::DICTIONARY) {
                continue;
            }

            Dictionary sample_data = sample_value;

            MotionSample sample;

            sample.time = sample_data.get(
                "time",
                0.0
            );

            sample.position = parse_vector3(
                sample_data.get("position", Array())
            );

            sample.velocity = parse_vector3(
                sample_data.get("velocity", Array())
            );

            QuaternionData relative_rotation = parse_quaternion(
                sample_data.get("rotation", Array())
            );

            QuaternionData parent_rotation =
                convert_rotation_to_parent_space(
                    initial_rotation,
                    relative_rotation
                );

            sample.yaw = extract_parent_yaw(
                parent_rotation
            );

            animation.samples.push_back(sample);

            total_samples++;
        }

        if (!animation.samples.empty()) {
            database.push_back(animation);
        }
    }

    if (database.empty()) {
        last_error = "No valid animations were loaded.";
        return false;
    }

    // ----------------------------------------------
    // PRECOMPUTE LOCAL-FACING FEATURES
    // ----------------------------------------------

    valid_search_samples = 0;
    eligible_search_samples = 0;

    for (MotionAnimation &animation : database) {

        for (MotionSample &sample : animation.samples) {

            sample.matching_velocity = to_local_facing(
                sample.velocity,
                sample.yaw
            );

            bool valid_trajectory = true;
            bool valid_rotation = true;

            for (int future_index = 0; future_index < 3; future_index++) {

                double future_time =
                    sample.time + FUTURE_TIMES[future_index];

                Vector3 future_position;

                if (!interpolate_position(
                    animation.samples,
                    future_time,
                    future_position
                )) {
                    valid_trajectory = false;
                }
                else {

                    Vector3 displacement =
                        future_position - sample.position;

                    sample.future_positions[future_index] =
                        to_local_facing(
                            displacement,
                            sample.yaw
                        );
                }

                double future_yaw = 0.0;

                if (!interpolate_yaw(
                    animation.samples,
                    future_time,
                    future_yaw
                )) {
                    valid_rotation = false;
                }
                else {

                    sample.future_yaw_deltas[future_index] =
                        wrap_angle(
                            future_yaw - sample.yaw
                        );
                }
            }

            sample.has_future_trajectory = valid_trajectory;
            sample.has_future_rotation = valid_rotation;

            if (valid_trajectory && valid_rotation) {

                valid_search_samples++;

                if (animation.eligible_steady_locomotion) {
                    eligible_search_samples++;
                }
            }
        }
    }

    return true;
}


// ==================================================
// TOP-10 MOTION MATCHING SEARCH
// ==================================================

Dictionary MotionMatchingSearch::search_best_match(
    Vector3 desired_velocity,
    Array desired_future_positions,
    double desired_facing_yaw
) {

    Dictionary result;

    if (database.empty()) {
        result["success"] = false;
        result["error"] = "Database has not been loaded.";
        return result;
    }

    if (desired_future_positions.size() != 3) {
        result["success"] = false;
        result["error"] = "Expected exactly 3 future trajectory positions.";
        return result;
    }

    std::array<Vector3, 3> desired_positions;

    for (int i = 0; i < 3; i++) {

        Variant value = desired_future_positions[i];

        if (value.get_type() != Variant::VECTOR3) {
            result["success"] = false;
            result["error"] = "Future trajectory positions must be Vector3 values.";
            return result;
        }

        desired_positions[i] = value;
    }

    const std::array<double, 3> desired_yaw_deltas = {
        0.0,
        0.0,
        0.0
    };

    struct Candidate {

        double total_cost = 0.0;
        double velocity_cost = 0.0;
        double trajectory_cost = 0.0;
        double facing_cost = 0.0;
        double rotation_cost = 0.0;

        int animation_index = -1;
        int sample_index = -1;

        double time = 0.0;
        double yaw = 0.0;

        Vector3 position;
        Vector3 raw_velocity;
        Vector3 matching_velocity;

        std::array<Vector3, 3> future_positions;
        std::array<double, 3> future_yaw_deltas;
    };

    std::vector<Candidate> candidates;

    int evaluated_samples = 0;

    // ----------------------------------------------
    // SEARCH DATABASE
    // ----------------------------------------------

    for (
        int animation_index = 0;
        animation_index < (int)database.size();
        animation_index++
    ) {

        const MotionAnimation &animation =
            database[animation_index];

        if (!animation.eligible_steady_locomotion) {
            continue;
        }

        for (
            int sample_index = 0;
            sample_index < (int)animation.samples.size();
            sample_index++
        ) {

            const MotionSample &sample =
                animation.samples[sample_index];

            if (
                !sample.has_future_trajectory ||
                !sample.has_future_rotation
            ) {
                continue;
            }

            evaluated_samples++;

            double velocity_cost = calculate_cost(
                sample.matching_velocity,
                desired_velocity
            );

            double trajectory_cost = 0.0;

            for (int i = 0; i < 3; i++) {
                trajectory_cost +=
                    sample.future_positions[i].distance_squared_to(
                        desired_positions[i]
                    );
            }

            double facing_difference = wrap_angle(
                sample.yaw - desired_facing_yaw
            );

            double facing_cost =
                facing_difference * facing_difference;

            double rotation_cost = 0.0;

            for (int i = 0; i < 3; i++) {

                double yaw_difference = wrap_angle(
                    sample.future_yaw_deltas[i] -
                    desired_yaw_deltas[i]
                );

                rotation_cost +=
                    yaw_difference * yaw_difference;
            }

            double total_cost =
                velocity_cost +
                trajectory_cost * TRAJECTORY_WEIGHT +
                facing_cost * FACING_WEIGHT +
                rotation_cost * ROTATION_WEIGHT;

            Candidate candidate;

            candidate.total_cost = total_cost;
            candidate.velocity_cost = velocity_cost;
            candidate.trajectory_cost = trajectory_cost;
            candidate.facing_cost = facing_cost;
            candidate.rotation_cost = rotation_cost;

            candidate.animation_index = animation_index;
            candidate.sample_index = sample_index;

            candidate.time = sample.time;
            candidate.yaw = sample.yaw;

            candidate.position = sample.position;
            candidate.raw_velocity = sample.velocity;
            candidate.matching_velocity = sample.matching_velocity;

            candidate.future_positions = sample.future_positions;
            candidate.future_yaw_deltas = sample.future_yaw_deltas;

            candidates.push_back(candidate);
        }
    }

    std::sort(
        candidates.begin(),
        candidates.end(),
        [](const Candidate &a, const Candidate &b) {
            return a.total_cost < b.total_cost;
        }
    );

    if (candidates.empty()) {
        result["success"] = false;
        result["error"] = "No eligible steady locomotion samples found.";
        result["eligible_animations"] = eligible_animation_count;
        result["eligible_samples"] = eligible_search_samples;
        return result;
    }

    // ----------------------------------------------
    // BUILD TOP 10 RESULTS
    // ----------------------------------------------

    Array top_matches;

    int result_count = std::min(
        10,
        (int)candidates.size()
    );

    for (int i = 0; i < result_count; i++) {

        const Candidate &candidate = candidates[i];

        const MotionAnimation &animation =
            database[candidate.animation_index];

        Dictionary match;

        match["rank"] = i + 1;
        match["animation_name"] = animation.name;
        match["animation_index"] = candidate.animation_index;
        match["sample_index"] = candidate.sample_index;
        match["time"] = candidate.time;
        match["duration"] = animation.duration;
        match["position"] = candidate.position;
        match["yaw"] = candidate.yaw;
        match["yaw_degrees"] = Math::rad_to_deg(candidate.yaw);
        match["raw_velocity"] = candidate.raw_velocity;
        match["velocity"] = candidate.matching_velocity;

        Array future_positions;
        Array future_yaw_deltas;

        for (int j = 0; j < 3; j++) {

            future_positions.push_back(
                candidate.future_positions[j]
            );

            future_yaw_deltas.push_back(
                Math::rad_to_deg(
                    candidate.future_yaw_deltas[j]
                )
            );
        }

        match["future_positions"] = future_positions;
        match["future_yaw_deltas_degrees"] = future_yaw_deltas;

        match["velocity_cost"] = candidate.velocity_cost;
        match["trajectory_cost"] = candidate.trajectory_cost;
        match["facing_cost"] = candidate.facing_cost;
        match["rotation_cost"] = candidate.rotation_cost;
        match["cost"] = candidate.total_cost;

        top_matches.push_back(match);
    }

    // ----------------------------------------------
    // BEST MATCH
    // ----------------------------------------------

    const Candidate &best = candidates.front();

    const MotionAnimation &best_animation =
        database[best.animation_index];

    result["success"] = true;
    result["animation_name"] = best_animation.name;
    result["animation_index"] = best.animation_index;
    result["sample_index"] = best.sample_index;
    result["time"] = best.time;
    result["duration"] = best_animation.duration;
    result["position"] = best.position;
    result["raw_velocity"] = best.raw_velocity;
    result["velocity"] = best.matching_velocity;
    result["yaw"] = best.yaw;
    result["yaw_degrees"] = Math::rad_to_deg(best.yaw);

    result["desired_facing_yaw_degrees"] =
        Math::rad_to_deg(desired_facing_yaw);

    result["velocity_cost"] = best.velocity_cost;
    result["trajectory_cost"] = best.trajectory_cost;
    result["facing_cost"] = best.facing_cost;
    result["rotation_cost"] = best.rotation_cost;
    result["cost"] = best.total_cost;

    result["samples_evaluated"] = evaluated_samples;
    result["valid_database_samples"] = valid_search_samples;
    result["eligible_animations"] = eligible_animation_count;
    result["eligible_samples"] = eligible_search_samples;
    result["top_matches"] = top_matches;

    Array best_future_yaw_deltas;

    for (int i = 0; i < 3; i++) {
        best_future_yaw_deltas.push_back(
            Math::rad_to_deg(
                best.future_yaw_deltas[i]
            )
        );
    }

    result["future_yaw_deltas_degrees"] =
        best_future_yaw_deltas;

    return result;
}


// ==================================================
// CONTINUITY-AWARE MOTION MATCHING SEARCH
// ==================================================

static double continuity_time_distance(double candidate_time, double current_time, double duration) {
    if (duration <= 0.000001) return std::abs(candidate_time - current_time);
    double difference = std::fmod(std::abs(candidate_time - current_time), duration);
    return std::min(difference, duration - difference);
}

Dictionary MotionMatchingSearch::search_best_match_continuous(
    Vector3 desired_velocity,
    Array desired_future_positions,
    double desired_facing_yaw,
    int current_animation_index,
    double current_animation_time,
    double animation_switch_penalty,
    double same_animation_time_weight
) {
    Dictionary result;
    if (database.empty()) {
        result["success"] = false;
        result["error"] = "Database has not been loaded.";
        return result;
    }
    if (desired_future_positions.size() != 3) {
        result["success"] = false;
        result["error"] = "Expected exactly 3 future trajectory positions.";
        return result;
    }

    std::array<Vector3, 3> desired_positions;
    for (int i = 0; i < 3; i++) {
        Variant value = desired_future_positions[i];
        if (value.get_type() != Variant::VECTOR3) {
            result["success"] = false;
            result["error"] = "Future trajectory positions must be Vector3 values.";
            return result;
        }
        desired_positions[i] = value;
    }

    struct Candidate {
        double selection_score = 0.0;
        double base_cost = 0.0;
        double continuity_cost = 0.0;
        double velocity_cost = 0.0;
        double trajectory_cost = 0.0;
        double facing_cost = 0.0;
        double rotation_cost = 0.0;
        int animation_index = -1;
        int sample_index = -1;
        double time = 0.0;
        double yaw = 0.0;
        Vector3 position;
        Vector3 raw_velocity;
        Vector3 matching_velocity;
        std::array<Vector3, 3> future_positions;
        std::array<double, 3> future_yaw_deltas;
    };

    std::vector<Candidate> candidates;
    int evaluated_samples = 0;
    const bool has_current_animation =
        current_animation_index >= 0 &&
        current_animation_index < (int)database.size();

    for (int animation_index = 0; animation_index < (int)database.size(); animation_index++) {
        const MotionAnimation &animation = database[animation_index];
        if (!animation.eligible_steady_locomotion) continue;

        for (int sample_index = 0; sample_index < (int)animation.samples.size(); sample_index++) {
            const MotionSample &sample = animation.samples[sample_index];
            if (!sample.has_future_trajectory || !sample.has_future_rotation) continue;
            evaluated_samples++;

            const double velocity_cost = calculate_cost(sample.matching_velocity, desired_velocity);
            double trajectory_cost = 0.0;
            for (int i = 0; i < 3; i++) {
                trajectory_cost += sample.future_positions[i].distance_squared_to(desired_positions[i]);
            }

            const double facing_difference = wrap_angle(sample.yaw - desired_facing_yaw);
            const double facing_cost = facing_difference * facing_difference;
            double rotation_cost = 0.0;
            for (int i = 0; i < 3; i++) {
                const double yaw_difference = wrap_angle(sample.future_yaw_deltas[i]);
                rotation_cost += yaw_difference * yaw_difference;
            }

            const double base_cost =
                velocity_cost +
                trajectory_cost * TRAJECTORY_WEIGHT +
                facing_cost * FACING_WEIGHT +
                rotation_cost * ROTATION_WEIGHT;

            double continuity_cost = 0.0;
            if (has_current_animation) {
                if (animation_index == current_animation_index) {
                    const double time_distance = continuity_time_distance(
                        sample.time, current_animation_time, animation.duration
                    );
                    continuity_cost = time_distance * time_distance *
                        std::max(0.0, same_animation_time_weight);
                } else {
                    continuity_cost = std::max(0.0, animation_switch_penalty);
                }
            }

            Candidate candidate;
            candidate.selection_score = base_cost + continuity_cost;
            candidate.base_cost = base_cost;
            candidate.continuity_cost = continuity_cost;
            candidate.velocity_cost = velocity_cost;
            candidate.trajectory_cost = trajectory_cost;
            candidate.facing_cost = facing_cost;
            candidate.rotation_cost = rotation_cost;
            candidate.animation_index = animation_index;
            candidate.sample_index = sample_index;
            candidate.time = sample.time;
            candidate.yaw = sample.yaw;
            candidate.position = sample.position;
            candidate.raw_velocity = sample.velocity;
            candidate.matching_velocity = sample.matching_velocity;
            candidate.future_positions = sample.future_positions;
            candidate.future_yaw_deltas = sample.future_yaw_deltas;
            candidates.push_back(candidate);
        }
    }

    if (candidates.empty()) {
        result["success"] = false;
        result["error"] = "No eligible steady locomotion samples found.";
        result["eligible_animations"] = eligible_animation_count;
        result["eligible_samples"] = eligible_search_samples;
        return result;
    }

    std::sort(candidates.begin(), candidates.end(),
        [](const Candidate &a, const Candidate &b) {
            return a.selection_score < b.selection_score;
        });

    Array top_matches;
    const int result_count = std::min(10, (int)candidates.size());
    for (int i = 0; i < result_count; i++) {
        const Candidate &candidate = candidates[i];
        const MotionAnimation &animation = database[candidate.animation_index];
        Dictionary match;
        match["rank"] = i + 1;
        match["animation_name"] = animation.name;
        match["animation_index"] = candidate.animation_index;
        match["sample_index"] = candidate.sample_index;
        match["time"] = candidate.time;
        match["duration"] = animation.duration;
        match["position"] = candidate.position;
        match["yaw"] = candidate.yaw;
        match["yaw_degrees"] = Math::rad_to_deg(candidate.yaw);
        match["raw_velocity"] = candidate.raw_velocity;
        match["velocity"] = candidate.matching_velocity;
        Array future_positions;
        Array future_yaw_deltas;
        for (int j = 0; j < 3; j++) {
            future_positions.push_back(candidate.future_positions[j]);
            future_yaw_deltas.push_back(Math::rad_to_deg(candidate.future_yaw_deltas[j]));
        }
        match["future_positions"] = future_positions;
        match["future_yaw_deltas_degrees"] = future_yaw_deltas;
        match["velocity_cost"] = candidate.velocity_cost;
        match["trajectory_cost"] = candidate.trajectory_cost;
        match["facing_cost"] = candidate.facing_cost;
        match["rotation_cost"] = candidate.rotation_cost;
        match["base_cost"] = candidate.base_cost;
        match["continuity_cost"] = candidate.continuity_cost;
        match["selection_score"] = candidate.selection_score;
        match["cost"] = candidate.selection_score;
        top_matches.push_back(match);
    }

    const Candidate &best = candidates.front();
    const MotionAnimation &best_animation = database[best.animation_index];
    result["success"] = true;
    result["animation_name"] = best_animation.name;
    result["animation_index"] = best.animation_index;
    result["sample_index"] = best.sample_index;
    result["time"] = best.time;
    result["duration"] = best_animation.duration;
    result["position"] = best.position;
    result["raw_velocity"] = best.raw_velocity;
    result["velocity"] = best.matching_velocity;
    result["yaw"] = best.yaw;
    result["yaw_degrees"] = Math::rad_to_deg(best.yaw);
    result["desired_facing_yaw_degrees"] = Math::rad_to_deg(desired_facing_yaw);
    result["velocity_cost"] = best.velocity_cost;
    result["trajectory_cost"] = best.trajectory_cost;
    result["facing_cost"] = best.facing_cost;
    result["rotation_cost"] = best.rotation_cost;
    result["base_cost"] = best.base_cost;
    result["continuity_cost"] = best.continuity_cost;
    result["selection_score"] = best.selection_score;
    result["cost"] = best.selection_score;
    result["samples_evaluated"] = evaluated_samples;
    result["valid_database_samples"] = valid_search_samples;
    result["eligible_animations"] = eligible_animation_count;
    result["eligible_samples"] = eligible_search_samples;
    result["current_animation_index"] = current_animation_index;
    result["current_animation_time"] = current_animation_time;
    result["top_matches"] = top_matches;
    Array best_future_yaw_deltas;
    for (int i = 0; i < 3; i++) {
        best_future_yaw_deltas.push_back(Math::rad_to_deg(best.future_yaw_deltas[i]));
    }
    result["future_yaw_deltas_degrees"] = best_future_yaw_deltas;
    return result;
}


// ==================================================
// DATABASE COVERAGE ANALYZER
// ==================================================

Dictionary MotionMatchingSearch::analyze_database_coverage() const {

    Dictionary result;

    if (database.empty()) {
        result["success"] = false;
        result["error"] = "Database has not been loaded.";
        return result;
    }

    struct Direction {
        String name;
        Vector3 vector;
    };

    const double diagonal = 1.0 / std::sqrt(2.0);

    const std::array<Direction, 8> directions = {{

        {"forward", Vector3(0.0, 0.0, 1.0)},
        {"backward", Vector3(0.0, 0.0, -1.0)},
        {"left", Vector3(-1.0, 0.0, 0.0)},
        {"right", Vector3(1.0, 0.0, 0.0)},

        {"forward_left", Vector3(-diagonal, 0.0, diagonal)},
        {"forward_right", Vector3(diagonal, 0.0, diagonal)},
        {"backward_left", Vector3(-diagonal, 0.0, -diagonal)},
        {"backward_right", Vector3(diagonal, 0.0, -diagonal)}

    }};

    const double MIN_ALIGNMENT = std::cos(
        Math::deg_to_rad(25.0)
    );

    struct FamilyStats {
        int animation_count = 0;
        int valid_sample_count = 0;
    };

    const std::array<String, 3> family_names = {{
        "walk",
        "run",
        "sprint"
    }};

    std::array<FamilyStats, 3> family_stats;

    struct DirectionStats {

        int aligned_samples = 0;

        double minimum_speed = std::numeric_limits<double>::max();
        double maximum_speed = 0.0;
        double maximum_total_speed = 0.0;

        String fastest_animation;
        double fastest_time = 0.0;

        Vector3 fastest_velocity;

        bool has_samples = false;
    };

    std::array<std::array<DirectionStats, 8>, 4> stats;

    // ----------------------------------------------
    // ITERATE ELIGIBLE ANIMATIONS
    // ----------------------------------------------

    for (const MotionAnimation &animation : database) {

        if (!animation.eligible_steady_locomotion) {
            continue;
        }

        int family_index = -1;

        if (has_tag(animation.tags, "locomotion_walk")) {
            family_index = 1;
        }
        else if (has_tag(animation.tags, "locomotion_run")) {
            family_index = 2;
        }
        else if (has_tag(animation.tags, "locomotion_sprint")) {
            family_index = 3;
        }

        if (family_index < 1 || family_index > 3) {
            continue;
        }

        family_stats[family_index - 1].animation_count++;

        for (const MotionSample &sample : animation.samples) {

            if (
                !sample.has_future_trajectory ||
                !sample.has_future_rotation
            ) {
                continue;
            }

            Vector3 velocity = sample.matching_velocity;
            velocity.y = 0.0;

            double total_speed = velocity.length();

            family_stats[family_index - 1].valid_sample_count++;

            for (int direction_index = 0; direction_index < 8; direction_index++) {

                const Vector3 &direction =
                    directions[direction_index].vector;

                if (total_speed <= 0.0001) {
                    continue;
                }

                double alignment = velocity.normalized().dot(direction);

                if (alignment < MIN_ALIGNMENT) {
                    continue;
                }

                double projected_speed = velocity.dot(direction);

                if (projected_speed <= 0.0) {
                    continue;
                }

                int group_indices[2] = {
                    0,
                    family_index
                };

                for (int group_number = 0; group_number < 2; group_number++) {

                    int group_index = group_indices[group_number];

                    DirectionStats &entry =
                        stats[group_index][direction_index];

                    entry.aligned_samples++;
                    entry.has_samples = true;

                    entry.minimum_speed = std::min(
                        entry.minimum_speed,
                        projected_speed
                    );

                    if (projected_speed > entry.maximum_speed) {

                        entry.maximum_speed = projected_speed;
                        entry.maximum_total_speed = total_speed;
                        entry.fastest_animation = animation.name;
                        entry.fastest_time = sample.time;
                        entry.fastest_velocity = velocity;
                    }
                }
            }
        }
    }

    // ----------------------------------------------
    // BUILD FAMILY REPORTS
    // ----------------------------------------------

    Dictionary families;

    for (int family_index = 0; family_index < 3; family_index++) {

        Dictionary family;

        family["animation_count"] =
            family_stats[family_index].animation_count;

        family["valid_sample_count"] =
            family_stats[family_index].valid_sample_count;

        families[family_names[family_index]] = family;
    }

    // ----------------------------------------------
    // BUILD DIRECTION REPORTS
    // ----------------------------------------------

    Array direction_reports;

    for (int direction_index = 0; direction_index < 8; direction_index++) {

        Dictionary direction_report;

        direction_report["direction"] =
            directions[direction_index].name;

        Dictionary group_reports;

        for (int group_index = 0; group_index < 4; group_index++) {

            String group_name;

            if (group_index == 0) {
                group_name = "all";
            }
            else {
                group_name = family_names[group_index - 1];
            }

            const DirectionStats &entry =
                stats[group_index][direction_index];

            Dictionary group;

            group["aligned_samples"] = entry.aligned_samples;
            group["has_samples"] = entry.has_samples;

            if (entry.has_samples) {

                group["minimum_speed"] = entry.minimum_speed;
                group["maximum_speed"] = entry.maximum_speed;

                group["maximum_total_speed"] =
                    entry.maximum_total_speed;

                group["fastest_animation"] =
                    entry.fastest_animation;

                group["fastest_time"] = entry.fastest_time;
                group["fastest_velocity"] = entry.fastest_velocity;
            }
            else {

                group["minimum_speed"] = 0.0;
                group["maximum_speed"] = 0.0;
                group["maximum_total_speed"] = 0.0;
                group["fastest_animation"] = "";
                group["fastest_time"] = 0.0;
                group["fastest_velocity"] = Vector3();
            }

            group_reports[group_name] = group;
        }

        direction_report["groups"] = group_reports;
        direction_reports.push_back(direction_report);
    }

    result["success"] = true;
    result["direction_alignment_degrees"] = 25.0;

    result["eligible_animation_count"] =
        eligible_animation_count;

    result["eligible_search_samples"] =
        eligible_search_samples;

    result["families"] = families;
    result["directions"] = direction_reports;

    return result;
}


// ==================================================
// FASTEST DIRECTIONAL SAMPLES ANALYZER
// ==================================================

Dictionary MotionMatchingSearch::analyze_fastest_directional_samples(
    int samples_per_direction
) const {

    Dictionary result;

    if (database.empty()) {
        result["success"] = false;
        result["error"] = "Database has not been loaded.";
        return result;
    }

    samples_per_direction = std::max(
        1,
        std::min(samples_per_direction, 100)
    );

    struct Direction {
        String name;
        Vector3 vector;
    };

    const double diagonal = 1.0 / std::sqrt(2.0);

    const std::array<Direction, 8> directions = {{

        {"forward", Vector3(0.0, 0.0, 1.0)},
        {"backward", Vector3(0.0, 0.0, -1.0)},
        {"left", Vector3(-1.0, 0.0, 0.0)},
        {"right", Vector3(1.0, 0.0, 0.0)},

        {"forward_left", Vector3(-diagonal, 0.0, diagonal)},
        {"forward_right", Vector3(diagonal, 0.0, diagonal)},
        {"backward_left", Vector3(-diagonal, 0.0, -diagonal)},
        {"backward_right", Vector3(diagonal, 0.0, -diagonal)}

    }};

    const double minimum_alignment = std::cos(
        Math::deg_to_rad(25.0)
    );

    struct Candidate {

        String animation_name;
        String family;

        int animation_index = -1;
        int sample_index = -1;

        double time = 0.0;

        double projected_speed = 0.0;
        double total_speed = 0.0;

        double yaw = 0.0;

        Vector3 velocity;
    };

    Array direction_reports;
    int total_candidates = 0;

    // ----------------------------------------------
    // PROCESS EACH DIRECTION
    // ----------------------------------------------

    for (int direction_index = 0; direction_index < 8; direction_index++) {

        const Direction &direction = directions[direction_index];

        std::vector<Candidate> candidates;

        for (
            int animation_index = 0;
            animation_index < (int)database.size();
            animation_index++
        ) {

            const MotionAnimation &animation =
                database[animation_index];

            if (!animation.eligible_steady_locomotion) {
                continue;
            }

            String family = "unknown";

            for (const String &tag : animation.tags) {

                if (tag == "locomotion_walk") {
                    family = "walk";
                    break;
                }

                if (tag == "locomotion_run") {
                    family = "run";
                    break;
                }

                if (tag == "locomotion_sprint") {
                    family = "sprint";
                    break;
                }
            }

            for (
                int sample_index = 0;
                sample_index < (int)animation.samples.size();
                sample_index++
            ) {

                const MotionSample &sample =
                    animation.samples[sample_index];

                if (
                    !sample.has_future_trajectory ||
                    !sample.has_future_rotation
                ) {
                    continue;
                }

                Vector3 velocity = sample.matching_velocity;
                velocity.y = 0.0;

                double total_speed = velocity.length();

                if (total_speed <= 0.0001) {
                    continue;
                }

                Vector3 normalized_velocity = velocity / total_speed;

                double alignment = normalized_velocity.dot(
                    direction.vector
                );

                if (alignment < minimum_alignment) {
                    continue;
                }

                double projected_speed = velocity.dot(
                    direction.vector
                );

                if (projected_speed <= 0.0) {
                    continue;
                }

                Candidate candidate;

                candidate.animation_name = animation.name;
                candidate.family = family;

                candidate.animation_index = animation_index;
                candidate.sample_index = sample_index;

                candidate.time = sample.time;

                candidate.projected_speed = projected_speed;
                candidate.total_speed = total_speed;

                candidate.yaw = sample.yaw;
                candidate.velocity = velocity;

                candidates.push_back(candidate);
            }
        }

        std::sort(
            candidates.begin(),
            candidates.end(),
            [](const Candidate &a, const Candidate &b) {
                return a.projected_speed > b.projected_speed;
            }
        );

        Dictionary direction_report;

        direction_report["direction"] = direction.name;

        direction_report["available_candidates"] =
            (int)candidates.size();

        Array fastest_samples;

        int result_count = std::min(
            samples_per_direction,
            (int)candidates.size()
        );

        for (int i = 0; i < result_count; i++) {

            const Candidate &candidate = candidates[i];

            Dictionary sample;

            sample["rank"] = i + 1;
            sample["animation_name"] = candidate.animation_name;
            sample["family"] = candidate.family;
            sample["animation_index"] = candidate.animation_index;
            sample["sample_index"] = candidate.sample_index;
            sample["time"] = candidate.time;
            sample["projected_speed"] = candidate.projected_speed;
            sample["total_speed"] = candidate.total_speed;
            sample["velocity"] = candidate.velocity;

            sample["yaw_degrees"] =
                Math::rad_to_deg(candidate.yaw);

            fastest_samples.push_back(sample);
        }

        direction_report["fastest_samples"] = fastest_samples;
        direction_reports.push_back(direction_report);

        total_candidates += (int)candidates.size();
    }

    result["success"] = true;
    result["direction_alignment_degrees"] = 25.0;
    result["samples_per_direction"] = samples_per_direction;

    result["eligible_animations"] = eligible_animation_count;
    result["eligible_samples"] = eligible_search_samples;

    result["total_directional_candidates"] = total_candidates;
    result["directions"] = direction_reports;

    return result;
}


// ==================================================
// FASTEST UNIQUE ANIMATIONS ANALYZER
// ==================================================

Dictionary MotionMatchingSearch::analyze_fastest_unique_animations(
    int animations_per_direction
) const {

    Dictionary result;

    if (database.empty()) {
        result["success"] = false;
        result["error"] = "Database has not been loaded.";
        return result;
    }

    animations_per_direction = std::max(
        1,
        std::min(animations_per_direction, 100)
    );

    struct Direction {
        String name;
        Vector3 vector;
    };

    const double diagonal = 1.0 / std::sqrt(2.0);

    const std::array<Direction, 8> directions = {{

        {"forward", Vector3(0.0, 0.0, 1.0)},
        {"backward", Vector3(0.0, 0.0, -1.0)},
        {"left", Vector3(-1.0, 0.0, 0.0)},
        {"right", Vector3(1.0, 0.0, 0.0)},

        {"forward_left", Vector3(-diagonal, 0.0, diagonal)},
        {"forward_right", Vector3(diagonal, 0.0, diagonal)},
        {"backward_left", Vector3(-diagonal, 0.0, -diagonal)},
        {"backward_right", Vector3(diagonal, 0.0, -diagonal)}

    }};

    const double minimum_alignment = std::cos(
        Math::deg_to_rad(25.0)
    );

    struct Candidate {

        String animation_name;
        String family;

        int animation_index = -1;
        int sample_index = -1;

        double time = 0.0;

        double projected_speed = 0.0;
        double total_speed = 0.0;

        double yaw = 0.0;

        Vector3 velocity;
    };

    Array direction_reports;

    int total_directional_samples = 0;
    int total_unique_directional_animations = 0;

    // ----------------------------------------------
    // PROCESS EACH DIRECTION
    // ----------------------------------------------

    for (int direction_index = 0; direction_index < 8; direction_index++) {

        const Direction &direction = directions[direction_index];

        std::vector<Candidate> unique_candidates;

        int available_directional_samples = 0;

        // Each animation can contribute only one result:
        // its fastest matching sample for this direction.

        for (
            int animation_index = 0;
            animation_index < (int)database.size();
            animation_index++
        ) {

            const MotionAnimation &animation =
                database[animation_index];

            if (!animation.eligible_steady_locomotion) {
                continue;
            }

            String family = "unknown";

            for (const String &tag : animation.tags) {

                if (tag == "locomotion_walk") {
                    family = "walk";
                    break;
                }

                if (tag == "locomotion_run") {
                    family = "run";
                    break;
                }

                if (tag == "locomotion_sprint") {
                    family = "sprint";
                    break;
                }
            }

            Candidate best_candidate;
            bool found_candidate = false;

            for (
                int sample_index = 0;
                sample_index < (int)animation.samples.size();
                sample_index++
            ) {

                const MotionSample &sample =
                    animation.samples[sample_index];

                if (
                    !sample.has_future_trajectory ||
                    !sample.has_future_rotation
                ) {
                    continue;
                }

                Vector3 velocity = sample.matching_velocity;
                velocity.y = 0.0;

                double total_speed = velocity.length();

                if (total_speed <= 0.0001) {
                    continue;
                }

                Vector3 normalized_velocity = velocity / total_speed;

                double alignment = normalized_velocity.dot(
                    direction.vector
                );

                if (alignment < minimum_alignment) {
                    continue;
                }

                double projected_speed = velocity.dot(
                    direction.vector
                );

                if (projected_speed <= 0.0) {
                    continue;
                }

                available_directional_samples++;

                if (
                    found_candidate &&
                    projected_speed <= best_candidate.projected_speed
                ) {
                    continue;
                }

                best_candidate.animation_name = animation.name;
                best_candidate.family = family;

                best_candidate.animation_index = animation_index;
                best_candidate.sample_index = sample_index;

                best_candidate.time = sample.time;

                best_candidate.projected_speed = projected_speed;
                best_candidate.total_speed = total_speed;

                best_candidate.yaw = sample.yaw;
                best_candidate.velocity = velocity;

                found_candidate = true;
            }

            if (found_candidate) {
                unique_candidates.push_back(best_candidate);
            }
        }

        // ------------------------------------------
        // SORT UNIQUE ANIMATIONS BY SPEED
        // ------------------------------------------

        std::sort(
            unique_candidates.begin(),
            unique_candidates.end(),
            [](const Candidate &a, const Candidate &b) {
                return a.projected_speed > b.projected_speed;
            }
        );

        // ------------------------------------------
        // BUILD DIRECTION REPORT
        // ------------------------------------------

        Dictionary direction_report;

        direction_report["direction"] = direction.name;

        direction_report["available_directional_samples"] =
            available_directional_samples;

        direction_report["unique_animation_count"] =
            (int)unique_candidates.size();

        Array fastest_animations;

        int result_count = std::min(
            animations_per_direction,
            (int)unique_candidates.size()
        );

        for (int i = 0; i < result_count; i++) {

            const Candidate &candidate = unique_candidates[i];

            Dictionary animation;

            animation["rank"] = i + 1;

            animation["animation_name"] =
                candidate.animation_name;

            animation["family"] =
                candidate.family;

            animation["animation_index"] =
                candidate.animation_index;

            animation["best_sample_index"] =
                candidate.sample_index;

            animation["best_sample_time"] =
                candidate.time;

            animation["projected_speed"] =
                candidate.projected_speed;

            animation["total_speed"] =
                candidate.total_speed;

            animation["velocity"] =
                candidate.velocity;

            animation["yaw_degrees"] =
                Math::rad_to_deg(candidate.yaw);

            fastest_animations.push_back(animation);
        }

        direction_report["fastest_animations"] =
            fastest_animations;

        direction_reports.push_back(direction_report);

        total_directional_samples +=
            available_directional_samples;

        total_unique_directional_animations +=
            (int)unique_candidates.size();
    }

    // ----------------------------------------------
    // FINAL RESULT
    // ----------------------------------------------

    result["success"] = true;

    result["direction_alignment_degrees"] = 25.0;

    result["animations_per_direction"] =
        animations_per_direction;

    result["eligible_animations"] =
        eligible_animation_count;

    result["eligible_samples"] =
        eligible_search_samples;

    result["total_directional_samples"] =
        total_directional_samples;

    result["total_unique_directional_animations"] =
        total_unique_directional_animations;

    result["directions"] = direction_reports;

    return result;
}


// ==================================================
// DATABASE INFORMATION
// ==================================================

int MotionMatchingSearch::get_animation_count() const {
    return (int)database.size();
}

int MotionMatchingSearch::get_sample_count() const {
    return total_samples;
}

int MotionMatchingSearch::get_eligible_animation_count() const {
    return eligible_animation_count;
}

int MotionMatchingSearch::get_eligible_sample_count() const {
    return eligible_search_samples;
}

String MotionMatchingSearch::get_last_error() const {
    return last_error;
}


// ==================================================
// GODOT REGISTRATION
// ==================================================

void MotionMatchingSearch::_bind_methods() {

    ClassDB::bind_method(
        D_METHOD(
            "calculate_cost",
            "current_velocity",
            "desired_velocity"
        ),
        &MotionMatchingSearch::calculate_cost
    );

    ClassDB::bind_method(
        D_METHOD("load_database", "file_path"),
        &MotionMatchingSearch::load_database
    );

    ClassDB::bind_method(
        D_METHOD(
            "search_best_match",
            "desired_velocity",
            "desired_future_positions",
            "desired_facing_yaw"
        ),
        &MotionMatchingSearch::search_best_match
    );

    ClassDB::bind_method(
        D_METHOD(
            "search_best_match_continuous",
            "desired_velocity",
            "desired_future_positions",
            "desired_facing_yaw",
            "current_animation_index",
            "current_animation_time",
            "animation_switch_penalty",
            "same_animation_time_weight"
        ),
        &MotionMatchingSearch::search_best_match_continuous
    );

    ClassDB::bind_method(

        &MotionMatchingSearch::analyze_database_coverage
    );

    ClassDB::bind_method(
        D_METHOD(
            "analyze_fastest_directional_samples",
            "samples_per_direction"
        ),
        &MotionMatchingSearch::analyze_fastest_directional_samples,
        DEFVAL(20)
    );

    ClassDB::bind_method(
        D_METHOD(
            "analyze_fastest_unique_animations",
            "animations_per_direction"
        ),
        &MotionMatchingSearch::analyze_fastest_unique_animations,
        DEFVAL(20)
    );

    ClassDB::bind_method(
        D_METHOD("get_animation_count"),
        &MotionMatchingSearch::get_animation_count
    );

    ClassDB::bind_method(
        D_METHOD("get_sample_count"),
        &MotionMatchingSearch::get_sample_count
    );

    ClassDB::bind_method(
        D_METHOD("get_eligible_animation_count"),
        &MotionMatchingSearch::get_eligible_animation_count
    );

    ClassDB::bind_method(
        D_METHOD("get_eligible_sample_count"),
        &MotionMatchingSearch::get_eligible_sample_count
    );

    ClassDB::bind_method(
        D_METHOD("get_last_error"),
        &MotionMatchingSearch::get_last_error
    );
}
