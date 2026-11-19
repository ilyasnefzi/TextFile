extends Node


const TEST_SPEED := 4.5
const FUTURE_TIMES := [0.2, 0.4, 0.6]
const TOP_MATCHES_TO_PRINT := 10

# Combat mode: character maintains its current facing direction.
# Zero means no relative yaw offset from the current facing.
const DESIRED_FACING_YAW := 0.0


func _ready() -> void:

	print("")
	print("========== 8-DIRECTIONAL MOTION MATCHING TEST ==========")

	var search = MotionMatchingSearch.new()

	var loaded: bool = search.load_database("user://motion_database.json")

	if not loaded:
		print("DATABASE LOADING FAILED")
		print(search.get_last_error())
		return

	print("Database loaded successfully.")
	print("Animations: ", search.get_animation_count())
	print("Samples: ", search.get_sample_count())

	var tests := [
		{"name": "FORWARD", "direction": Vector3(0, 0, 1)},
		{"name": "BACKWARD", "direction": Vector3(0, 0, -1)},
		{"name": "LEFT STRAFE", "direction": Vector3(-1, 0, 0)},
		{"name": "RIGHT STRAFE", "direction": Vector3(1, 0, 0)},
		{"name": "FORWARD LEFT", "direction": Vector3(-1, 0, 1).normalized()},
		{"name": "FORWARD RIGHT", "direction": Vector3(1, 0, 1).normalized()},
		{"name": "BACKWARD LEFT", "direction": Vector3(-1, 0, -1).normalized()},
		{"name": "BACKWARD RIGHT", "direction": Vector3(1, 0, -1).normalized()}
	]

	for test in tests:
		run_direction_test(search, test)

	print("")
	print("========== 8-DIRECTIONAL TESTS COMPLETED ==========")


func run_direction_test(search, test: Dictionary) -> void:

	var direction: Vector3 = test["direction"]
	var desired_velocity: Vector3 = direction * TEST_SPEED

	var desired_future_positions: Array = []

	for time in FUTURE_TIMES:
		desired_future_positions.append(
			direction * TEST_SPEED * time
		)

	var start_time := Time.get_ticks_usec()

	var result: Dictionary = search.search_best_match(
		desired_velocity,
		desired_future_positions,
		DESIRED_FACING_YAW
	)

	var end_time := Time.get_ticks_usec()
	var search_time_ms: float = (end_time - start_time) / 1000.0

	print("")
	print("========================================")
	print("TEST: ", test["name"])
	print("========================================")

	if not result.get("success", false):
		print("SEARCH FAILED: ", result.get("error", "Unknown error"))
		return

	print("Desired velocity: ", desired_velocity)
	print("Desired facing yaw: ", rad_to_deg(DESIRED_FACING_YAW), " degrees")

	print("")
	print("BEST MATCH")
	print("----------------------------------------")

	print("Animation: ", result.get("animation_name", "N/A"))
	print("Animation index: ", result.get("animation_index", -1))
	print("Sample index: ", result.get("sample_index", -1))
	print("Timestamp: ", result.get("time", -1.0))

	var yaw: float = result.get("yaw", 0.0)

	print(
		"Sample yaw: ",
		yaw,
		" radians (",
		rad_to_deg(yaw),
		" degrees)"
	)

	print("Raw velocity: ", result.get("raw_velocity", Vector3.ZERO))
	print("Local-facing velocity: ", result.get("velocity", Vector3.ZERO))

	print("")
	print("COST BREAKDOWN")
	print("----------------------------------------")

	print("Velocity cost: ", result.get("velocity_cost", -1.0))
	print("Trajectory cost: ", result.get("trajectory_cost", -1.0))
	print("Facing cost: ", result.get("facing_cost", -1.0))
	print("Rotation cost: ", result.get("rotation_cost", -1.0))
	print("Total cost: ", result.get("cost", -1.0))

	print("")
	print("Future yaw changes: ", result.get("future_yaw_deltas_degrees", []))

	print("")
	print("TOP ", TOP_MATCHES_TO_PRINT, " CANDIDATES")
	print("----------------------------------------")

	if not result.has("top_matches"):
		print("Top matches were not returned by the C++ extension.")
	else:
		var candidates: Array = result["top_matches"]

		for candidate in candidates:

			print("")
			print(
				"#",
				candidate.get("rank", "?"),
				" | ",
				candidate.get("animation_name", "N/A")
			)

			print(
				"Time: ",
				candidate.get("time", -1.0),
				" | Yaw: ",
				candidate.get("yaw_degrees", 0.0),
				" degrees"
			)

			print("Local velocity: ", candidate.get("velocity", Vector3.ZERO))

			print(
				"Velocity cost: ",
				candidate.get("velocity_cost", -1.0),
				" | Trajectory cost: ",
				candidate.get("trajectory_cost", -1.0)
			)

			print("Facing cost: ", candidate.get("facing_cost", -1.0))
			print("Rotation cost: ", candidate.get("rotation_cost", -1.0))
			print("TOTAL COST: ", candidate.get("cost", -1.0))

			print(
				"Future yaw changes: ",
				candidate.get("future_yaw_deltas_degrees", [])
			)

	print("")
	print("Samples evaluated: ", result.get("samples_evaluated", 0))
	print("Search time: ", search_time_ms, " ms")
