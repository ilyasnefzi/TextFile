extends SceneTree

const ANIMATION_FOLDER := "res://Assets/Animations/"
const REPORT_PATH := "user://animation_root_report.txt"

const POSITION_MOVEMENT_THRESHOLD := 0.02
const ROTATION_THRESHOLD_DEGREES := 1.0


func _initialize() -> void:
	call_deferred("_run_scan")


func _run_scan() -> void:
	var report := PackedStringArray()

	report.append("========== ROOT MOTION ANALYSIS ==========")
	report.append("")

	var directory := DirAccess.open(ANIMATION_FOLDER)

	if directory == null:
		push_error("Cannot open animation folder: " + ANIMATION_FOLDER)
		quit()
		return

	var files := directory.get_files()
	files.sort()

	var total_animations := 0
	var animations_with_position_track := 0
	var animations_with_actual_translation := 0
	var animations_with_horizontal_translation := 0
	var animations_with_rotation := 0
	var animations_with_actual_rotation := 0
	var animations_without_root_tracks := 0

	for file_name in files:
		if not file_name.to_lower().ends_with(".glb"):
			continue

		var file_path := ANIMATION_FOLDER + file_name
		var packed_scene := load(file_path) as PackedScene

		if packed_scene == null:
			report.append("ERROR: Could not load " + file_name)
			continue

		var instance := packed_scene.instantiate()
		root.add_child(instance)

		var animation_players: Array[AnimationPlayer] = []
		_collect_animation_players(instance, animation_players)

		report.append("")
		report.append("========== FILE: " + file_name + " ==========")

		if animation_players.is_empty():
			report.append("WARNING: No AnimationPlayer found.")
			instance.queue_free()
			continue

		for player in animation_players:
			var animation_names := player.get_animation_list()

			for animation_name in animation_names:
				var animation := player.get_animation(animation_name)

				if animation == null:
					continue

				total_animations += 1

				var position_track_found := false
				var rotation_track_found := false

				var clip_has_translation := false
				var clip_has_horizontal_translation := false
				var clip_has_rotation := false

				report.append("")
				report.append("Animation: " + animation_name)
				report.append("Duration: %.3f seconds" % animation.length)

				for track_index in range(animation.get_track_count()):
					var track_path := str(animation.track_get_path(track_index))
					var track_type := animation.track_get_type(track_index)

					# Only inspect the bone named "root".
					if not track_path.to_lower().contains(":root"):
						continue

					if track_type == Animation.TYPE_POSITION_3D:
						position_track_found = true

						var key_count := animation.track_get_key_count(track_index)

						if key_count < 2:
							report.append("Root position: Less than 2 keys")
							continue

						var first_position: Vector3
						var previous_position: Vector3
						var last_position: Vector3

						var total_distance := 0.0
						var horizontal_distance := 0.0

						var min_position := Vector3(INF, INF, INF)
						var max_position := Vector3(-INF, -INF, -INF)

						for key_index in range(key_count):
							var value: Variant = animation.track_get_key_value(
								track_index,
								key_index
							)

							if not value is Vector3:
								continue

							var position: Vector3 = value

							if key_index == 0:
								first_position = position
								previous_position = position

							else:
								total_distance += previous_position.distance_to(position)

								var horizontal_step := Vector2(
									position.x - previous_position.x,
									position.z - previous_position.z
								)

								horizontal_distance += horizontal_step.length()
								previous_position = position

							last_position = position

							min_position.x = minf(min_position.x, position.x)
							min_position.y = minf(min_position.y, position.y)
							min_position.z = minf(min_position.z, position.z)

							max_position.x = maxf(max_position.x, position.x)
							max_position.y = maxf(max_position.y, position.y)
							max_position.z = maxf(max_position.z, position.z)

						var net_delta := last_position - first_position

						var net_horizontal_distance := Vector2(
							net_delta.x,
							net_delta.z
						).length()

						clip_has_translation = total_distance > POSITION_MOVEMENT_THRESHOLD
						clip_has_horizontal_translation = horizontal_distance > POSITION_MOVEMENT_THRESHOLD

						report.append("Root position track: " + track_path)
						report.append("Position keys: " + str(key_count))
						report.append("First position: " + str(first_position))
						report.append("Last position: " + str(last_position))
						report.append("Net displacement: " + str(net_delta))
						report.append("Net horizontal displacement: %.4f m" % net_horizontal_distance)
						report.append("Total 3D path distance: %.4f m" % total_distance)
						report.append("Total horizontal path distance: %.4f m" % horizontal_distance)
						report.append("Position range: " + str(min_position) + " -> " + str(max_position))

					elif track_type == Animation.TYPE_ROTATION_3D:
						rotation_track_found = true

						var key_count := animation.track_get_key_count(track_index)

						if key_count < 2:
							report.append("Root rotation: Less than 2 keys")
							continue

						var first_rotation: Quaternion
						var previous_rotation: Quaternion
						var last_rotation: Quaternion

						var total_rotation_degrees := 0.0

						for key_index in range(key_count):
							var value: Variant = animation.track_get_key_value(
								track_index,
								key_index
							)

							if not value is Quaternion:
								continue

							var rotation: Quaternion = value.normalized()

							if key_index == 0:
								first_rotation = rotation
								previous_rotation = rotation
							else:
								var dot_value := clampf(
									absf(previous_rotation.dot(rotation)),
									0.0,
									1.0
								)

								total_rotation_degrees += rad_to_deg(
									2.0 * acos(dot_value)
								)

								previous_rotation = rotation

							last_rotation = rotation

						var net_dot := clampf(
							absf(first_rotation.dot(last_rotation)),
							0.0,
							1.0
						)

						var net_rotation_degrees := rad_to_deg(
							2.0 * acos(net_dot)
						)

						clip_has_rotation = total_rotation_degrees > ROTATION_THRESHOLD_DEGREES

						report.append("Root rotation track: " + track_path)
						report.append("Rotation keys: " + str(key_count))
						report.append("Net rotation: %.2f degrees" % net_rotation_degrees)
						report.append("Total rotation across keys: %.2f degrees" % total_rotation_degrees)

				if position_track_found:
					animations_with_position_track += 1

				if rotation_track_found:
					animations_with_rotation += 1

				if clip_has_translation:
					animations_with_actual_translation += 1

				if clip_has_horizontal_translation:
					animations_with_horizontal_translation += 1

				if clip_has_rotation:
					animations_with_actual_rotation += 1

				if not position_track_found and not rotation_track_found:
					animations_without_root_tracks += 1
					report.append("WARNING: No root position or rotation track found.")

				report.append("")

		instance.queue_free()

	report.append("")
	report.append("========== SUMMARY ==========")
	report.append("Total animations: " + str(total_animations))
	report.append("Animations with root position tracks: " + str(animations_with_position_track))
	report.append("Animations with root rotation tracks: " + str(animations_with_rotation))
	report.append("Animations with measurable root translation: " + str(animations_with_actual_translation))
	report.append("Animations with measurable horizontal translation: " + str(animations_with_horizontal_translation))
	report.append("Animations with measurable root rotation: " + str(animations_with_actual_rotation))
	report.append("Animations without root tracks: " + str(animations_without_root_tracks))
	report.append("")
	report.append("Movement threshold: %.3f m" % POSITION_MOVEMENT_THRESHOLD)
	report.append("Rotation threshold: %.1f degrees" % ROTATION_THRESHOLD_DEGREES)
	report.append("================================")

	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)

	if output == null:
		push_error("Could not write report: " + REPORT_PATH)
		quit()
		return

	output.store_string("\n".join(report))
	output.close()

	print("")
	print("Root motion analysis completed.")
	print("Total animations: ", total_animations)
	print("Animations with measurable translation: ", animations_with_actual_translation)
	print("Animations with measurable horizontal translation: ", animations_with_horizontal_translation)
	print("Animations with measurable rotation: ", animations_with_actual_rotation)
	print("Report saved to: ", REPORT_PATH)

	quit()


func _collect_animation_players(
	node: Node,
	result: Array[AnimationPlayer]
) -> void:
	if node is AnimationPlayer:
		result.append(node)

	for child in node.get_children():
		_collect_animation_players(child, result)
