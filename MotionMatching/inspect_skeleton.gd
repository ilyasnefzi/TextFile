extends SceneTree

func _initialize():
	var scene = load("res://Assets/Characters/Character_01.glb").instantiate()

	var skeleton = find_skeleton(scene)

	if skeleton == null:
		print("ERROR: Skeleton3D not found.")
		quit()
		return

	print("\n========== SKELETON BONES ==========")
	print("Total bones: ", skeleton.get_bone_count())

	for i in range(skeleton.get_bone_count()):
		var parent = skeleton.get_bone_parent(i)
		var parent_name = "None" if parent == -1 else skeleton.get_bone_name(parent)

		print(
			"Bone ", i,
			" | Name: ", skeleton.get_bone_name(i),
			" | Parent: ", parent_name
		)

	print("===================================\n")

	scene.free()
	quit()


func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		var result = find_skeleton(child)
		if result != null:
			return result

	return null
