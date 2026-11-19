#ifndef MOTION_MATCHING_SEARCH_H
#define MOTION_MATCHING_SEARCH_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

#include <vector>
#include <array>

namespace godot {

class MotionMatchingSearch : public RefCounted {

    GDCLASS(MotionMatchingSearch, RefCounted)

private:

    // ==================================================
    // MOTION SAMPLE
    // ==================================================

    struct MotionSample {

        double time = 0.0;
        double yaw = 0.0;

        Vector3 position;
        Vector3 velocity;
        Vector3 matching_velocity;

        std::array<Vector3, 3> future_positions;

        std::array<double, 3> future_yaw_deltas = {
            0.0,
            0.0,
            0.0
        };

        bool has_future_trajectory = false;
        bool has_future_rotation = false;
    };


    // ==================================================
    // MOTION ANIMATION
    // ==================================================

    struct MotionAnimation {

        String name;
        double duration = 0.0;

        std::vector<String> tags;

        std::vector<MotionSample> samples;

        bool eligible_steady_locomotion = false;
    };


    // ==================================================
    // DATABASE
    // ==================================================

    std::vector<MotionAnimation> database;

    int total_samples = 0;
    int valid_search_samples = 0;

    int eligible_animation_count = 0;
    int eligible_search_samples = 0;

    String last_error;


    // ==================================================
    // INTERNAL HELPERS
    // ==================================================

    bool interpolate_position(
        const std::vector<MotionSample> &samples,
        double time,
        Vector3 &result
    ) const;


protected:

    static void _bind_methods();


public:

    // ==================================================
    // CONSTRUCTOR
    // ==================================================

    MotionMatchingSearch();


    // ==================================================
    // VELOCITY COST
    // ==================================================

    double calculate_cost(
        Vector3 current_velocity,
        Vector3 desired_velocity
    );


    // ==================================================
    // DATABASE LOADER
    // ==================================================

    bool load_database(String file_path);


    // ==================================================
    // MOTION MATCHING SEARCH
    // ==================================================

    Dictionary search_best_match(
        Vector3 desired_velocity,
        Array desired_future_positions,
        double desired_facing_yaw
    );


    // ==================================================
    // DATABASE COVERAGE ANALYSIS
    // ==================================================

    Dictionary analyze_database_coverage() const;


    // ==================================================
    // FASTEST DIRECTIONAL SAMPLES ANALYSIS
    // ==================================================

    Dictionary analyze_fastest_directional_samples(
        int samples_per_direction = 20
    ) const;


    // ==================================================
    // DATABASE INFORMATION
    // ==================================================

    int get_animation_count() const;

    int get_sample_count() const;

    int get_eligible_animation_count() const;

    int get_eligible_sample_count() const;

    String get_last_error() const;
};

}

#endif
