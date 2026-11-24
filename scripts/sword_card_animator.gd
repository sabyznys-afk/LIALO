class_name SwordCardAnimator
extends RefCounted

## 3D World-Space Hand-Drawn Sword Card Scoring Animator
## No 2D HUD/UI elements — all visuals live physically over BattleTable3D
## and use crossed dual-sided (CULL_DISABLED) planes so both +Z and -Z
## multiplayer seats clearly see every beat.

const Toon = preload("res://scripts/toon_style.gd")
const SHADER_CEL_PATH := "res://shaders/sword_cel_sprite.gdshader"
const SHADER_BLADE_PATH := "res://shaders/sword_blade_cutout.gdshader"

const TEX_BLADE_MIST := "res://assets/vfx/sword_card/sword_blade_mist.png"
const TEX_BLADE_ROYAL := "res://assets/vfx/sword_card/sword_blade_royal.png"
const TEX_WEAPON_HALBERD := "res://assets/vfx/sword_card/weapon_halberd.png"
const TEX_WEAPON_STAFF := "res://assets/vfx/sword_card/weapon_staff.png"
const TEX_WEAPON_DAGGER := "res://assets/vfx/sword_card/weapon_dagger.png"
const TEX_WEAPON_MACE := "res://assets/vfx/sword_card/weapon_mace.png"
const TEX_WEAPON_SPEAR := "res://assets/vfx/sword_card/weapon_spear.png"
const TEX_WEAPON_SHIELD := "res://assets/vfx/sword_card/weapon_shield.png"
const TEX_SLASH_SHEET := "res://assets/vfx/sword_card/slash_cel_sheet.png"
const TEX_MIST_SHEET := "res://assets/vfx/sword_card/mist_veil_sheet.png"
const TEX_IMPACT_SHEET := "res://assets/vfx/sword_card/impact_sigil_sheet.png"
const TEX_SPARKS_SHEET := "res://assets/vfx/sword_card/ink_sparks_sheet.png"

const TEX_SFX_UNSHEATHE := "res://assets/audio/sfx_anim_sword_unsheathe.mp3"
const TEX_SFX_SLASH := "res://assets/audio/sfx_anim_sword_slash.mp3"

static var _shader_cel: Shader = null
static var _shader_blade: Shader = null
static var _sfx_unsheathe: AudioStream = null
static var _sfx_cleave_mist: AudioStream = null
static var _sfx_cleave_royal: AudioStream = null
static var _weapon_tex_cache: Dictionary = {}


static func _load_weapon_tex(path: String) -> Texture2D:
	if _weapon_tex_cache.has(path):
		return _weapon_tex_cache[path] as Texture2D
	var t := Toon.tex(path)
	if t != null:
		_weapon_tex_cache[path] = t
		return t
	var abs_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			var it := ImageTexture.create_from_image(img)
			_weapon_tex_cache[path] = it
			return it
	return Toon.tex(TEX_BLADE_ROYAL)


static func _pick_weapon_style(card_data: Dictionary, use_mist: bool) -> String:
	if use_mist:
		return "sword_mist"
	var cls := str(card_data.get("edition", card_data.get("card_class", "NORMAL"))).to_upper()
	var pid := str(card_data.get("power_id", "")).to_upper()
	var rank := str(card_data.get("rank", "")).to_upper()
	var suit := str(card_data.get("suit", "CERVEN")).to_upper()
	if cls == "MAGE" or pid in ["SPEC_ORACLE", "SPEC_MIRROR", "SPEC_ALCHEMIST"]:
		return "staff"
	if cls == "THIEF" or rank == "7" or pid in ["SPEC_HEX", "SPEC_PLAGUE"]:
		return "dagger"
	if rank == "E" or pid in ["SPEC_STORM", "SPEC_CHRONOS"]:
		return "spear"
	if cls == "MERCHANT" or rank == "10" or pid in ["SPEC_MIDAS", "SPEC_CROWN", "SPEC_GAMBLER"]:
		return "mace"
	if rank in ["H", "D"] or (rank in ["8", "9"] and suit == "ZELEN"):
		return "halberd"
	if pid in ["SPEC_SHIELD", "SPEC_PHOENIX", "SPEC_VAMPIRE", "SPEC_MAGNET", "SPEC_JESTER"] or rank in ["8", "9"]:
		return "shield"
	return "sword_royal"


static func play_sword_card_score_anim(
	table_node: Node3D,
	card_data: Dictionary,
	card_node: Node3D,
	attacker_is_player: bool,
	impact_pos: Vector3,
	score_pts: int = 20,
	eff_mult: float = 1.0,
	is_knight_mist: bool = false
) -> Node3D:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return null
	_ensure_assets()

	var cls := str(card_data.get("edition", card_data.get("card_class", "NORMAL"))).to_upper()
	var use_mist := is_knight_mist or (cls == "KNIGHT")

	var rig := _SwordVfxRig.new()
	rig.name = "SwordCardVfxRig"
	table_node.add_child(rig)
	var local_impact := table_node.to_local(impact_pos)
	rig.configure(
		table_node,
		card_data,
		card_node,
		attacker_is_player,
		local_impact,
		score_pts,
		eff_mult,
		use_mist,
		_shader_cel,
		_shader_blade,
		_sfx_unsheathe,
		_sfx_cleave_mist if use_mist else _sfx_cleave_royal
	)
	return rig


static func play_sword_card_mp_strike(
	table_node: Node3D,
	card_data: Dictionary,
	from_pos: Vector3,
	to_pos: Vector3,
	center_pos: Vector3,
	score_pts: int = 35,
	eff_mult: float = 1.5,
	is_knight_mist: bool = false
) -> Node3D:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return null
	_ensure_assets()

	var cls := str(card_data.get("edition", card_data.get("card_class", "NORMAL"))).to_upper()
	var use_mist := is_knight_mist or (cls == "KNIGHT")

	var l_from := table_node.to_local(from_pos)
	var l_to := table_node.to_local(to_pos)
	var l_center := table_node.to_local(center_pos)

	var dir_xz := Vector3(l_to.x - l_from.x, 0.0, l_to.z - l_from.z)
	if dir_xz.length_squared() < 0.001:
		dir_xz = Vector3(0.0, 0.0, -1.0)
	else:
		dir_xz = dir_xz.normalized()

	var rig := _SwordVfxRig.new()
	rig.name = "SwordCardMpVfxRig"
	table_node.add_child(rig)
	rig.position = Vector3(l_center.x, 0.0, l_center.z)
	rig.rotation.y = atan2(-dir_xz.x, -dir_xz.z)
	var tray_local := rig.to_local(table_node.to_global(Vector3(l_from.x, l_center.y + 0.018, l_from.z)))
	rig.configure(
		table_node,
		card_data,
		null,
		true,
		Vector3(0.0, l_center.y, 0.0),
		score_pts,
		eff_mult,
		use_mist,
		_shader_cel,
		_shader_blade,
		_sfx_unsheathe,
		_sfx_cleave_mist if use_mist else _sfx_cleave_royal,
		tray_local
	)
	return rig


static func _load_sfx_mp3(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var st := load(path)
		if st is AudioStream:
			if st is AudioStreamMP3:
				(st as AudioStreamMP3).loop = false
			return st
	if FileAccess.file_exists(path):
		var raw := FileAccess.get_file_as_bytes(path)
		if not raw.is_empty():
			var mp3 := AudioStreamMP3.load_from_buffer(raw)
			if mp3:
				mp3.loop = false
				return mp3
	return null


static func _ensure_assets() -> void:
	if _shader_cel == null:
		_shader_cel = load(SHADER_CEL_PATH) as Shader
	if _shader_blade == null:
		_shader_blade = load(SHADER_BLADE_PATH) as Shader
	if _sfx_unsheathe == null:
		_sfx_unsheathe = _load_sfx_mp3(TEX_SFX_UNSHEATHE)
		if _sfx_unsheathe == null:
			_sfx_unsheathe = _synth_unsheathe_wav()
	if _sfx_cleave_mist == null:
		_sfx_cleave_mist = _load_sfx_mp3(TEX_SFX_SLASH)
		if _sfx_cleave_mist == null:
			_sfx_cleave_mist = _synth_cleave_wav(true)
	if _sfx_cleave_royal == null:
		_sfx_cleave_royal = _load_sfx_mp3(TEX_SFX_SLASH)
		if _sfx_cleave_royal == null:
			_sfx_cleave_royal = _synth_cleave_wav(false)


static func _synth_unsheathe_wav() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.26
	var n := int(rate * dur)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var seed_val := 1337
	for i in range(n):
		var t := float(i) / float(rate)
		var u := t / dur
		seed_val = (seed_val * 1664525 + 1013904223) & 0x7fffffff
		var white := (float(seed_val % 2000) / 1000.0) - 1.0
		var env := sin(minf(1.0, u / 0.22) * PI * 0.5) * exp(-t * 8.5)
		var ring_freq := lerpf(940.0, 1480.0, u)
		var metallic := sin(TAU * ring_freq * t) * 0.38 + sin(TAU * (ring_freq * 1.62) * t) * 0.22 + sin(TAU * 2520.0 * t) * 0.14
		var scrape := white * (0.28 + 0.25 * sin(u * PI))
		var sample := clampf((metallic + scrape) * env * 0.72, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	return wav


static func _synth_cleave_wav(is_mist: bool) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.62
	var n := int(rate * dur)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var seed_val := 9001 if is_mist else 4242
	var phase := 0.0
	var dt := 1.0 / float(rate)
	for i in range(n):
		var t := float(i) / float(rate)
		seed_val = (seed_val * 1664525 + 1013904223) & 0x7fffffff
		var white := (float(seed_val % 2000) / 1000.0) - 1.0
		# Air cleave whoosh sweeping downward in frequency
		var whoosh_freq := lerpf(1650.0, 140.0, minf(1.0, t / 0.18))
		phase += whoosh_freq * dt
		var whoosh_env := exp(-t * 14.0) * sin(minf(1.0, t / 0.025) * PI * 0.5)
		var whoosh := (sin(TAU * phase) * 0.42 + white * 0.58) * whoosh_env
		# Felt impact bass punch at t = 0.03s
		var it := maxf(0.0, t - 0.028)
		var impact_env := exp(-it * 24.0) if t >= 0.028 else 0.0
		var thud := sin(TAU * lerpf(145.0, 52.0, minf(1.0, it / 0.11)) * it) * impact_env * 0.65
		# Resonant rune bell fifth
		var f1 := 1174.66 if is_mist else 880.0
		var f2 := 1760.00 if is_mist else 1318.51
		var chime_env := exp(-it * 6.4) * _smoothstep(0.015, 0.055, t)
		var chime := (sin(TAU * f1 * t) * 0.30 + sin(TAU * f2 * t) * 0.22 + sin(TAU * (f1 * 2.0) * t) * 0.08) * chime_env
		var mist_hiss := white * exp(-maxf(0.0, t - 0.06) * 5.2) * (0.20 if is_mist else 0.11)
		var sample := clampf((whoosh + thud + chime + mist_hiss) * 0.78, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	return wav


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 1.0 if x >= edge1 else 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


class _InkSparkParticle:
	var node: MeshInstance3D
	var mat: ShaderMaterial
	var vel: Vector3
	var rot_spd: float
	var life: float
	var max_life: float
	var base_scale: float
	var landed := false


class _EnergyOrbParticle:
	var node: MeshInstance3D
	var mat: ShaderMaterial
	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var delay: float
	var dur: float
	var spin_spd: float
	var base_scale: float
	var burst_done := false


class _SwordVfxRig extends Node3D:
	var _table_ref: WeakRef
	var _card_ref: WeakRef
	var _attacker_is_player := true
	var _is_knight_mist := true
	var _dir_z := -1.0
	var _impact_pos := Vector3.ZERO
	var _felt_y := 0.824
	var _power_scale := 1.0

	var _glow_col := Color(0.28, 0.92, 1.0, 1.0)
	var _tint_col := Color(0.95, 0.99, 1.0, 1.0)
	var _mist_col := Color(0.76, 0.93, 1.0, 0.94)
	var _royal_shift := 0.0

	var _elapsed := 0.0
	var _anim_t := 0.0
	var _hitstop_left := 0.0
	var _hitstop_done := false
	var _cleave_fired := false
	var _impact_fired := false
	const TOTAL_DUR := 1.26

	var _sword_pivot: Node3D
	var _blade_mesh: MeshInstance3D
	var _blade_mat: ShaderMaterial
	var _shadow_blade_mesh: MeshInstance3D
	var _shadow_mat: ShaderMaterial
	var _weapon_style := "sword_royal"
	var _second_pivot: Node3D = null
	var _second_blade_mat: ShaderMaterial = null
	var _second_shadow_mat: ShaderMaterial = null

	var _slash_canopy: MeshInstance3D
	var _slash_canopy_mat: ShaderMaterial
	var _slash_cross: MeshInstance3D
	var _slash_cross_mat: ShaderMaterial
	var _slash_skim: MeshInstance3D
	var _slash_skim_mat: ShaderMaterial

	var _sigil_outer: MeshInstance3D
	var _sigil_outer_mat: ShaderMaterial
	var _sigil_inner: MeshInstance3D
	var _sigil_inner_mat: ShaderMaterial
	var _arrival_sigil: MeshInstance3D
	var _arrival_sigil_mat: ShaderMaterial
	var _arrival_triggered := false
	var _tray_target := Vector3.ZERO
	var _custom_tray_local := Vector3(NAN, NAN, NAN)

	var _mist_felt: MeshInstance3D
	var _mist_felt_mat: ShaderMaterial
	var _mist_wing_a: MeshInstance3D
	var _mist_wing_a_mat: ShaderMaterial
	var _mist_wing_b: MeshInstance3D
	var _mist_wing_b_mat: ShaderMaterial

	var _flash_light: OmniLight3D
	var _audio_draw: AudioStreamPlayer
	var _audio_cleave: AudioStreamPlayer
	var _sfx_cleave_stream: AudioStream

	var _sparks: Array[_InkSparkParticle] = []
	var _orbs: Array[_EnergyOrbParticle] = []
	var _cel_shader: Shader
	var _blade_shader: Shader
	var _tex_sparks: Texture2D
	var _rng := RandomNumberGenerator.new()

	func configure(
		table_node: Node3D,
		card_data: Dictionary,
		card_node: Node3D,
		attacker_is_player: bool,
		impact_pos: Vector3,
		score_pts: int,
		eff_mult: float,
		is_knight_mist: bool,
		cel_shader: Shader,
		blade_shader: Shader,
		sfx_draw: AudioStream,
		sfx_cleave: AudioStream,
		custom_tray_local: Vector3 = Vector3(NAN, NAN, NAN)
	) -> void:
		_rng.randomize()
		_table_ref = weakref(table_node)
		_card_ref = weakref(card_node) if is_instance_valid(card_node) else null
		_attacker_is_player = attacker_is_player
		_is_knight_mist = is_knight_mist
		_dir_z = -1.0 if attacker_is_player else 1.0
		_impact_pos = impact_pos
		_felt_y = clampf(impact_pos.y + 0.008, 0.822, 0.865)
		_power_scale = clampf(1.0 + maxf(0.0, float(score_pts - 20) * 0.003 + maxf(0.0, eff_mult - 1.0) * 0.06), 0.96, 1.24)
		_cel_shader = cel_shader
		_blade_shader = blade_shader
		_sfx_cleave_stream = sfx_cleave
		_custom_tray_local = custom_tray_local

		var cls := str(card_data.get("edition", card_data.get("card_class", "NORMAL"))).to_upper()
		var pid := str(card_data.get("power_id", ""))
		var suit := str(card_data.get("suit", "CERVEN"))
		var use_mist := is_knight_mist or (cls == "KNIGHT")
		_is_knight_mist = use_mist
		_weapon_style = SwordCardAnimator._pick_weapon_style(card_data, use_mist)
		if use_mist:
			_glow_col = Color(0.28, 0.92, 1.0, 1.0)
			_tint_col = Color(0.96, 0.99, 1.0, 1.0)
			_mist_col = Color(0.74, 0.93, 1.0, 0.94)
			_royal_shift = 0.0
		else:
			_tint_col = Color(1.0, 0.95, 0.88, 1.0)
			_mist_col = Color(0.98, 0.76, 0.44, 0.72)
			_royal_shift = 1.0
			var accent_v = card_data.get("accent", null)
			if accent_v is Color and pid != "":
				_glow_col = (accent_v as Color).lightened(0.14)
				_mist_col = Color(_glow_col.r, _glow_col.g, _glow_col.b, 0.68)
			elif cls == "MAGE":
				_glow_col = Color(0.72, 0.42, 1.0, 1.0)
				_mist_col = Color(0.76, 0.54, 1.0, 0.70)
			elif cls == "THIEF":
				_glow_col = Color(0.30, 0.96, 0.58, 1.0)
				_mist_col = Color(0.42, 0.96, 0.66, 0.68)
			elif suit == "CERVEN" or suit == "HEARTS":
				_glow_col = Color(1.0, 0.38, 0.24, 1.0)
			elif suit == "ZELEN":
				_glow_col = Color(0.32, 0.92, 0.48, 1.0)
				_mist_col = Color(0.44, 0.92, 0.56, 0.68)
			else:
				_glow_col = Color(1.0, 0.76, 0.26, 1.0)

		_build_visual_layers()
		_setup_audio(table_node, sfx_draw)

	func _build_visual_layers() -> void:
		var anchor := Vector3(_impact_pos.x, _felt_y, _impact_pos.z)
		var attack_center := anchor + Vector3(0.0, 0.0, _dir_z * 0.14)

		var weapon_tex_path := TEX_BLADE_ROYAL
		match _weapon_style:
			"sword_mist": weapon_tex_path = TEX_BLADE_MIST
			"halberd": weapon_tex_path = TEX_WEAPON_HALBERD
			"staff": weapon_tex_path = TEX_WEAPON_STAFF
			"dagger": weapon_tex_path = TEX_WEAPON_DAGGER
			"mace": weapon_tex_path = TEX_WEAPON_MACE
			"spear": weapon_tex_path = TEX_WEAPON_SPEAR
			"shield": weapon_tex_path = TEX_WEAPON_SHIELD
		var tex_blade := SwordCardAnimator._load_weapon_tex(weapon_tex_path)
		var tex_slash := Toon.tex(TEX_SLASH_SHEET)
		var tex_mist := Toon.tex(TEX_MIST_SHEET)
		var tex_sigil := Toon.tex(TEX_IMPACT_SHEET)
		_tex_sparks = Toon.tex(TEX_SPARKS_SHEET)

		# 1. Dynamic 3D Point Light illuminating felt, brass, and opponent silhouette
		_flash_light = OmniLight3D.new()
		_flash_light.position = attack_center + Vector3(0.0, 0.34, 0.0)
		_flash_light.light_color = Color(_glow_col.r, _glow_col.g, _glow_col.b)
		_flash_light.light_energy = 0.0
		_flash_light.omni_range = 2.45
		_flash_light.omni_attenuation = 1.4
		add_child(_flash_light)

		# 2. Carved Table Impact Rune Sigils (flat on felt -> symmetric +Z and -Z view)
		_sigil_outer_mat = _make_cel_mat(tex_sigil, Vector2(4.0, 4.0), 1.35, 1.8)
		_sigil_outer = _make_quad_node("ImpactSigilOuter", 0.94 * _power_scale, 0.94 * _power_scale, _sigil_outer_mat, 1)
		_sigil_outer.position = attack_center + Vector3(0.0, 0.005, 0.0)
		_sigil_outer.rotation_degrees = Vector3(-90.0, 12.0 if _attacker_is_player else 192.0, 0.0)
		_sigil_outer.scale = Vector3.ONE * 0.01
		add_child(_sigil_outer)

		_sigil_inner_mat = _make_cel_mat(tex_sigil, Vector2(4.0, 4.0), 2.15, 4.7)
		_sigil_inner_mat.set_shader_parameter("flip_x", 1.0)
		_sigil_inner = _make_quad_node("ImpactSigilInner", 0.62 * _power_scale, 0.62 * _power_scale, _sigil_inner_mat, 2)
		_sigil_inner.position = attack_center + Vector3(0.0, 0.009, 0.0)
		_sigil_inner.rotation_degrees = Vector3(-90.0, -24.0 if _attacker_is_player else 156.0, 0.0)
		_sigil_inner.scale = Vector3.ONE * 0.01
		add_child(_sigil_inner)

		# Diegetic point-bank flare on the scoring player's side of the table (100% in-world, zero UI)
		if not is_nan(_custom_tray_local.x):
			_tray_target = Vector3(_custom_tray_local.x, _felt_y + 0.018, _custom_tray_local.z)
		else:
			_tray_target = Vector3(0.0, _felt_y + 0.018, 0.68) if _attacker_is_player else Vector3(0.0, _felt_y + 0.018, -0.72)
		_arrival_sigil_mat = _make_cel_mat(tex_sigil, Vector2(4.0, 4.0), 2.8, 8.2)
		_arrival_sigil = _make_quad_node("ScoreArrivalSigil", 0.38 * _power_scale, 0.38 * _power_scale, _arrival_sigil_mat, 3)
		_arrival_sigil.position = _tray_target
		_arrival_sigil.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_arrival_sigil.visible = false
		add_child(_arrival_sigil)

		# 3. Hand-Drawn Battle Mist Veil (1 felt swirl + 2 crossed angled planes for both seats)
		_mist_felt_mat = _make_cel_mat(tex_mist, Vector2(4.0, 4.0), 0.72, 2.2)
		_mist_felt_mat.set_shader_parameter("tint_col", _mist_col)
		_mist_felt_mat.set_shader_parameter("blend_next", 0.55)
		_mist_felt_mat.set_shader_parameter("loop_sheet", 1.0)
		_mist_felt_mat.set_shader_parameter("ink_preserve", 0.65)
		_mist_felt = _make_quad_node("MistFelt", 1.08 * _power_scale, 1.08 * _power_scale, _mist_felt_mat, 0)
		_mist_felt.position = anchor + Vector3(0.0, 0.011, _dir_z * 0.06)
		_mist_felt.rotation_degrees = Vector3(-90.0, _rng.randf_range(-18.0, 18.0), 0.0)
		_mist_felt.scale = Vector3.ONE * 0.01
		add_child(_mist_felt)

		_mist_wing_a_mat = _make_cel_mat(tex_mist, Vector2(4.0, 4.0), 0.85, 6.1)
		_mist_wing_a_mat.set_shader_parameter("tint_col", _mist_col)
		_mist_wing_a_mat.set_shader_parameter("blend_next", 0.6)
		_mist_wing_a_mat.set_shader_parameter("loop_sheet", 1.0)
		_mist_wing_a_mat.set_shader_parameter("ink_preserve", 0.62)
		_mist_wing_a = _make_quad_node("MistWingA", 0.96 * _power_scale, 0.68 * _power_scale, _mist_wing_a_mat, 1)
		_mist_wing_a.position = anchor + Vector3(-0.08, 0.16, _dir_z * 0.05)
		_mist_wing_a.rotation_degrees = Vector3(-22.0, 40.0, 0.0)
		_mist_wing_a.scale = Vector3.ONE * 0.01
		add_child(_mist_wing_a)

		_mist_wing_b_mat = _make_cel_mat(tex_mist, Vector2(4.0, 4.0), 0.85, 9.4)
		_mist_wing_b_mat.set_shader_parameter("tint_col", _mist_col)
		_mist_wing_b_mat.set_shader_parameter("blend_next", 0.6)
		_mist_wing_b_mat.set_shader_parameter("loop_sheet", 1.0)
		_mist_wing_b_mat.set_shader_parameter("flip_x", 1.0)
		_mist_wing_b_mat.set_shader_parameter("ink_preserve", 0.62)
		_mist_wing_b = _make_quad_node("MistWingB", 0.96 * _power_scale, 0.68 * _power_scale, _mist_wing_b_mat, 1)
		_mist_wing_b.position = anchor + Vector3(0.08, 0.17, _dir_z * 0.05)
		_mist_wing_b.rotation_degrees = Vector3(-22.0, -40.0, 0.0)
		_mist_wing_b.scale = Vector3.ONE * 0.01
		add_child(_mist_wing_b)

		# 4. Vaulted 3D Dual-Plane Hand-Drawn Cel Slash Arcs (symmetric yaw +-42 deg, lifted so bottom never clips into table)
		_slash_canopy_mat = _make_cel_mat(tex_slash, Vector2(6.0, 4.0), 2.15, 3.1)
		_slash_canopy = _make_quad_node("SlashCanopy", 0.90 * _power_scale, 0.90 * _power_scale, _slash_canopy_mat, 4)
		_slash_canopy.position = attack_center + Vector3(0.0, 0.35, _dir_z * 0.04)
		_slash_canopy.rotation_degrees = Vector3(-28.0 if _attacker_is_player else 28.0, 34.0 if _attacker_is_player else -146.0, -12.0)
		_slash_canopy.visible = false
		add_child(_slash_canopy)

		_slash_cross_mat = _make_cel_mat(tex_slash, Vector2(6.0, 4.0), 1.95, 7.3)
		_slash_cross_mat.set_shader_parameter("flip_x", 1.0)
		_slash_cross = _make_quad_node("SlashCross", 0.80 * _power_scale, 0.80 * _power_scale, _slash_cross_mat, 5)
		_slash_cross.position = attack_center + Vector3(0.0, 0.34, _dir_z * 0.08)
		_slash_cross.rotation_degrees = Vector3(-22.0 if _attacker_is_player else 22.0, -38.0 if _attacker_is_player else 142.0, 14.0)
		_slash_cross.visible = false
		add_child(_slash_cross)

		_slash_skim_mat = _make_cel_mat(tex_slash, Vector2(6.0, 4.0), 1.75, 5.2)
		_slash_skim = _make_quad_node("SlashFeltSkim", 0.96 * _power_scale, 0.96 * _power_scale, _slash_skim_mat, 3)
		_slash_skim.position = attack_center + Vector3(0.0, 0.022, _dir_z * 0.04)
		_slash_skim.rotation_degrees = Vector3(-88.0, 16.0 if _attacker_is_player else 196.0, 0.0)
		_slash_skim.visible = false
		add_child(_slash_skim)

		# 5. Physical Hero Hand-Drawn Sword Cutout + Dark Ink Shadow Silhouette
		_sword_pivot = Node3D.new()
		_sword_pivot.name = "SwordBladePivot"
		_sword_pivot.position = anchor + Vector3(0.0, 0.20, -_dir_z * 0.02)
		add_child(_sword_pivot)

		var blade_h := 0.56 * _power_scale
		if _weapon_style == "halberd" or _weapon_style == "spear":
			blade_h = 0.68 * _power_scale
		elif _weapon_style == "staff":
			blade_h = 0.64 * _power_scale
		elif _weapon_style == "dagger":
			blade_h = 0.48 * _power_scale
		elif _weapon_style == "shield":
			blade_h = 0.54 * _power_scale
		var aspect := 0.75
		if tex_blade != null and tex_blade.get_size().y > 1.0:
			aspect = tex_blade.get_size().x / tex_blade.get_size().y
		var blade_w := blade_h * aspect

		_blade_mat = ShaderMaterial.new()
		_blade_mat.shader = _blade_shader
		_blade_mat.set_shader_parameter("blade_tex", tex_blade)
		_blade_mat.set_shader_parameter("tint_col", _tint_col)
		_blade_mat.set_shader_parameter("glow_col", _glow_col)
		_blade_mat.set_shader_parameter("rune_glow", 1.95)
		_blade_mat.set_shader_parameter("opacity", 0.0)

		_blade_mesh = _make_quad_node("SwordBladeMain", blade_w, blade_h, _blade_mat, 6)
		# Shift up so hilt/crossguard sits at _sword_pivot origin and tip extends to +0.86*blade_h
		_blade_mesh.position = Vector3(0.0, 0.0 if _weapon_style == "shield" else blade_h * 0.36, 0.0)
		_sword_pivot.add_child(_blade_mesh)

		# Subtle ink-outline offset backing plane for 3D woodcut diorama thickness
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = _blade_shader
		_shadow_mat.set_shader_parameter("blade_tex", tex_blade)
		_shadow_mat.set_shader_parameter("tint_col", Color(0.08, 0.06, 0.07, 0.85))
		_shadow_mat.set_shader_parameter("glow_col", Color(0.05, 0.04, 0.05, 1.0))
		_shadow_mat.set_shader_parameter("rune_glow", 0.0)
		_shadow_mat.set_shader_parameter("sheen_strength", 0.0)
		_shadow_mat.set_shader_parameter("opacity", 0.0)

		_shadow_blade_mesh = _make_quad_node("SwordBladeInkDepth", blade_w * 1.03, blade_h * 1.01, _shadow_mat, 5)
		_shadow_blade_mesh.position = Vector3(0.004, (0.0 if _weapon_style == "shield" else blade_h * 0.36) - 0.004, -0.006 * _dir_z)
		_sword_pivot.add_child(_shadow_blade_mesh)

		_sword_pivot.scale = Vector3.ONE * 0.05

		# Twin crossed assassin dagger rig for "dagger" style
		if _weapon_style == "dagger":
			_second_pivot = Node3D.new()
			_second_pivot.name = "SecondDaggerPivot"
			_second_pivot.position = anchor + Vector3(0.0, 0.20, -_dir_z * 0.02)
			_second_pivot.scale = Vector3.ONE * 0.05
			add_child(_second_pivot)

			_second_blade_mat = _blade_mat.duplicate() as ShaderMaterial
			var dag2 := _make_quad_node("SecondDaggerMain", blade_w, blade_h, _second_blade_mat, 6)
			dag2.position = Vector3(0.0, blade_h * 0.36, 0.0)
			_second_pivot.add_child(dag2)

			_second_shadow_mat = _shadow_mat.duplicate() as ShaderMaterial
			var dag2_sh := _make_quad_node("SecondDaggerInkDepth", blade_w * 1.03, blade_h * 1.01, _second_shadow_mat, 5)
			dag2_sh.position = Vector3(-0.004, blade_h * 0.36 - 0.004, -0.006 * _dir_z)
			_second_pivot.add_child(dag2_sh)

		# 6. Pre-spawn Ink Droplets & Diegetic Score Energy Orbs (hidden until cleave)
		_build_ink_sparks(attack_center)
		_build_score_orbs(attack_center)

	func _build_ink_sparks(center: Vector3) -> void:
		var count := 16
		for i in range(count):
			var sp := _InkSparkParticle.new()
			var mat := _make_cel_mat(_tex_sparks, Vector2(4.0, 4.0), 1.4 if i % 3 == 0 else 0.35, float(i) * 2.7)
			mat.set_shader_parameter("frame_index", float(i % 16))
			mat.set_shader_parameter("ink_preserve", 0.92)
			mat.set_shader_parameter("opacity", 0.0)
			var sz := _rng.randf_range(0.065, 0.135) * _power_scale
			var mesh := _make_quad_node("InkSpark_%d" % i, sz, sz, mat, 7)
			mesh.position = center + Vector3(_rng.randf_range(-0.08, 0.08), 0.12, _rng.randf_range(-0.08, 0.08))
			mesh.rotation_degrees = Vector3(_rng.randf_range(-55.0, -15.0), _rng.randf_range(-55.0, 55.0), _rng.randf_range(0.0, 360.0))
			mesh.visible = false
			add_child(mesh)

			var ang := (float(i) / float(count)) * TAU + _rng.randf_range(-0.22, 0.22)
			var spd := _rng.randf_range(0.85, 1.75)
			sp.node = mesh
			sp.mat = mat
			sp.vel = Vector3(cos(ang) * spd, _rng.randf_range(0.85, 1.95), sin(ang) * spd + _dir_z * 0.45)
			sp.rot_spd = _rng.randf_range(-7.5, 7.5)
			sp.max_life = _rng.randf_range(0.45, 0.72)
			sp.life = 0.0
			sp.base_scale = sz
			_sparks.append(sp)

	func _build_score_orbs(center: Vector3) -> void:
		# Points visibly channel in 3D space from the rune impact seal to the attacker's table edge (NO UI!)
		var count := 9
		for i in range(count):
			var orb := _EnergyOrbParticle.new()
			var mat := _make_cel_mat(_tex_sparks, Vector2(4.0, 4.0), 3.4, float(i) * 4.1)
			mat.set_shader_parameter("frame_index", float(14 if (i % 3 == 0) else ((i * 2 + 7) % 16)))
			mat.set_shader_parameter("ink_preserve", 0.45)
			mat.set_shader_parameter("opacity", 0.0)
			var mesh := _make_quad_node("ScoreEnergyOrb_%d" % i, 0.16, 0.16, mat, 8)
			mesh.rotation_degrees = Vector3(-36.0, 32.0 if (i % 2 == 0) else -32.0, 0.0)
			mesh.visible = false
			add_child(mesh)

			var spread_x := _rng.randf_range(-0.24, 0.24)
			var p0 := center + Vector3(_rng.randf_range(-0.10, 0.10), 0.07, _rng.randf_range(-0.08, 0.08))
			var p2 := Vector3(_tray_target.x + spread_x * 0.30, _tray_target.y + 0.04, _tray_target.z)
			var p1 := p0.lerp(p2, 0.48) + Vector3(spread_x * 1.35, _rng.randf_range(0.24, 0.42), 0.0)
			orb.node = mesh
			orb.mat = mat
			orb.p0 = p0
			orb.p1 = p1
			orb.p2 = p2
			orb.delay = 0.30 + float(i) * 0.042
			orb.dur = 0.44 + float(i % 3) * 0.045
			orb.spin_spd = _rng.randf_range(-9.0, 9.0)
			orb.base_scale = _rng.randf_range(0.95, 1.35)
			_orbs.append(orb)

	func _make_cel_mat(tex: Texture2D, grid: Vector2, glow_str: float, boil_seed: float) -> ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = _cel_shader
		mat.set_shader_parameter("sprite_sheet", tex)
		mat.set_shader_parameter("grid_size", grid)
		mat.set_shader_parameter("frame_index", 0.0)
		mat.set_shader_parameter("tint_col", _tint_col)
		mat.set_shader_parameter("glow_col", _glow_col)
		mat.set_shader_parameter("glow_strength", glow_str)
		mat.set_shader_parameter("royal_shift", _royal_shift)
		mat.set_shader_parameter("boil_seed", boil_seed)
		mat.set_shader_parameter("opacity", 1.0)
		return mat

	func _make_quad_node(node_name: String, w: float, h: float, mat: Material, sort_idx: int) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.name = node_name
		var qm := QuadMesh.new()
		qm.size = Vector2(w, h)
		mi.mesh = qm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.sorting_offset = float(sort_idx) * 0.04
		return mi

	func _setup_audio(table_node: Node3D, sfx_draw: AudioStream) -> void:
		var vol_db := _get_audio_db(table_node, -6.5)
		if vol_db <= -79.0:
			return
		_audio_draw = AudioStreamPlayer.new()
		_audio_draw.stream = sfx_draw
		_audio_draw.volume_db = vol_db
		add_child(_audio_draw)
		_audio_draw.play()

		_audio_cleave = AudioStreamPlayer.new()
		_audio_cleave.stream = _sfx_cleave_stream
		_audio_cleave.volume_db = vol_db + 1.5
		_audio_cleave.pitch_scale = 1.04 if _is_knight_mist else 0.90
		add_child(_audio_cleave)

	func _get_audio_db(table_node: Node3D, base_db: float) -> float:
		if not is_instance_valid(table_node):
			return base_db
		var muted_v = table_node.get("battle_audio_muted")
		if muted_v != null and bool(muted_v):
			return -80.0
		var pct_v = table_node.get("battle_audio_pct")
		var pct := float(pct_v) if pct_v != null else 100.0
		if pct <= 1.0:
			return -80.0
		return base_db + linear_to_db(clampf(pct / 100.0, 0.05, 1.5))

	func _process(delta: float) -> void:
		var dt := minf(delta, 0.05)
		_elapsed += dt
		if _elapsed >= TOTAL_DUR:
			queue_free()
			return

		# Brief Sakuga hitstop on cleave peak apex (45ms hold while micro-trembling)
		if _hitstop_left > 0.0:
			_hitstop_left -= dt
			var jit := Vector3(_rng.randf_range(-0.014, 0.014), _rng.randf_range(-0.014, 0.014), _rng.randf_range(-0.010, 0.010))
			_sword_pivot.position += jit * 0.35
			_slash_canopy.position += jit * 0.25
			_blade_mat.set_shader_parameter("flash_white", 0.85)
			if is_instance_valid(_second_pivot) and _second_blade_mat != null:
				_second_pivot.position -= jit * 0.35
				_second_blade_mat.set_shader_parameter("flash_white", 0.85)
			_slash_canopy_mat.set_shader_parameter("flash_white", 0.72)
			return
		else:
			_anim_t += dt

		_update_sword_blade(_anim_t)
		_update_slashes(_anim_t)
		_update_sigil_and_mist(_anim_t)
		_update_sparks(dt)
		_update_score_orbs(dt)
		_update_light(_anim_t)

	func _set_weapon_mats(opacity_v: float, dissolve_v: float, flash_v: float, sheen_v: float, rune_v: float) -> void:
		_blade_mat.set_shader_parameter("opacity", opacity_v)
		_shadow_mat.set_shader_parameter("opacity", opacity_v * 0.85)
		_blade_mat.set_shader_parameter("dissolve", dissolve_v)
		_shadow_mat.set_shader_parameter("dissolve", dissolve_v)
		_blade_mat.set_shader_parameter("flash_white", flash_v)
		if sheen_v >= -0.4:
			_blade_mat.set_shader_parameter("sheen_pos", sheen_v)
		if rune_v >= 0.0:
			_blade_mat.set_shader_parameter("rune_glow", rune_v)
		if _second_blade_mat != null and _second_shadow_mat != null:
			_second_blade_mat.set_shader_parameter("opacity", opacity_v)
			_second_shadow_mat.set_shader_parameter("opacity", opacity_v * 0.85)
			_second_blade_mat.set_shader_parameter("dissolve", dissolve_v)
			_second_shadow_mat.set_shader_parameter("dissolve", dissolve_v)
			_second_blade_mat.set_shader_parameter("flash_white", flash_v)
			if sheen_v >= -0.4:
				_second_blade_mat.set_shader_parameter("sheen_pos", sheen_v)
			if rune_v >= 0.0:
				_second_blade_mat.set_shader_parameter("rune_glow", rune_v)

	func _update_sword_blade(t: float) -> void:
		var base_anchor := Vector3(_impact_pos.x, _felt_y + 0.14, _impact_pos.z)
		var yaw_face := 22.0 if _attacker_is_player else -158.0
		var wind_pitch := 24.0 if _attacker_is_player else -24.0
		var planted_pitch := -18.0 if _attacker_is_player else 18.0
		var sgn := 1.0 if _attacker_is_player else -1.0

		if t >= 0.20 and not _cleave_fired:
			_cleave_fired = true
			if is_instance_valid(_audio_cleave):
				_audio_cleave.play()

		match _weapon_style:
			"halberd":
				var p_plant := Vector3(_impact_pos.x + 0.18 * sgn, _felt_y + 0.44, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var eo := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.32, 1.04, eo)
					_sword_pivot.scale = Vector3(sc, sc, sc)
					_sword_pivot.position = base_anchor + Vector3(lerpf(0.0, 0.34 * sgn, eo), lerpf(-0.04, 0.22, eo), -_dir_z * lerpf(0.0, 0.08, eo))
					_sword_pivot.rotation_degrees = Vector3(lerpf(8.0 * sgn, 26.0 * sgn, eo), yaw_face + lerpf(0.0, 32.0 * sgn, eo), lerpf(-24.0, -96.0, eo))
					_set_weapon_mats(clampf(u * 3.5, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.35, u), 1.95)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := 1.0 - pow(1.0 - u, 3.4)
					var p0 := base_anchor + Vector3(0.34 * sgn, 0.22, -_dir_z * 0.08)
					_sword_pivot.position = p0.lerp(p_plant, snap) + Vector3(-sin(u * PI) * 0.22 * sgn, sin(u * PI) * 0.08, 0.0)
					_sword_pivot.rotation_degrees = Vector3(lerpf(26.0 * sgn, planted_pitch, snap), yaw_face + lerpf(32.0 * sgn, -14.0 * sgn, snap), lerpf(-96.0, 138.0, snap))
					var st := 1.0 + sin(u * PI) * 0.22
					_sword_pivot.scale = Vector3(1.06 / sqrt(st), st, 1.0)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.56, -1.0, 2.35)
					if not _hitstop_done and u >= 0.58:
						_hitstop_done = true
						_hitstop_left = 0.045
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 9.5) * sin(u * 42.0) * 4.5
					_sword_pivot.position = p_plant + Vector3(0.0, sin(u * 5.0) * 0.005, 0.0)
					_sword_pivot.rotation_degrees = Vector3(planted_pitch + vib * 0.35, yaw_face - 14.0 * sgn, 138.0 + vib)
					_sword_pivot.scale = Vector3(1.04, 1.04, 1.0)
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.45 * (1.0 - u * 4.0)), -1.0, 2.45 - u * 0.7)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.6)
					_sword_pivot.position.y += 0.0005

			"staff":
				var p_plant := Vector3(_impact_pos.x, _felt_y + 0.14, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var eo := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.30, 1.02, eo)
					_sword_pivot.scale = Vector3(sc, sc, sc)
					_sword_pivot.position = base_anchor + Vector3(0.0, lerpf(0.04, 0.42, eo), _dir_z * lerpf(0.02, 0.12, eo))
					_sword_pivot.rotation_degrees = Vector3(lerpf(-10.0 * sgn, 14.0 * sgn, eo), yaw_face + eo * 360.0, sin(eo * PI) * 14.0)
					_set_weapon_mats(clampf(u * 3.4, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.4, u), 2.35)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := pow(u, 2.4)
					var p0 := base_anchor + Vector3(0.0, 0.42, _dir_z * 0.12)
					_sword_pivot.position = p0.lerp(p_plant, snap)
					_sword_pivot.rotation_degrees = Vector3(lerpf(14.0 * sgn, -10.0 * sgn, snap), yaw_face, lerpf(0.0, 8.0 * sgn, snap))
					var st := 1.0 + sin(u * PI) * 0.18
					_sword_pivot.scale = Vector3(1.02 / sqrt(st), st, 1.0)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.65, -1.0, 3.1)
					if not _hitstop_done and u >= 0.72:
						_hitstop_done = true
						_hitstop_left = 0.045
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 10.0) * sin(u * 40.0) * 3.0
					_sword_pivot.position = p_plant + Vector3(0.0, absf(sin(u * 8.0)) * 0.008, 0.0)
					_sword_pivot.rotation_degrees = Vector3(-10.0 * sgn + vib * 0.4, yaw_face + sin(u * 6.0) * 8.0, 8.0 * sgn + vib)
					_sword_pivot.scale = Vector3.ONE.lerp(Vector3(1.05, 1.05, 1.0), minf(1.0, u * 4.0))
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.50 * (1.0 - u * 4.0)), -1.0, 2.8 - u * 0.8)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.8)
					_sword_pivot.position.y += 0.0008

			"dagger":
				var p_left := Vector3(_impact_pos.x - 0.13 * sgn, _felt_y + 0.36, _impact_pos.z + _dir_z * 0.14)
				var p_right := Vector3(_impact_pos.x + 0.13 * sgn, _felt_y + 0.36, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var eo := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.28, 1.02, eo)
					_sword_pivot.scale = Vector3(sc, sc, sc)
					_sword_pivot.position = base_anchor + Vector3(lerpf(0.18 * sgn, 0.44 * sgn, eo), lerpf(0.02, 0.26, eo), -_dir_z * 0.08)
					_sword_pivot.rotation_degrees = Vector3(wind_pitch, yaw_face, lerpf(-20.0, -58.0, eo))
					if is_instance_valid(_second_pivot):
						_second_pivot.scale = Vector3(-sc, sc, sc)
						_second_pivot.position = base_anchor + Vector3(lerpf(-0.18 * sgn, -0.44 * sgn, eo), lerpf(0.02, 0.26, eo), -_dir_z * 0.08)
						_second_pivot.rotation_degrees = Vector3(wind_pitch, yaw_face, lerpf(20.0, 58.0, eo))
					_set_weapon_mats(clampf(u * 3.5, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.35, u), 2.05)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := 1.0 - pow(1.0 - u, 3.8)
					var s1 := base_anchor + Vector3(0.44 * sgn, 0.26, -_dir_z * 0.08)
					_sword_pivot.position = s1.lerp(p_right, snap) + Vector3(0.0, sin(u * PI) * 0.08, 0.0)
					_sword_pivot.rotation_degrees = Vector3(lerpf(wind_pitch, planted_pitch, snap), yaw_face, lerpf(-58.0, 138.0, snap))
					var st := 1.0 + sin(u * PI) * 0.24
					_sword_pivot.scale = Vector3(1.02 / sqrt(st), st, 1.0)
					if is_instance_valid(_second_pivot):
						var s2 := base_anchor + Vector3(-0.44 * sgn, 0.26, -_dir_z * 0.08)
						_second_pivot.position = s2.lerp(p_left, snap) + Vector3(0.0, sin(u * PI) * 0.08, 0.0)
						_second_pivot.rotation_degrees = Vector3(lerpf(wind_pitch, planted_pitch, snap), yaw_face, lerpf(58.0, -138.0, snap))
						_second_pivot.scale = Vector3(-1.02 / sqrt(st), st, 1.0)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.58, -1.0, 2.45)
					if not _hitstop_done and u >= 0.58:
						_hitstop_done = true
						_hitstop_left = 0.045
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 11.0) * sin(u * 48.0) * 4.0
					_sword_pivot.position = p_right
					_sword_pivot.rotation_degrees = Vector3(planted_pitch + vib * 0.3, yaw_face, 138.0 + vib)
					_sword_pivot.scale = Vector3.ONE
					if is_instance_valid(_second_pivot):
						_second_pivot.position = p_left
						_second_pivot.rotation_degrees = Vector3(planted_pitch - vib * 0.3, yaw_face, -138.0 - vib)
						_second_pivot.scale = Vector3(-1.0, 1.0, 1.0)
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.45 * (1.0 - u * 4.0)), -1.0, 2.3 - u * 0.6)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.5)
					_sword_pivot.position.y += 0.0005
					if is_instance_valid(_second_pivot):
						_second_pivot.position.y += 0.0005

			"mace":
				var p_plant := Vector3(_impact_pos.x, _felt_y + 0.40, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var eo := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.30, 1.08, eo)
					_sword_pivot.scale = Vector3(sc, sc, sc)
					_sword_pivot.position = base_anchor + Vector3(lerpf(0.0, 0.18 * sgn, eo), lerpf(0.05, 0.56, eo), -_dir_z * 0.06)
					_sword_pivot.rotation_degrees = Vector3(lerpf(10.0 * sgn, 34.0 * sgn, eo), yaw_face, lerpf(0.0, -32.0, eo))
					_set_weapon_mats(clampf(u * 3.4, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.35, u), 2.0)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := pow(u, 2.2)
					var p0 := base_anchor + Vector3(0.18 * sgn, 0.56, -_dir_z * 0.06)
					_sword_pivot.position = p0.lerp(p_plant, snap)
					_sword_pivot.rotation_degrees = Vector3(lerpf(34.0 * sgn, planted_pitch, snap), yaw_face, lerpf(-32.0, 174.0, snap))
					var st := 1.0 + sin(u * PI) * 0.22
					_sword_pivot.scale = Vector3(1.12 / sqrt(st), st, 1.0)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.62, -1.0, 2.6)
					if not _hitstop_done and u >= 0.72:
						_hitstop_done = true
						_hitstop_left = 0.050
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 9.0) * sin(u * 38.0) * 5.0
					_sword_pivot.position = p_plant + Vector3(0.0, -absf(sin(u * 12.0)) * exp(-u * 8.0) * 0.02, 0.0)
					_sword_pivot.rotation_degrees = Vector3(planted_pitch + vib * 0.4, yaw_face, 174.0 + vib)
					_sword_pivot.scale = Vector3(1.05, 1.05, 1.0)
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.5 * (1.0 - u * 4.0)), -1.0, 2.4 - u * 0.7)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.5)
					_sword_pivot.position.y += 0.0004

			"spear":
				var p_plant := Vector3(_impact_pos.x + 0.14 * sgn, _felt_y + 0.46, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var eo := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.32, 1.04, eo)
					_sword_pivot.scale = Vector3(sc, sc, sc)
					_sword_pivot.position = base_anchor + Vector3(lerpf(0.0, -0.22 * sgn, eo), lerpf(0.28, 0.92, eo), -_dir_z * 0.14)
					_sword_pivot.rotation_degrees = Vector3(lerpf(12.0 * sgn, 24.0 * sgn, eo), yaw_face, lerpf(120.0, 158.0, eo))
					_set_weapon_mats(clampf(u * 3.6, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.4, u), 2.3)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := pow(u, 2.0)
					var p0 := base_anchor + Vector3(-0.22 * sgn, 0.92, -_dir_z * 0.14)
					_sword_pivot.position = p0.lerp(p_plant, snap)
					_sword_pivot.rotation_degrees = Vector3(lerpf(24.0 * sgn, -16.0 * sgn, snap), yaw_face, lerpf(158.0, 162.0, snap))
					var st := 1.0 + sin(u * PI) * 0.28
					_sword_pivot.scale = Vector3(1.0 / sqrt(st), st, 1.0)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.65, -1.0, 3.0)
					if not _hitstop_done and u >= 0.72:
						_hitstop_done = true
						_hitstop_left = 0.055
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 10.5) * sin(u * 52.0) * 3.5
					_sword_pivot.position = p_plant
					_sword_pivot.rotation_degrees = Vector3(-16.0 * sgn + vib * 0.3, yaw_face, 162.0 + vib)
					_sword_pivot.scale = Vector3(1.03, 1.03, 1.0)
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.5 * (1.0 - u * 4.0)), -1.0, 2.6 - u * 0.75)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.6)
					_sword_pivot.position.y += 0.0005

			"shield":
				var p_plant := Vector3(_impact_pos.x, _felt_y + 0.25, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var eo := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.24, 1.12, eo)
					_sword_pivot.scale = Vector3(sc, sc, sc)
					_sword_pivot.position = base_anchor + Vector3(0.0, lerpf(0.04, 0.44, eo), _dir_z * 0.14)
					_sword_pivot.rotation_degrees = Vector3(-16.0 * sgn, yaw_face + lerpf(-22.0 * sgn, 0.0, eo), 0.0)
					_set_weapon_mats(clampf(u * 3.5, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.35, u), 2.15)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := pow(u, 2.4)
					var p0 := base_anchor + Vector3(0.0, 0.44, _dir_z * 0.14)
					_sword_pivot.position = p0.lerp(p_plant, snap)
					_sword_pivot.rotation_degrees = Vector3(lerpf(-16.0 * sgn, -10.0 * sgn, snap), yaw_face, 0.0)
					var sq := 1.0 + sin(u * PI) * 0.18
					_sword_pivot.scale = Vector3(1.06 * sq, 1.06 / sqrt(sq), 1.06)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.62, -1.0, 2.8)
					if not _hitstop_done and u >= 0.72:
						_hitstop_done = true
						_hitstop_left = 0.045
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 10.0) * sin(u * 38.0) * 3.0
					_sword_pivot.position = p_plant + Vector3(0.0, sin(u * 5.0) * 0.004, 0.0)
					_sword_pivot.rotation_degrees = Vector3(-10.0 * sgn, yaw_face, vib)
					_sword_pivot.scale = Vector3(1.06, 1.06, 1.06)
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.45 * (1.0 - u * 4.0)), -1.0, 2.5 - u * 0.7)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.6)
					_sword_pivot.position.y += 0.0004

			_:
				var planted_pos := Vector3(_impact_pos.x + (0.16 if _attacker_is_player else -0.16), _felt_y + 0.41, _impact_pos.z + _dir_z * 0.14)
				if t < 0.20:
					var u := clampf(t / 0.20, 0.0, 1.0)
					var ease_out := 1.0 - pow(1.0 - u, 3.0)
					var sc := lerpf(0.28, 1.02, ease_out)
					_sword_pivot.scale = Vector3(sc, sc * lerpf(0.88, 1.06, u), sc)
					_sword_pivot.position = base_anchor + Vector3(
						lerpf(0.0, 0.14 if _attacker_is_player else -0.14, ease_out),
						lerpf(-0.08, 0.18, ease_out),
						-_dir_z * lerpf(0.0, 0.10, ease_out)
					)
					_sword_pivot.rotation_degrees = Vector3(
						lerpf(6.0 if _attacker_is_player else -6.0, wind_pitch, ease_out),
						yaw_face,
						lerpf(-10.0, -40.0, ease_out)
					)
					_set_weapon_mats(clampf(u * 3.4, 0.0, 1.0), 0.0, 0.0, lerpf(-0.3, 1.35, u), 1.95)
				elif t < 0.32:
					var u := clampf((t - 0.20) / 0.12, 0.0, 1.0)
					var snap := 1.0 - pow(1.0 - u, 3.6)
					var start_pos := base_anchor + Vector3(0.14 if _attacker_is_player else -0.14, 0.18, -_dir_z * 0.10)
					_sword_pivot.position = start_pos.lerp(planted_pos, snap) + Vector3(0.0, sin(u * PI) * 0.12, 0.0)
					_sword_pivot.rotation_degrees = Vector3(
						lerpf(wind_pitch, planted_pitch, snap),
						yaw_face + lerpf(0.0, -10.0 if _attacker_is_player else 10.0, snap),
						lerpf(-40.0, 152.0, snap)
					)
					var stretch := 1.0 + sin(u * PI) * 0.20
					_sword_pivot.scale = Vector3(1.04 / sqrt(stretch), stretch, 1.0)
					_set_weapon_mats(1.0, 0.0, sin(u * PI) * 0.52, -1.0, 2.2)
					if not _hitstop_done and u >= 0.56:
						_hitstop_done = true
						_hitstop_left = 0.045
				elif t < 0.80:
					var u := clampf((t - 0.32) / 0.48, 0.0, 1.0)
					var vib := exp(-u * 10.5) * sin(u * 46.0) * 4.2
					_sword_pivot.position = planted_pos + Vector3(0.0, sin(u * 6.0) * 0.005, 0.0)
					_sword_pivot.rotation_degrees = Vector3(
						planted_pitch + vib * 0.4,
						yaw_face + (-10.0 if _attacker_is_player else 10.0),
						152.0 + vib
					)
					_sword_pivot.scale = Vector3.ONE.lerp(Vector3(1.02, 1.02, 1.0), minf(1.0, u * 4.0))
					_set_weapon_mats(1.0, 0.0, maxf(0.0, 0.45 * (1.0 - u * 4.0)), -1.0, 2.45 - u * 0.75)
				else:
					var u := clampf((t - 0.80) / 0.34, 0.0, 1.0)
					_set_weapon_mats(1.0 - pow(u, 1.8), u, 0.0, -1.0, 1.6)
					_sword_pivot.position.y += 0.0005

	func _update_slashes(t: float) -> void:
		# Primary slash: starts at t = 0.15s -> 0.86s across 24 cel frames
		if t >= 0.15 and t < 0.92:
			_slash_canopy.visible = true
			var u := clampf((t - 0.15) / 0.72, 0.0, 1.0)
			# Ease fast through smear frames (4..15) so strike snaps cleanly
			var frame_curve := pow(u, 0.78) * 23.0
			_slash_canopy_mat.set_shader_parameter("frame_index", frame_curve)
			_slash_canopy_mat.set_shader_parameter("dissolve", clampf((u - 0.72) / 0.28, 0.0, 1.0) * 0.75)
			_slash_canopy_mat.set_shader_parameter("flash_white", maxf(0.0, 0.45 - absf(u - 0.28) * 2.5))
			_slash_canopy.scale = Vector3.ONE * lerpf(0.84, 1.18, minf(1.0, u * 2.2))

			_slash_skim.visible = true
			_slash_skim_mat.set_shader_parameter("frame_index", clampf(frame_curve * 1.04, 0.0, 23.0))
			_slash_skim_mat.set_shader_parameter("dissolve", clampf((u - 0.70) / 0.30, 0.0, 1.0) * 0.8)
			_slash_skim.scale = Vector3.ONE * lerpf(0.82, 1.24, minf(1.0, u * 2.0))
		else:
			_slash_canopy.visible = false
			_slash_skim.visible = false

		# Cross-cut secondary counter slash (forms volumetric 3D X-cleave!)
		if t >= 0.23 and t < 0.98:
			_slash_cross.visible = true
			var u2 := clampf((t - 0.23) / 0.70, 0.0, 1.0)
			var f2 := pow(u2, 0.82) * 23.0
			_slash_cross_mat.set_shader_parameter("frame_index", f2)
			_slash_cross_mat.set_shader_parameter("dissolve", clampf((u2 - 0.68) / 0.32, 0.0, 1.0) * 0.82)
			_slash_cross_mat.set_shader_parameter("opacity", 0.92 if _is_knight_mist else 0.78)
			_slash_cross.scale = Vector3.ONE * lerpf(0.82, 1.12, minf(1.0, u2 * 2.2))
		else:
			_slash_cross.visible = false

	func _update_sigil_and_mist(t: float) -> void:
		# Felt impact rune seal erupts right at blade apex (t >= 0.22s)
		if t >= 0.22:
			if not _impact_fired:
				_impact_fired = true
				for sp in _sparks:
					sp.node.visible = true
					sp.mat.set_shader_parameter("opacity", 1.0)
				_trigger_table_camera_punch()
			var u := clampf((t - 0.22) / 0.88, 0.0, 1.0)
			var pop := 1.0 - pow(1.0 - minf(1.0, u * 5.2), 3.0)
			_sigil_outer.scale = Vector3.ONE * lerpf(0.28, 1.10, pop)
			_sigil_outer.rotation_degrees.y += 0.25
			_sigil_outer_mat.set_shader_parameter("frame_index", minf(15.0, u * 16.5))
			_sigil_outer_mat.set_shader_parameter("dissolve", clampf((u - 0.66) / 0.34, 0.0, 1.0))

			_sigil_inner.scale = Vector3.ONE * lerpf(0.18, 0.96, pop)
			_sigil_inner.rotation_degrees.y -= 0.65
			_sigil_inner_mat.set_shader_parameter("frame_index", minf(15.0, u * 18.0 + 1.0))
			_sigil_inner_mat.set_shader_parameter("dissolve", clampf((u - 0.60) / 0.40, 0.0, 1.0))

		# Hand-drawn mist veil swells smoothly — especially dramatic for KNIGHT Mistblade
		var mist_u := clampf(t / 1.18, 0.0, 1.0)
		var mist_grow := sin(minf(1.0, mist_u * 1.45) * PI * 0.5)
		var mist_fade := clampf((mist_u - 0.64) / 0.36, 0.0, 1.0)
		var mist_op := (1.0 - mist_fade) * (0.95 if _is_knight_mist else 0.56)
		var mist_frame := mist_u * 15.8

		_mist_felt.scale = Vector3.ONE * lerpf(0.32, 1.28, mist_grow)
		_mist_felt.rotation_degrees.y += 0.18
		_mist_felt_mat.set_shader_parameter("frame_index", mist_frame)
		_mist_felt_mat.set_shader_parameter("dissolve", mist_fade * 0.85)
		_mist_felt_mat.set_shader_parameter("opacity", mist_op)

		var wing_op := clampf((t - 0.14) * 3.5, 0.0, 1.0) * (1.0 - mist_fade) * (0.86 if _is_knight_mist else 0.42)
		var wing_sc := lerpf(0.38, 1.14, mist_grow)
		_mist_wing_a.scale = Vector3.ONE * wing_sc
		_mist_wing_b.scale = Vector3.ONE * wing_sc
		_mist_wing_a_mat.set_shader_parameter("frame_index", mist_frame)
		_mist_wing_b_mat.set_shader_parameter("frame_index", fmod(mist_frame + 3.0, 16.0))
		_mist_wing_a_mat.set_shader_parameter("dissolve", mist_fade * 0.9)
		_mist_wing_b_mat.set_shader_parameter("dissolve", mist_fade * 0.9)
		_mist_wing_a_mat.set_shader_parameter("opacity", wing_op)
		_mist_wing_b_mat.set_shader_parameter("opacity", wing_op)

	func _update_sparks(delta: float) -> void:
		if not _impact_fired:
			return
		for sp in _sparks:
			if sp.life >= sp.max_life:
				sp.node.visible = false
				continue
			sp.life += delta
			var u := sp.life / sp.max_life
			if not sp.landed:
				sp.vel.y -= 4.8 * delta
				sp.vel *= pow(0.35, delta)
				sp.node.position += sp.vel * delta
				sp.node.rotation.z += sp.rot_spd * delta
				if sp.node.position.y <= _felt_y + 0.012:
					sp.node.position.y = _felt_y + 0.012
					sp.landed = true
			sp.mat.set_shader_parameter("dissolve", clampf((u - 0.55) / 0.45, 0.0, 1.0))
			sp.mat.set_shader_parameter("opacity", clampf((1.0 - u) * 2.2, 0.0, 1.0))

	func _update_score_orbs(delta: float) -> void:
		for orb in _orbs:
			if _anim_t < orb.delay:
				continue
			var u := clampf((_anim_t - orb.delay) / orb.dur, 0.0, 1.0)
			if u >= 1.0:
				orb.node.visible = false
				if not _arrival_triggered:
					_arrival_triggered = true
				continue
			orb.node.visible = true
			var q0 := orb.p0.lerp(orb.p1, u)
			var q1 := orb.p1.lerp(orb.p2, u)
			orb.node.position = q0.lerp(q1, u)
			orb.node.rotation.z += orb.spin_spd * delta
			var sc := orb.base_scale * (1.0 - 0.45 * u) * sin(clampf(u * 4.0, 0.0, 1.0) * PI * 0.5)
			orb.node.scale = Vector3.ONE * maxf(0.05, sc)
			var alpha_pulse := clampf(minf(u * 6.0, (1.0 - u) * 4.5), 0.0, 1.0)
			orb.mat.set_shader_parameter("opacity", alpha_pulse)

		# Flare miniature rune tally seal at the scoring player's edge when first energy orb arrives
		if _anim_t >= 0.68 and _anim_t < 1.24:
			_arrival_sigil.visible = true
			var au := clampf((_anim_t - 0.68) / 0.56, 0.0, 1.0)
			var apop := 1.0 - pow(1.0 - minf(1.0, au * 4.5), 3.0)
			_arrival_sigil.scale = Vector3.ONE * lerpf(0.32, 1.22, apop)
			_arrival_sigil.rotation_degrees.y += 1.4
			_arrival_sigil_mat.set_shader_parameter("frame_index", minf(15.0, 3.0 + au * 12.8))
			_arrival_sigil_mat.set_shader_parameter("dissolve", clampf((au - 0.52) / 0.48, 0.0, 1.0))
			_arrival_sigil_mat.set_shader_parameter("opacity", clampf((1.0 - au) * 2.5, 0.0, 1.0))
		else:
			_arrival_sigil.visible = false

	func _update_light(t: float) -> void:
		var pulse := 0.0
		if t < 0.25:
			pulse = (t / 0.25) * 1.4
		elif t < 0.42:
			pulse = lerpf(4.4, 2.2, (t - 0.25) / 0.17)
		else:
			pulse = maxf(0.0, 2.2 * (1.0 - (t - 0.42) / 0.65))
		_flash_light.light_energy = pulse * _power_scale

	func _trigger_table_camera_punch() -> void:
		var table = _table_ref.get_ref()
		if not is_instance_valid(table):
			return
		var shake_cur = table.get("cam_kick_shake")
		if shake_cur != null:
			table.set("cam_kick_shake", maxf(float(shake_cur), 0.52 if _is_knight_mist else 0.44))
		var spring = table.get("cam_spring")
		if spring != null and spring.has_method("trigger_score_recoil"):
			spring.trigger_score_recoil(35, 1.4, 0.55 if _attacker_is_player else 0.42)
