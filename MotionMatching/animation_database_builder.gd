extends Node

const SAMPLE_RATE: float = 30.0
const ROTATION_THRESHOLD_DEGREES: float = 1.0

const ROOT_BONE_NAME: StringName = &"root"
const LEFT_FOOT_BONE_NAME: StringName = &"foot_l"
const RIGHT_FOOT_BONE_NAME: StringName = &"foot_r"

const ANIMATION_FILES: Array[String] = [
	"res://Assets/Animations/Run.glb",
	"res://Assets/Animations/Walk.glb",
	"res://Assets/Animations/Sprint.glb",
	"res://Assets/Animations/Crouch.glb",
	"res://Assets/Animations/Idle.glb"
]

const OUTPUT_PATH: String = "user://motion_database.json"

var rotation_diagnostic_done: bool = false


func _ready() -> void:
	build_database()


# ==================================================
# DATABASE BUILDER
# ==================================================

func build_database() -> void:
	print("\n========== MOTION DATABASE BUILDER ==========")

	var database: Array[Dictionary] = []

	var total_found: int = 0
	var total_exported: int = 0
	var total_skipped: int = 0
	var total_samples: int = 0
	var total_rotation_tracks: int = 0
	var total_rotation_motion: int = 0

	var category_counts: Dictionary = {}

	for source_file in ANIMATION_FILES:

		print("\n----------------------------------------")
		print("Processing: ", source_file)

		var packed_scene: PackedScene = load(source_file) as PackedScene

		if packed_scene == null:
			push_error("Could not load: " + source_file)
			continue

		var instance: Node = packed_scene.instantiate()

		# Add the instance to the scene tree so AnimationPlayer
		# and Skeleton3D can evaluate animation poses.
		add_child(instance)

		var animation_player: AnimationPlayer = find_animation_player(instance)
		var skeleton: Skeleton3D = find_skeleton(instance)

		if animation_player == null:
			push_error("No AnimationPlayer found in: " + source_file)
			instance.free()
			continue

		if skeleton == null:
			push_error("No Skeleton3D found in: " + source_file)
			instance.free()
			continue

		var root_bone_index: int = skeleton.find_bone(ROOT_BONE_NAME)
		var left_foot_index: int = skeleton.find_bone(LEFT_FOOT_BONE_NAME)
		var right_foot_index: int = skeleton.find_bone(RIGHT_FOOT_BONE_NAME)

		if root_bone_index == -1:
			push_error("Missing root bone in: " + source_file)
			instance.free()
			continue

		if left_foot_index == -1:
			push_error("Missing foot_l bone in: " + source_file)
			instance.free()
			continue

		if right_foot_index == -1:
			push_error("Missing foot_r bone in: " + source_file)
			instance.free()
			continue

		print("Skeleton: ", skeleton.name)
		print("Root bone index: ", root_bone_index)
		print("Left foot index: ", left_foot_index)
		print("Right foot index: ", right_foot_index)

		var animation_names: PackedStringArray = (
			animation_player.get_animation_list()
		)

		var file_found: int = 0
		var file_processed: int = 0
		var file_exported: int = 0
		var file_samples: int = 0
		var file_rotation_tracks: int = 0
		var file_rotation_motion: int = 0

		for animation_name in animation_names:

			var animation: Animation = (
				animation_player.get_animation(animation_name)
			)

			if animation == null:
				continue

			file_found += 1
			total_found += 1

			var root_position_track: int = find_root_track(
				animation,
				Animation.TYPE_POSITION_3D
			)

			var root_rotation_track: int = find_root_track(
				animation,
				Animation.TYPE_ROTATION_3D
			)

			if root_position_track == -1:
				total_skipped += 1
				continue

			if animation.length <= 0.0:
				total_skipped += 1
				continue

			if animation.track_get_key_count(root_position_track) < 2:
				total_skipped += 1
				continue

			file_processed += 1

			# ------------------------------------------
			# ROTATION DIAGNOSTIC
			# ------------------------------------------

			if (
				not rotation_diagnostic_done
				and animation_name.contains("Turn L 090")
				and root_rotation_track != -1
			):
				inspect_rotation(
					animation,
					root_position_track,
					root_rotation_track
				)

				rotation_diagnostic_done = true

			# ------------------------------------------
			# ROOT INITIAL VALUES
			# ------------------------------------------

			var initial_position: Vector3 = (
				animation.position_track_interpolate(
					root_position_track,
					0.0
				)
			)

			var final_position: Vector3 = (
				animation.position_track_interpolate(
					root_position_track,
					animation.length
				)
			)

			var displacement: Vector3 = (
				final_position - initial_position
			)

			var average_velocity: Vector3 = (
				displacement / animation.length
			)

			var has_rotation_track: bool = (
				root_rotation_track != -1
			)

			var initial_rotation: Quaternion = Quaternion.IDENTITY
			var final_rotation: Quaternion = Quaternion.IDENTITY
			var inverse_initial_rotation: Quaternion = Quaternion.IDENTITY

			var rotation_key_count: int = 0

			if has_rotation_track:

				rotation_key_count = (
					animation.track_get_key_count(
						root_rotation_track
					)
				)

				if rotation_key_count > 0:

					initial_rotation = (
						animation.rotation_track_interpolate(
							root_rotation_track,
							0.0
						)
					)

					final_rotation = (
						animation.rotation_track_interpolate(
							root_rotation_track,
							animation.length
						)
					)

					inverse_initial_rotation = (
						initial_rotation.inverse()
					)

					file_rotation_tracks += 1
					total_rotation_tracks += 1

			# ------------------------------------------
			# SAMPLE ROOT + FOOT FEATURES
			# ------------------------------------------

			var trajectory_samples: Array = sample_animation(
				animation_player,
				animation_name,
				animation,
				root_position_track,
				root_rotation_track,
				skeleton,
				root_bone_index,
				left_foot_index,
				right_foot_index,
				initial_position,
				inverse_initial_rotation
			)

			# ------------------------------------------
			# ROTATION ANALYSIS
			# ------------------------------------------

			var max_rotation_degrees: float = 0.0

			for sample in trajectory_samples:

				var sample_rotation: Array = sample["rotation"]

				var q: Quaternion = Quaternion(
					float(sample_rotation[0]),
					float(sample_rotation[1]),
					float(sample_rotation[2]),
					float(sample_rotation[3])
				)

				var angle_radians: float = 2.0 * acos(
					clampf(absf(q.w), 0.0, 1.0)
				)

				var angle_degrees: float = rad_to_deg(
					angle_radians
				)

				max_rotation_degrees = maxf(
					max_rotation_degrees,
					angle_degrees
				)

			var has_rotation_motion: bool = (
				max_rotation_degrees > ROTATION_THRESHOLD_DEGREES
			)

			if has_rotation_motion:
				file_rotation_motion += 1
				total_rotation_motion += 1

			var final_relative_rotation: Quaternion = (
				Quaternion.IDENTITY
			)

			if has_rotation_track:
				final_relative_rotation = (
					inverse_initial_rotation * final_rotation
				)

			# ------------------------------------------
			# CLASSIFICATION
			# ------------------------------------------

			var tags: Array = classify_animation(
				animation_name,
				source_file
			)

			# ------------------------------------------
			# DATABASE ENTRY
			# ------------------------------------------

			var entry: Dictionary = {

				"source_file": source_file,
				"name": animation_name,
				"duration": animation.length,

				"coordinate_space": "animation_root_parent",

				"root_track_path": str(
					animation.track_get_path(
						root_position_track
					)
				),

				"root_key_count": (
					animation.track_get_key_count(
						root_position_track
					)
				),

				"has_root_rotation": has_rotation_track,
				"has_root_rotation_track": has_rotation_track,
				"has_root_rotation_motion": has_rotation_motion,

				"root_rotation_track_path": (
					str(animation.track_get_path(root_rotation_track))
					if has_rotation_track else ""
				),

				"root_rotation_key_count": rotation_key_count,

				"root_initial_rotation": quaternion_to_array(
					initial_rotation
				),

				"root_final_relative_rotation": quaternion_to_array(
					final_relative_rotation
				),

				"max_rotation_degrees": max_rotation_degrees,

				"final_rotation_degrees": (
					2.0 * rad_to_deg(
						acos(
							clampf(
								absf(final_relative_rotation.w),
								0.0,
								1.0
							)
						)
					)
				),

				"sample_rate": SAMPLE_RATE,
				"sample_count": trajectory_samples.size(),

				"displacement": vector3_to_array(
					displacement
				),

				"average_velocity": vector3_to_array(
					average_velocity
				),

				"pose_feature_bones": [
					"foot_l",
					"foot_r"
				],

				"pose_coordinate_space": "root_local",

				"tags": tags,

				"trajectory_samples": trajectory_samples
			}

			database.append(entry)

			file_exported += 1
			total_exported += 1

			file_samples += trajectory_samples.size()
			total_samples += trajectory_samples.size()

			for tag in tags:

				category_counts[tag] = (
					int(category_counts.get(tag, 0)) + 1
				)

		print("Animations found: ", file_found)
		print("Animations processed: ", file_processed)
		print("Animations exported: ", file_exported)

		print(
			"Animations with rotation tracks: ",
			file_rotation_tracks
		)

		print(
			"Animations with meaningful rotation: ",
			file_rotation_motion
		)

		print("Trajectory samples: ", file_samples)

		instance.free()

	# ----------------------------------------------
	# SAVE DATABASE
	# ----------------------------------------------

	if not rotation_diagnostic_done:

		print(
			"\nWARNING: No matching 'Turn L 090' animation was found."
		)

		print("No rotation diagnostic was performed.")

	var output_file: FileAccess = FileAccess.open(
		OUTPUT_PATH,
		FileAccess.WRITE
	)

	if output_file == null:
		push_error("Could not write motion database.")
		return

	output_file.store_string(
		JSON.stringify(database, "\t")
	)

	output_file.close()

	# ----------------------------------------------
	# SUMMARY
	# ----------------------------------------------

	print("\n========== DATABASE SUMMARY ==========")

	print("Source files: ", ANIMATION_FILES.size())
	print("Animations found: ", total_found)
	print("Animations skipped: ", total_skipped)
	print("Exported animations: ", total_exported)

	print(
		"Animations with rotation tracks: ",
		total_rotation_tracks
	)

	print(
		"Animations with meaningful root rotation: ",
		total_rotation_motion
	)

	print("Total trajectory samples: ", total_samples)

	print("\n========== CLASSIFICATION SUMMARY ==========")

	var sorted_categories: Array = category_counts.keys()
	sorted_categories.sort()

	for category in sorted_categories:
		print(category, ": ", category_counts[category])

	print("\n========== POSE FEATURE SUMMARY ==========")

	print("Pose bones: foot_l, foot_r")
	print("Position coordinate space: root_local")
	print("Velocity calculation: sampled finite differences")

	print("\nDatabase exported to: ", OUTPUT_PATH)
	print("========================================\n")


# ==================================================
# ANIMATION SAMPLING
# ==================================================

func sample_animation(
	animation_player: AnimationPlayer,
	animation_name: StringName,
	animation: Animation,
	position_track: int,
	rotation_track: int,
	skeleton: Skeleton3D,
	root_bone_index: int,
	left_foot_index: int,
	right_foot_index: int,
	initial_position: Vector3,
	inverse_initial_rotation: Quaternion
) -> Array:

	var samples: Array = []

	var sample_count: int = int(
		floor(animation.length * SAMPLE_RATE)
	) + 1

	animation_player.stop()
	animation_player.play(animation_name, 0.0)

	var root_position_samples: Array[Vector3] = []
	var left_foot_samples: Array[Vector3] = []
	var right_foot_samples: Array[Vector3] = []

	var root_rotation_samples: Array[Quaternion] = []

	# ----------------------------------------------
	# EVALUATE ANIMATION AT EVERY SAMPLE
	# ----------------------------------------------

	for i in range(sample_count):

		var sample_time: float = (
			float(i) / SAMPLE_RATE
		)

		# Evaluate the actual skeleton pose immediately.
		animation_player.seek(sample_time, true)

		# ------------------------------------------
		# ROOT POSITION
		# ------------------------------------------

		var interpolated_position: Vector3 = (
			animation.position_track_interpolate(
				position_track,
				sample_time
			)
		)

		var current_position: Vector3 = (
			interpolated_position - initial_position
		)

		root_position_samples.append(current_position)

		# ------------------------------------------
		# ROOT ROTATION
		# ------------------------------------------

		var relative_rotation: Quaternion = (
			Quaternion.IDENTITY
		)

		if rotation_track != -1:

			if animation.track_get_key_count(rotation_track) > 0:

				var current_rotation: Quaternion = (
					animation.rotation_track_interpolate(
						rotation_track,
						sample_time
					)
				)

				relative_rotation = (
					inverse_initial_rotation * current_rotation
				)

		root_rotation_samples.append(relative_rotation)

		# ------------------------------------------
		# SKELETON ROOT-LOCAL FOOT POSITIONS
		# ------------------------------------------

		var root_transform: Transform3D = (
			skeleton.get_bone_global_pose(
				root_bone_index
			)
		)

		var left_foot_transform: Transform3D = (
			skeleton.get_bone_global_pose(
				left_foot_index
			)
		)

		var right_foot_transform: Transform3D = (
			skeleton.get_bone_global_pose(
				right_foot_index
			)
		)

		var inverse_root_transform: Transform3D = (
			root_transform.affine_inverse()
		)

		var left_foot_local: Transform3D = (
			inverse_root_transform * left_foot_transform
		)

		var right_foot_local: Transform3D = (
			inverse_root_transform * right_foot_transform
		)

		left_foot_samples.append(
			left_foot_local.origin
		)

		right_foot_samples.append(
			right_foot_local.origin
		)

	# ----------------------------------------------
	# BUILD SAMPLE DICTIONARIES
	# ----------------------------------------------

	var sample_interval: float = 1.0 / SAMPLE_RATE

	for i in range(sample_count):

		var sample_time: float = float(i) / SAMPLE_RATE

		var previous_time: float = maxf(
			0.0,
			sample_time - sample_interval
		)

		var next_time: float = minf(
			animation.length,
			sample_time + sample_interval
		)

		var previous_position: Vector3 = (
			animation.position_track_interpolate(
				position_track,
				previous_time
			) - initial_position
		)

		var next_position: Vector3 = (
			animation.position_track_interpolate(
				position_track,
				next_time
			) - initial_position
		)

		var time_difference: float = (
			next_time - previous_time
		)

		var root_velocity: Vector3 = Vector3.ZERO

		if time_difference > 0.00001:

			root_velocity = (
				next_position - previous_position
			) / time_difference

		var sample: Dictionary = {

			"time": sample_time,

			"position": vector3_to_array(
				root_position_samples[i]
			),

			"velocity": vector3_to_array(
				root_velocity
			),

			"rotation": quaternion_to_array(
				root_rotation_samples[i]
			),

			"left_foot_position": vector3_to_array(
				left_foot_samples[i]
			),

			"left_foot_velocity": vector3_to_array(
				calculate_sample_velocity(
					left_foot_samples,
					i,
					SAMPLE_RATE
				)
			),

			"right_foot_position": vector3_to_array(
				right_foot_samples[i]
			),

			"right_foot_velocity": vector3_to_array(
				calculate_sample_velocity(
					right_foot_samples,
					i,
					SAMPLE_RATE
				)
			)
		}

		samples.append(sample)

	return samples


# ==================================================
# SAMPLE VELOCITY
# ==================================================

func calculate_sample_velocity(
	positions: Array[Vector3],
	index: int,
	sample_rate: float
) -> Vector3:

	if positions.size() < 2:
		return Vector3.ZERO

	var previous_index: int = maxi(
		0,
		index - 1
	)

	var next_index: int = mini(
		positions.size() - 1,
		index + 1
	)

	if previous_index == next_index:
		return Vector3.ZERO

	var time_difference: float = (
		float(next_index - previous_index) / sample_rate
	)

	if time_difference <= 0.00001:
		return Vector3.ZERO

	return (
		positions[next_index] - positions[previous_index]
	) / time_difference


# ==================================================
# ROTATION AXIS DIAGNOSTIC
# ==================================================

func inspect_rotation(
	animation: Animation,
	position_track: int,
	rotation_track: int
) -> void:

	print("\n")
	print("========================================")
	print("       ROTATION AXIS DIAGNOSTIC")
	print("========================================")

	if rotation_track == -1:
		print("No root rotation track.")
		return

	var initial_rotation: Quaternion = (
		animation.rotation_track_interpolate(
			rotation_track,
			0.0
		)
	)

	print("Animation duration: ", animation.length)
	print("Initial rotation: ", initial_rotation)

	var fractions: Array[float] = [
		0.0,
		0.25,
		0.5,
		0.75,
		1.0
	]

	for fraction in fractions:

		var sample_time: float = (
			animation.length * fraction
		)

		var current_rotation: Quaternion = (
			animation.rotation_track_interpolate(
				rotation_track,
				sample_time
			)
		)

		var relative_rotation: Quaternion = (
			initial_rotation.inverse() * current_rotation
		)

		var normalized_rotation: Quaternion = (
			relative_rotation.normalized()
		)

		var axis: Vector3 = normalized_rotation.get_axis()
		var angle: float = normalized_rotation.get_angle()

		var root_position: Vector3 = (
			animation.position_track_interpolate(
				position_track,
				sample_time
			)
		)

		print("----------------------------------------")
		print("Time: ", sample_time)
		print("Root position: ", root_position)
		print("Absolute rotation: ", current_rotation)
		print("Relative rotation: ", relative_rotation)
		print("Rotation axis: ", axis)
		print("Rotation angle degrees: ", rad_to_deg(angle))

	print("========================================")
	print("       END ROTATION AXIS DIAGNOSTIC")
	print("========================================\n")


# ==================================================
# ANIMATION HELPERS
# ==================================================

func find_animation_player(node: Node) -> AnimationPlayer:

	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():

		var result: AnimationPlayer = (
			find_animation_player(child)
		)

		if result != null:
			return result

	return null


func find_skeleton(node: Node) -> Skeleton3D:

	if node is Skeleton3D:
		return node as Skeleton3D

	for child in node.get_children():

		var result: Skeleton3D = (
			find_skeleton(child)
		)

		if result != null:
			return result

	return null


func find_root_track(
	animation: Animation,
	track_type: Animation.TrackType
) -> int:

	for track_index in range(animation.get_track_count()):

		if animation.track_get_type(track_index) != track_type:
			continue

		var track_path: String = str(
			animation.track_get_path(track_index)
		)

		if track_path.ends_with(":root"):
			return track_index

	return -1


# ==================================================
# SERIALIZATION
# ==================================================

func vector3_to_array(value: Vector3) -> Array:

	return [
		value.x,
		value.y,
		value.z
	]


func quaternion_to_array(value: Quaternion) -> Array:

	return [
		value.x,
		value.y,
		value.z,
		value.w
	]


# ==================================================
# ANIMATION CLASSIFICATION
# ==================================================

func classify_animation(
	animation_name: String,
	source_file: String
) -> Array:

	var animation_name_lower: String = (
		animation_name.to_lower()
	)

	var source_lower: String = (
		source_file.to_lower()
	)

	var tokens: PackedStringArray = (
		animation_name_lower
		.replace("_", " ")
		.split(" ", false)
	)

	var tags: Array = []

	if source_lower.contains("/run.glb"):
		tags.append("locomotion_run")

	elif source_lower.contains("/walk.glb"):
		tags.append("locomotion_walk")

	elif source_lower.contains("/sprint.glb"):
		tags.append("locomotion_sprint")

	elif source_lower.contains("/crouch.glb"):
		tags.append("locomotion_crouch")

	elif source_lower.contains("/idle.glb"):
		tags.append("locomotion_idle")

	if "loop" in tokens:
		tags.append("loop")

	if "start" in tokens:
		tags.append("start")

	if "stop" in tokens:
		tags.append("stop")

	if "pivot" in tokens:
		tags.append("pivot")

	if "turn" in tokens:
		tags.append("turn")

	if "reface" in tokens:
		tags.append("reface")

	if "shuffle" in tokens:
		tags.append("shuffle")

	if "spin" in tokens:
		tags.append("spin")

	if "transition" in tokens:
		tags.append("transition")

	if "arc" in tokens:
		tags.append("arc")

	for shape in [
		"box",
		"circle",
		"diamond",
		"hourglass",
		"prism"
	]:

		if shape in tokens:
			tags.append("trajectory_" + shape)

	if "lfoot" in tokens:
		tags.append("left_foot")

	if "rfoot" in tokens:
		tags.append("right_foot")

	for direction in [
		"f", "b", "l", "r",
		"fl", "fr", "bl", "br",
		"ll", "lr", "rl", "rr"
	]:

		if direction in tokens:
			tags.append("direction_" + direction)

	if "lean" in tokens:
		tags.append("lean")

	if tags.is_empty():
		tags.append("other")

	return tags
