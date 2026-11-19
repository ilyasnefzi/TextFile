extends Node

var motion_matching: MotionMatchingSearch


func _ready() -> void:

	print("\n========== UNIQUE ANIMATION COVERAGE TEST ==========")

	motion_matching = MotionMatchingSearch.new()

	var database_path := "user://motion_database.json"

	print("Loading database: ", database_path)

	var loaded: bool = motion_matching.load_database(database_path)

	if not loaded:
		print("\nDATABASE LOAD FAILED")
		print("Error: ", motion_matching.get_last_error())
		return

	print("\nDATABASE LOADED SUCCESSFULLY")

	print("Total animations: ", motion_matching.get_animation_count())
	print("Total samples: ", motion_matching.get_sample_count())

	print("Eligible animations: ", motion_matching.get_eligible_animation_count())
	print("Eligible samples: ", motion_matching.get_eligible_sample_count())

	analyze_unique_animations()


func analyze_unique_animations() -> void:

	print("\n========== FASTEST UNIQUE ANIMATIONS ==========")

	var report: Dictionary = motion_matching.analyze_fastest_unique_animations(20)

	if not report.get("success", false):
		print("Analysis failed: ", report.get("error", "Unknown error"))
		return

	print("Eligible animations: ", report["eligible_animations"])
	print("Eligible samples: ", report["eligible_samples"])

	print("Directional alignment: ", report["direction_alignment_degrees"], " degrees")

	print("Total directional samples: ", report["total_directional_samples"])

	print("Total unique directional animations: ", report["total_unique_directional_animations"])

	for direction_data in report["directions"]:

		print("\n========================================")
		print(direction_data["direction"].to_upper())
		print("========================================")

		print("Directional samples: ", direction_data["available_directional_samples"])
		print("Unique animations: ", direction_data["unique_animation_count"])

		for animation in direction_data["fastest_animations"]:

			print(
				"#", animation["rank"],
				" | ", animation["family"].to_upper(),
				" | Speed: ", snappedf(animation["projected_speed"], 0.01),
				" | Time: ", snappedf(animation["best_sample_time"], 0.01),
				" | Velocity: ", animation["velocity"],
				" | ", animation["animation_name"]
			)

	print("\n========== UNIQUE ANIMATION ANALYSIS COMPLETE ==========")
