class_name HeroVisual
extends KayKitVisual
## The diner cook (S4 Task 7b, D-191): the Barbarian in the apron atlas, a frying pan in the right hand and the chef
## hat on the head bone. Since D-201 all of it is baked into art/characters/baked/hero.res (one draw call, the whole
## body on the apron atlas, so the sleeves are white too; tools/bake_characters.gd holds the pan and hat placement),
## and KayKitVisual swaps it in. Visual-only: no gameplay state, no Rng.

## E6 (D-294.8, flag on): the hero is drawn in front of the pads' world labels, which have no depth test and so can only be ordered by render priority.
## Every surface of the hero becomes an ALPHA material (the transparent pass, where labels live) that WRITES DEPTH (DEPTH_DRAW_ALWAYS: a pre-pass is
## skipped by some mobile GPUs in the Compatibility renderer, and then everything drawn after him would paint over him) at `priority`. The materials are
## copies set as surface overrides on this visual's own meshes: the shared originals are never touched. Called once from Hero.setup when the flag is on.
func draw_after_labels(priority: int) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is BaseMaterial3D:
				m.set_surface_override_material(s, front_copy(mat, priority))

## A copy of `mat` that draws in the transparent pass at `priority` and writes depth.
static func front_copy(mat: BaseMaterial3D, priority: int) -> BaseMaterial3D:
	var d := mat.duplicate() as BaseMaterial3D
	d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	d.render_priority = priority
	return d
