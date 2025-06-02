@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	print("Starting GltfImportAnimatableBody.gd post import...")
	for child: Node in scene.get_children():
		print("processing: %s" % [child.name])
		if child is StaticBody3D:
			var static_body3d: StaticBody3D = child as StaticBody3D
			print("Processing 'StaticBody3D' by reparenting collision shapes to animatable body: %s" % [child.name])
			for collision_shape: CollisionShape3D in static_body3d.get_children():
				var local_transform = static_body3d.transform
				collision_shape.owner = null
				static_body3d.remove_child(collision_shape)
				scene.add_child(collision_shape)
				collision_shape.transform = local_transform
				collision_shape.set_owner(scene)
			child.queue_free()
	return scene
