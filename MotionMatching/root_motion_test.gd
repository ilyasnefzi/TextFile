extends CharacterBody3D

const DATABASE_PATH: String = "user://motion_database.json"

const ANIMATION_FILES: Array[String] = [
	"res://Assets/Animations/Run.glb",
	"res://Assets/Animations/Walk.glb",
	"res://Assets/Animations/Sprint.glb",
	"res://Assets/Animations/Crouch.glb",
	"res://Assets/Animations/Idle.glb"
]

const DESIRED_VELOCITY: Vector3 = Vector3(0.0, 0.0, 4.5)
const DESIRED_FUTURE_POSITIONS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.9),
	Vector3(0.0, 0.0, 1.8),
	Vector3(0.0, 0.0, 2.7)
]
const DESIRED_FACING_YAW: float = 0.0

const MATCH_INTERVAL: float = 0.20
const DEBUG_INTERVAL: float = 1.0
const ANIMATION_SWITCH_PENALTY: float = 0.5
const SAME_ANIMATION_TIME_WEIGHT: float = 0.5

@onready var character_player: AnimationPlayer = $Visual/Character_01/AnimationPlayer
@onready var animation_tree: AnimationTree = $Visual/AnimationTree

var motion_matching: MotionMatchingSearch
var database_data: Dictionary = {}
var animation_lookup: Array[String] = []
var database_animations: Array = []

var motion_matching_started: bool = false
var match_timer: float = 0.0
var debug_timer: float = 0.0

var match_count: int = 0
var skipped_restart_count: int = 0
var switch_count: int = 0

var current_animation_path: String = ""
var current_animation_index: int = -1
var current_animation_duration: float = 0.0
var current_animation_start_timestamp: float = 0.0
var elapsed_since_animation_selection: float = 0.0

var debug_previous_position: Vector3 = Vector3.ZERO
var last_root_motion: Vector3 = Vector3.ZERO


func _ready() -> void:
	print("\n==================================================")
	print(" C++ CONTINUOUS MOTION MATCHING TEST - LOOP FIX")
	print("==================================================")

	if not _load_animation_libraries():
		return
	if not _configure_animation_tree():
		return
	if not _load_database_json():
		return
	if not _build_animation_lookup():
		return
	if not _initialize_motion_matching():
		return

	debug_previous_position = global_position
	_start_motion_matching()


func _load_animation_libraries() -> bool:
	print("\n----------------------------------------")
	print("LOADING ANIMATION LIBRARIES")
	print("----------------------------------------")

	for animation_file in ANIMATION_FILES:
		print("\nLoading: ", animation_file)

		if not ResourceLoader.exists(animation_file):
			push_error("Animation file does not exist: " + animation_file)
			return false

		var packed_scene := load(animation_file) as PackedScene
		if packed_scene == null:
			push_error("Could not load PackedScene: " + animation_file)
			return false

		var instance := packed_scene.instantiate()
		if instance == null:
			push_error("Could not instantiate: " + animation_file)
			return false

		var source_player := _find_animation_player(instance)
		if source_player == null:
			push_error("No AnimationPlayer found in: " + animation_file)
			instance.free()
			return false

		var library_name := animation_file.get_file().get_basename()

		if not source_player.has_animation_library(""):
			push_error("No default AnimationLibrary found in: " + animation_file)
			instance.free()
			return false

		var source_library := source_player.get_animation_library("")
		if source_library == null:
			push_error("Could not retrieve AnimationLibrary: " + animation_file)
			instance.free()
			return false

		if character_player.has_animation_library(library_name):
			character_player.remove_animation_library(library_name)

		var error := character_player.add_animation_library(library_name, source_library)
		if error != OK:
			push_error(
				"Could not add animation library: " +
				library_name +
				" Error: " +
				str(error)
			)
			instance.free()
			return false

		print(
			"Loaded library: ",
			library_name,
			" | Animations: ",
			source_library.get_animation_list().size()
		)
		instance.free()

	print("\nAll animation libraries loaded successfully.")
	return true


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result

	return null


func _configure_animation_tree() -> bool:
	print("\n----------------------------------------")
	print("CONFIGURING ANIMATION TREE")
	print("----------------------------------------")

	character_player.root_node = NodePath("..")
	animation_tree.root_node = NodePath("../Character_01")
	animation_tree.anim_player = animation_tree.get_path_to(character_player)
	animation_tree.root_motion_track = NodePath("Armature/Skeleton3D:root")
	animation_tree.active = true

	print("AnimationPlayer root node: ", character_player.root_node)
	print("AnimationTree root node: ", animation_tree.root_node)
	print("AnimationTree AnimationPlayer: ", animation_tree.anim_player)
	print("Root motion track: ", animation_tree.root_motion_track)

	var state_machine := animation_tree.tree_root as AnimationNodeStateMachine
	if state_machine == null:
		push_error("AnimationTree root is not an AnimationNodeStateMachine.")
		return false

	var run_state := state_machine.get_node("Run") as AnimationNodeAnimation
	if run_state == null:
		push_error("AnimationTree does not contain a Run state.")
		return false

	print("Run state found successfully.")
	return true


func _load_database_json() -> bool:
	print("\n----------------------------------------")
	print("LOADING MOTION DATABASE JSON")
	print("----------------------------------------")

	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("Motion database not found: " + DATABASE_PATH)
		return false

	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open motion database JSON.")
		return false

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null:
		push_error("Could not parse motion database JSON.")
		return false

	if parsed is Dictionary:
		database_data = parsed
		database_animations = database_data.get("animations", [])
	elif parsed is Array:
		database_animations = parsed
	else:
		push_error("Unexpected motion database JSON format.")
		return false

	if database_animations.is_empty():
		push_error("Motion database contains no animations.")
		return false

	print("Database loaded successfully.")
	print("Animation entries: ", database_animations.size())
	return true


func _build_animation_lookup() -> bool:
	print("\n----------------------------------------")
	print("BUILDING ANIMATION LOOKUP")
	print("----------------------------------------")

	animation_lookup.clear()
	var mapped_count := 0
	var missing_count := 0

	for animation_entry in database_animations:
		if not animation_entry is Dictionary:
			animation_lookup.append("")
			missing_count += 1
			continue

		var source_file: String = str(animation_entry.get("source_file", ""))
		var animation_name: String = str(animation_entry.get("name", ""))

		if source_file.is_empty() or animation_name.is_empty():
			animation_lookup.append("")
			missing_count += 1
			continue

		var library_name := source_file.get_file().get_basename()
		var animation_path := library_name + "/" + animation_name

		if character_player.has_animation(animation_path):
			animation_lookup.append(animation_path)
			mapped_count += 1
		else:
			animation_lookup.append("")
			missing_count += 1

	print("\nAnimation mapping completed.")
	print("Database entries: ", database_animations.size())
	print("Mapped animations: ", mapped_count)
	print("Missing animations: ", missing_count)

	if mapped_count == 0 or missing_count > 0:
		push_error("Animation mapping is incomplete.")
		return false

	print("All database animations mapped successfully.")
	return true


func _initialize_motion_matching() -> bool:
	print("\n----------------------------------------")
	print("INITIALIZING C++ MOTION MATCHING")
	print("----------------------------------------")

	motion_matching = MotionMatchingSearch.new()
	if motion_matching == null:
		push_error("Could not create MotionMatchingSearch.")
		return false

	if not motion_matching.load_database(DATABASE_PATH):
		push_error(
			"C++ database loading failed: " +
			motion_matching.get_last_error()
		)
		return false

	print("C++ database loaded successfully.")
	print("Total animations: ", motion_matching.get_animation_count())
	print("Total samples: ", motion_matching.get_sample_count())
	print("Eligible animations: ", motion_matching.get_eligible_animation_count())
	print("Eligible samples: ", motion_matching.get_eligible_sample_count())
	return true


func _start_motion_matching() -> void:
	print("\n----------------------------------------")
	print("STARTING MOTION MATCHING")
	print("----------------------------------------")

	motion_matching_started = true
	_update_motion_match()

	if motion_matching_started:
		print("\nMotion Matching is running.")
		print("Search interval: ", MATCH_INTERVAL, " seconds")
		print("C++ continuous search: enabled")
		print("AnimationNodeAnimation loop mode: LOOP_LINEAR")


func _get_current_animation_time() -> float:
	if current_animation_index < 0 or current_animation_duration <= 0.0:
		return -1.0

	var absolute_time := (
		current_animation_start_timestamp +
		elapsed_since_animation_selection
	)
	return fposmod(absolute_time, current_animation_duration)


func _update_motion_match() -> void:
	var current_time := _get_current_animation_time()

	var search_result: Dictionary = motion_matching.search_best_match_continuous(
		DESIRED_VELOCITY,
		DESIRED_FUTURE_POSITIONS,
		DESIRED_FACING_YAW,
		current_animation_index,
		current_time,
		ANIMATION_SWITCH_PENALTY,
		SAME_ANIMATION_TIME_WEIGHT
	)

	if search_result.is_empty() or not bool(search_result.get("success", false)):
		push_error("Continuous motion matching search failed: " + str(search_result))
		motion_matching_started = false
		return

	var animation_index: int = int(search_result.get("animation_index", -1))
	var sample_index: int = int(search_result.get("sample_index", -1))
	var sample_time: float = float(search_result.get("time", 0.0))

	if animation_index < 0 or animation_index >= database_animations.size():
		push_error("Search returned an invalid animation index.")
		motion_matching_started = false
		return

	if animation_index >= animation_lookup.size():
		push_error("Animation lookup index is out of range.")
		motion_matching_started = false
		return

	var runtime_animation_path: String = animation_lookup[animation_index]
	if runtime_animation_path.is_empty():
		push_error("Selected animation has no runtime mapping.")
		motion_matching_started = false
		return

	var selected_entry: Dictionary = database_animations[animation_index]
	var animation_duration: float = float(selected_entry.get("duration", 0.0))

	if not character_player.has_animation(runtime_animation_path):
		push_error("Selected runtime animation does not exist.")
		motion_matching_started = false
		return

	if animation_duration <= 0.0 or sample_time < 0.0 or sample_time >= animation_duration:
		push_error("Selected animation timestamp/duration is invalid.")
		motion_matching_started = false
		return

	# Do not restart a clip that is already playing. The C++ search accounts
	# for temporal continuity and picks the best phase in the current clip.
	if animation_index == current_animation_index:
		skipped_restart_count += 1
		return

	var state_machine := animation_tree.tree_root as AnimationNodeStateMachine
	var run_state := state_machine.get_node("Run") as AnimationNodeAnimation

	run_state.animation = runtime_animation_path
	run_state.use_custom_timeline = true
	run_state.timeline_length = animation_duration
	run_state.stretch_time_scale = false

	# IMPORTANT: custom timeline playback uses this node-level loop setting.
	# Without it, the state can stop at the clip end while our own clock wraps.
	run_state.loop_mode = Animation.LOOP_LINEAR

	run_state.start_offset = sample_time

	var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		push_error("AnimationTree playback not found.")
		motion_matching_started = false
		return

	playback.start("Run", true)
	animation_tree.advance(0.0)
	animation_tree.get_root_motion_position() # Discard seek delta.

	var previous_animation_index := current_animation_index

	current_animation_path = runtime_animation_path
	current_animation_index = animation_index
	current_animation_duration = animation_duration
	current_animation_start_timestamp = sample_time
	elapsed_since_animation_selection = 0.0

	match_count += 1
	if previous_animation_index >= 0:
		switch_count += 1

	print("\n========== ANIMATION SELECTION #", match_count, " ==========")
	print("Animation: ", selected_entry.get("name", "Unknown"))
	print("Animation index: ", animation_index)
	print("Sample index: ", sample_index)
	print("Selected source timestamp: ", sample_time)
	print("Duration: ", animation_duration)
	print("Runtime path: ", runtime_animation_path)
	print("Node loop mode: ", run_state.loop_mode, " (1 = LOOP_LINEAR)")
	print("Matched velocity: ", search_result.get("velocity", "N/A"))
	print("Base cost: ", search_result.get("base_cost", "N/A"))
	print("Continuity cost: ", search_result.get("continuity_cost", "N/A"))
	print("Selection score: ", search_result.get("selection_score", "N/A"))
	print("Current absolute clip time: ", _get_current_animation_time())
	print("Animation switches: ", switch_count)
	print("Same-clip decisions (no restart): ", skipped_restart_count)
	print("========================================")


func _physics_process(delta: float) -> void:
	if not motion_matching_started or delta <= 0.0:
		return

	if current_animation_index >= 0:
		elapsed_since_animation_selection += delta

	var position_before: Vector3 = global_position
	var root_motion: Vector3 = animation_tree.get_root_motion_position()
	var world_motion: Vector3 = global_transform.basis * root_motion

	last_root_motion = world_motion
	velocity = world_motion / delta
	move_and_slide()

	var position_after: Vector3 = global_position
	var actual_displacement: Vector3 = position_after - position_before

	match_timer += delta
	debug_timer += delta

	if debug_timer >= DEBUG_INTERVAL:
		var diagnostic_interval := debug_timer
		debug_timer = 0.0

		var interval_displacement: Vector3 = global_position - debug_previous_position
		var actual_world_velocity: Vector3 = interval_displacement / diagnostic_interval
		debug_previous_position = global_position

		print("\n========== PHYSICAL MOVEMENT DIAGNOSTICS ==========")
		print("CharacterBody3D world position: ", global_position)
		print("Actual displacement: ", interval_displacement)
		print("Actual world velocity: ", actual_world_velocity)
		print("Root motion this frame: ", last_root_motion)
		print("Velocity passed to move_and_slide(): ", velocity)
		print("Absolute source-animation time: ", _get_current_animation_time())
		print("Animation: ", current_animation_path)
		print("Animation switches: ", switch_count)
		print("Same-clip decisions (no restart): ", skipped_restart_count)
		print("On floor: ", is_on_floor())
		print("On wall: ", is_on_wall())
		print("On ceiling: ", is_on_ceiling())

		if get_slide_collision_count() > 0:
			var collision := get_slide_collision(0)
			print("First collision normal: ", collision.get_normal())
		else:
			print("No slide collisions detected.")

		print("====================================================")

	if match_timer >= MATCH_INTERVAL:
		match_timer = 0.0
		_update_motion_match()
