extends MeshInstance3D
## The coin scene's mesh node: takes the shared procedural CoinMesh at instantiation, so PileMesh (which reads the first
## MeshInstance3D's mesh) and FlyFx see the same one mesh. No Kenney coin any more.

func _init() -> void:
	mesh = CoinMesh.get_mesh()
