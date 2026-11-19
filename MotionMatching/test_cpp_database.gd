extends Node


func _ready() -> void:
	print("\n========== CONTINUOUS SEARCH TEST ==========")

	var motion_matching := MotionMatchingSearch.new()

	var database_path := "user://motion_database.json"

	print("Loading database: ", database_path)

	if not motion_matching.load_database(database_path):
		print("DATABASE LOAD FAILED")
		print(motion_matching.get_last_error())
		return

	print("Database loaded successfully.")
	print("Animations: ", motion_matching.get_animation_count())
	print("Eligible animations: ", motion_matching.get_eligible_animation_count())

	var desired_velocity := Vector3(0.0, 0.0, 4.5)

	var desired_future_positions: Array = [
		Vector3(0.0, 0.0, 0.9),
		Vector3(0.0, 0.0, 1.8),
		Vector3(0.0, 0.0, 2.7)
	]

	var desired_facing_yaw := 0.0

	# -1 means this is the initial search (no continuity penalty).
	var current_animation_index := -1
	var current_animation_time := 0.0

	var animation_switch_penalty := 1.0
	var same_animation_time_weight := 0.5

	print("\nRunning continuous search...")

	var start_time := Time.get_ticks_usec()

	var result: Dictionary = motion_matching.search_best_match_continuous(
		desired_velocity,
		desired_future_positions,
		desired_facing_yaw,
		current_animation_index,
		current_animation_time,
		animation_switch_penalty,
		same_animation_time_weight
	)

	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000.0

	print("\n========== SEARCH RESULT ==========")
	print(result)
	print("\nSearch time: ", elapsed_ms, " ms")
	print("\n========== TEST FINISHED ==========")
