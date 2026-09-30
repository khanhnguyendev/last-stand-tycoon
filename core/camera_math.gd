class_name CameraMath
extends RefCounted
## Camera placement and projection shared by CameraRig and tests (D-071, D-090, D-112).

const ASPECT := 720.0 / 1280.0
const FOCUS_MIN := Vector2(-17, -20)
const FOCUS_MAX := Vector2(17, 8)
const Z_NEAR := 0.1
const Z_FAR := 200.0

static func focus_for(hero_xz: Vector2) -> Vector2:
	return hero_xz.clamp(FOCUS_MIN, FOCUS_MAX)

static func camera_transform(focus: Vector2, ui: UiTuning) -> Transform3D:
	var pitch := deg_to_rad(-ui.camera_pitch)  # 55° down
	var target := Vector3(focus.x, 0.0, focus.y)
	var pos := target + Vector3(0.0, sin(pitch), cos(pitch)) * ui.camera_distance
	return Transform3D(Basis(), pos).looking_at(target, Vector3.UP)

static func keeps_width(aspect: float) -> bool:
	return aspect <= ASPECT + 1e-6

## Vertical FOV (degrees) of the portrait view; wider windows keep it with KEEP_HEIGHT (D-145).
static func portrait_fov_v(ui: UiTuning) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(ui.camera_fov_h) / 2.0) / ASPECT))

## D-145: KEEP_WIDTH up to 9:16; wider windows keep the portrait vertical FOV (KEEP_HEIGHT).
## CameraRig (Task 28) must use keeps_width() for Camera3D.keep_aspect and the matching fov.
static func projection(ui: UiTuning, aspect: float = ASPECT) -> Projection:
	if keeps_width(aspect):
		# flip_fov = true: camera_fov_h is horizontal, matching Camera3D.KEEP_WIDTH.
		return Projection.create_perspective(ui.camera_fov_h, aspect, Z_NEAR, Z_FAR, true)
	return Projection.create_perspective(portrait_fov_v(ui), aspect, Z_NEAR, Z_FAR, false)

## D-145: sets keep_aspect, fov, near and far on a real Camera3D for the given viewport aspect.
static func apply_lens(cam: Camera3D, ui: UiTuning, aspect: float) -> void:
	if keeps_width(aspect):
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = ui.camera_fov_h
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = portrait_fov_v(ui)
	cam.near = Z_NEAR
	cam.far = Z_FAR

static func to_ndc(world: Vector3, xform: Transform3D, proj: Projection) -> Vector3:
	var v := xform.affine_inverse() * world
	var c := proj * Vector4(v.x, v.y, v.z, 1.0)
	if c.w <= 0.0:
		return Vector3(INF, INF, INF)
	return Vector3(c.x / c.w, c.y / c.w, c.z / c.w)

static func on_screen(world: Vector3, xform: Transform3D, proj: Projection) -> bool:
	var n := to_ndc(world, xform, proj)
	return absf(n.x) <= 1.0 and absf(n.y) <= 1.0
