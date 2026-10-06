class_name CameraMath
extends RefCounted
## Camera placement and projection shared by CameraRig and tests (D-071, D-090, D-112).

const ASPECT := 720.0 / 1280.0
const ASPECT_MIN := 9.0 / 21.0
const ASPECT_MAX := 21.0 / 9.0
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

## E5 spec 7.5: the camera at `focus` pulled back along its view line to `zoom` x camera_distance (zoom 1.0 is
## camera_transform exactly). Shared by CameraRig's reveal and the reveal's fit so both place the camera alike.
static func zoomed_transform(focus: Vector2, ui: UiTuning, zoom: float) -> Transform3D:
	var xf := camera_transform(focus, ui)
	if is_equal_approx(zoom, 1.0):
		return xf
	var target := Vector3(focus.x, 0.0, focus.y)
	xf.origin = target + (xf.origin - target) * zoom
	return xf

## D-153 (extends D-145): the supported window aspect range is [ASPECT_MIN, ASPECT_MAX] = 9:21 .. 21:9.
## Outside it the view is clamped, never stretched: narrower than 9:21 keeps the vertical FOV of 9:21
## (KEEP_HEIGHT, so the view never gets taller); wider than 21:9 keeps the horizontal FOV of 21:9
## (KEEP_WIDTH, so the view never gets wider). The ground therefore only has to cover that range.
## True when the lens keeps the horizontal FOV (Camera3D.KEEP_WIDTH): from 9:21 up to 9:16 (D-145)
## and beyond 21:9 (D-153). False (KEEP_HEIGHT) between 9:16 and 21:9 and below 9:21.
static func keeps_width(aspect: float) -> bool:
	if aspect < ASPECT_MIN:
		return false
	return aspect <= ASPECT + 1e-6 or aspect > ASPECT_MAX

## Vertical FOV (degrees) of the portrait view; kept with KEEP_HEIGHT from 9:16 to 21:9 (D-153).
static func portrait_fov_v(ui: UiTuning) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(ui.camera_fov_h) / 2.0) / ASPECT))

## Vertical FOV (degrees) used below ASPECT_MIN: the one 9:21 shows with KEEP_WIDTH (D-153).
static func tallest_fov_v(ui: UiTuning) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(ui.camera_fov_h) / 2.0) / ASPECT_MIN))

## Horizontal FOV (degrees) used above ASPECT_MAX: the one 21:9 shows with KEEP_HEIGHT (D-153).
static func widest_fov_h(ui: UiTuning) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(portrait_fov_v(ui)) / 2.0) * ASPECT_MAX))

## Field of view (degrees) matching keeps_width(aspect): horizontal when true, vertical when false.
static func lens_fov(ui: UiTuning, aspect: float) -> float:
	if aspect < ASPECT_MIN:
		return tallest_fov_v(ui)
	if aspect > ASPECT_MAX:
		return widest_fov_h(ui)
	return ui.camera_fov_h if keeps_width(aspect) else portrait_fov_v(ui)

## D-145/D-153: KEEP_WIDTH from 9:21 to 9:16, KEEP_HEIGHT (portrait vertical FOV) from 9:16 to 21:9,
## clamped outside 9:21..21:9. CameraRig (Task 28) must use keeps_width() and lens_fov() (or apply_lens).
static func projection(ui: UiTuning, aspect: float = ASPECT) -> Projection:
	var keep_w := keeps_width(aspect)
	# flip_fov = true: the fov is horizontal, matching Camera3D.KEEP_WIDTH.
	return Projection.create_perspective(lens_fov(ui, aspect), aspect, Z_NEAR, Z_FAR, keep_w)

## D-145/D-153: sets keep_aspect, fov, near and far on a real Camera3D for the given viewport aspect.
static func apply_lens(cam: Camera3D, ui: UiTuning, aspect: float) -> void:
	cam.keep_aspect = Camera3D.KEEP_WIDTH if keeps_width(aspect) else Camera3D.KEEP_HEIGHT
	cam.fov = lens_fov(ui, aspect)
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
