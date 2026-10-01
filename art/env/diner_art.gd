extends Node3D
## Root script of art/env/diner.tscn (S4 Task 11). The diner fades through these boxes, not through one merged AABB, so
## the tall sign plank can't make the whole footprint fade (OccluderFade tests each grown box; any hit fades).
## Local space, ground at y = 0: walls plus parapet, the chimney, and the plank, posts and Board.
## D-201 perf note: the Board is a Label3D, so it costs about 2 draws (outline + fill) on top of the diner's 2 surfaces.
var occluder_boxes: Array[AABB] = [
	AABB(Vector3(-4.0, 0.0, -4.0), Vector3(8.0, 3.4, 8.0)),
	AABB(Vector3(2.9, 3.0, -3.75), Vector3(0.6, 1.8, 0.9)),
	AABB(Vector3(-2.2, 3.0, 3.4), Vector3(4.4, 2.1, 0.4)),
]
