class_name CameraRecoilSpring
extends RefCounted

## Procedural damped-harmonic spring recoil rig for LIALO's first-person Camera3D.
## Produces crisp tactile table-slam bumps and score-proportional impact kicks
## without drifting camera base orientation or exploding on frame drops.

const POS_STIFFNESS := 210.0
const POS_DAMPING := 17.5
const ROT_STIFFNESS := 190.0
const ROT_DAMPING := 16.0
const FOV_STIFFNESS := 180.0
const FOV_DAMPING := 15.5

var pos_offset := Vector3.ZERO
var pos_vel := Vector3.ZERO
var rot_offset_deg := Vector3.ZERO
var rot_vel_deg := Vector3.ZERO
var fov_offset := 0.0
var fov_vel := 0.0


func reset() -> void:
	pos_offset = Vector3.ZERO
	pos_vel = Vector3.ZERO
	rot_offset_deg = Vector3.ZERO
	rot_vel_deg = Vector3.ZERO
	fov_offset = 0.0
	fov_vel = 0.0


## Gentle downward wood-slam impulse as cards strike the felt surface.
func trigger_slam_tap(card_index: int = 0) -> void:
	var dir_x := -1.0 if (card_index % 2 == 0) else 1.0
	pos_vel += Vector3(dir_x * 0.14, -0.34, 0.0)
	rot_vel_deg += Vector3(-12.0, dir_x * 4.5, dir_x * 16.0)
	fov_vel += 9.5


## Major calculation impact scaled logarithmically by achieved score & multiplier.
func trigger_score_recoil(score_pts: int, eff_mult: float, intensity_scale: float = 1.0) -> void:
	var score_log := log(maxf(12.0, float(score_pts)))
	var mult_log := log(maxf(1.0, eff_mult))
	var mag := clampf((0.26 + score_log * 0.11 + mult_log * 0.18) * intensity_scale, 0.25, 1.55)
	var dir_x := -1.0 if randf() < 0.5 else 1.0

	pos_vel += Vector3(dir_x * 0.22 * mag, -0.46 * mag, 0.0)
	rot_vel_deg += Vector3(-18.0 * mag, dir_x * 6.5 * mag, dir_x * 26.0 * mag)
	fov_vel -= 22.0 * mag # Sharp punch-in zoom snap


func step(delta: float) -> void:
	var dt := clampf(delta, 0.0005, 0.025)

	var pos_acc := (-POS_STIFFNESS * pos_offset) - (POS_DAMPING * pos_vel)
	pos_vel += pos_acc * dt
	pos_offset += pos_vel * dt

	var rot_acc := (-ROT_STIFFNESS * rot_offset_deg) - (ROT_DAMPING * rot_vel_deg)
	rot_vel_deg += rot_acc * dt
	rot_offset_deg += rot_vel_deg * dt

	var fov_acc := (-FOV_STIFFNESS * fov_offset) - (FOV_DAMPING * fov_vel)
	fov_vel += fov_acc * dt
	fov_offset += fov_vel * dt


func apply_to_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	cam.h_offset = clampf(pos_offset.x, -0.08, 0.08)
	cam.v_offset = clampf(pos_offset.y, -0.08, 0.08)
	cam.rotation_degrees.z = clampf(rot_offset_deg.z, -4.5, 4.5)


func get_pitch_kick() -> float:
	return clampf(rot_offset_deg.x, -4.2, 4.2)


func get_fov_kick() -> float:
	return clampf(fov_offset, -5.0, 4.0)
