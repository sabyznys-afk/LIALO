extends SceneTree

## Headless verification script for LIALO Task #3: 5 Era Opponent 3D Models
## Verifies all 5 GLBs in res://assets/models/opponents/:
##   1. opp_antika.glb
##   2. opp_rim.glb
##   3. opp_stredovek.glb
##   4. opp_objavy.glb
##   5. opp_prohibicia.glb
## Asserts:
##   - Clean loading & instantiation
##   - Exact required pivot contract: TorsoPivot, HeadPivot, ArmLPivot, ArmRPivot, EyeL, EyeR
##   - Seated table scale, shoulder/head pivot heights, and +Z table-facing orientation
##   - Distinct sculpted mesh/vertex counts & era-specific signature child meshes (no clones!)

const ERA_GLBS := {
	"antika": {
		"path": "res://assets/models/opponents/opp_antika.glb",
		"signature_nodes": ["EgyptMuscularTorso", "UsekhCollarTier_0", "NemesHeaddressHoodFront", "UraeusCobraBody", "GoldBracer_L"],
	},
	"rim": {
		"path": "res://assets/models/opponents/opp_rim.glb",
		"signature_nodes": ["LoricaGirthHoop_0", "PaludamentumChestDrape", "GoldFibulaBrooch", "GaleaSteelBowl", "TransverseHorsehairCrest", "LeatherVambrace_L"],
	},
	"stredovek": {
		"path": "res://assets/models/opponents/opp_stredovek.glb",
		"signature_nodes": ["GothicSteelCuirass", "HeraldicSurcoatFront", "LeatherSwordBaldric", "FlutedSalletDome", "AventailChainmailCoif", "SteelGauntletCuff_L"],
	},
	"objavy": {
		"path": "res://assets/models/opponents/opp_objavy.glb",
		"signature_nodes": ["NavalLongcoatBody", "AdmiralHighCollar", "CrossedBandolier_1", "BrassCompassBezel", "TricornUpturnedBrim", "RuffledShirtCuff_L"],
	},
	"prohibicia": {
		"path": "res://assets/models/opponents/opp_prohibicia.glb",
		"signature_nodes": ["CharcoalSuitBody", "BroadPeakedLapel_L", "CrimsonSilkTie", "RubyTiePin", "FedoraPinchedCrown", "HavanaCigarBody", "CigarGlowingEmber"],
	},
}

const REQUIRED_PIVOTS := ["TorsoPivot", "HeadPivot", "ArmLPivot", "ArmRPivot", "EyeL", "EyeR"]

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _load_glb_node(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var ps := ResourceLoader.load(res_path) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			if inst is Node3D:
				return inst as Node3D
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_file(abs_p, state) == OK:
			var gen := gltf.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	return null


func _collect_meshes(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out_list.append(node as MeshInstance3D)
	for ch in node.get_children():
		_collect_meshes(ch, out_list)


func _compute_total_verts(meshes: Array[MeshInstance3D]) -> int:
	var total := 0
	for mi in meshes:
		var m := mi.mesh
		if m != null:
			for si in range(m.get_surface_count()):
				var arr := m.surface_get_arrays(si)
				if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	print("=== VERIFY ERA OPPONENTS 3D START ===")
	var signatures_seen: Dictionary = {}

	for era_id in ERA_GLBS.keys():
		var info: Dictionary = ERA_GLBS[era_id]
		var glb_path: String = info["path"]
		var inst := _load_glb_node(glb_path)
		if inst == null:
			_fail("[%s] Failed to load or instantiate %s" % [era_id, glb_path])
			continue

		root.add_child(inst)

		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(inst, meshes)
		var mesh_cnt := meshes.size()
		var vert_cnt := _compute_total_verts(meshes)

		if mesh_cnt < 25:
			_fail("[%s] Expected >= 25 sculpted sub-meshes in %s, got %d" % [era_id, glb_path, mesh_cnt])
		if vert_cnt < 1500:
			_fail("[%s] Expected >= 1500 vertices in %s, got %d" % [era_id, glb_path, vert_cnt])

		# 1. Verify required pivots exist & match coordinate contract
		var found_pivots: Dictionary = {}
		for piv_name in REQUIRED_PIVOTS:
			var p_node := inst.find_child(piv_name, true, false) as Node3D
			if p_node == null:
				_fail("[%s] Missing required pivot node '%s' in %s" % [era_id, piv_name, glb_path])
			else:
				found_pivots[piv_name] = p_node

		if found_pivots.has("TorsoPivot"):
			var tp: Node3D = found_pivots["TorsoPivot"]
			if tp.position.length() > 0.02:
				_fail("[%s] TorsoPivot should be at local (0,0,0), got %s" % [era_id, str(tp.position)])

		if found_pivots.has("HeadPivot"):
			var hp: Node3D = found_pivots["HeadPivot"]
			if hp.position.y < 0.52 or hp.position.y > 0.60:
				_fail("[%s] HeadPivot.position.y out of expected [0.52..0.60] range (~0.562): %.3f" % [era_id, hp.position.y])

		if found_pivots.has("ArmLPivot"):
			var alp: Node3D = found_pivots["ArmLPivot"]
			if alp.position.x > -0.20 or alp.position.y < 0.38 or alp.position.y > 0.50:
				_fail("[%s] ArmLPivot position invalid: %s" % [era_id, str(alp.position)])

		if found_pivots.has("ArmRPivot"):
			var arp: Node3D = found_pivots["ArmRPivot"]
			if arp.position.x < 0.20 or arp.position.y < 0.38 or arp.position.y > 0.50:
				_fail("[%s] ArmRPivot position invalid: %s" % [era_id, str(arp.position)])

		for eye_key in ["EyeL", "EyeR"]:
			if found_pivots.has(eye_key):
				var eye_node: Node3D = found_pivots[eye_key]
				if not (eye_node is MeshInstance3D) or (eye_node as MeshInstance3D).mesh == null:
					_fail("[%s] %s must be a MeshInstance3D with a non-null mesh" % [era_id, eye_key])
				if found_pivots.has("HeadPivot") and eye_node.get_parent() != found_pivots["HeadPivot"]:
					_fail("[%s] %s must be a child of HeadPivot" % [era_id, eye_key])
				if eye_node.position.z < 0.08:
					_fail("[%s] %s must face +Z toward player (local z > 0.08), got %.3f" % [era_id, eye_key, eye_node.position.z])

		# 2. Verify era-specific sculpted signature parts exist (proving non-clone geometry)
		var sig_list: Array = info["signature_nodes"]
		for sig_name in sig_list:
			if inst.find_child(str(sig_name), true, false) == null:
				_fail("[%s] Missing era-specific sculpted part '%s' in %s" % [era_id, str(sig_name), glb_path])

		var geom_sig := "%d_%d" % [mesh_cnt, vert_cnt]
		if signatures_seen.has(geom_sig):
			_fail("[%s] Duplicate mesh/vertex signature %s with era '%s' (clones forbidden!)" % [era_id, geom_sig, str(signatures_seen[geom_sig])])
		signatures_seen[geom_sig] = era_id

		print(
			"OK [%s] %s | meshes=%d | verts=%d | HeadPivot=%s | ArmL=%s | ArmR=%s | EyeL=%s | EyeR=%s"
			% [
				era_id,
				glb_path,
				mesh_cnt,
				vert_cnt,
				str(found_pivots.get("HeadPivot", inst).position),
				str(found_pivots.get("ArmLPivot", inst).position),
				str(found_pivots.get("ArmRPivot", inst).position),
				str(found_pivots.get("EyeL", inst).position),
				str(found_pivots.get("EyeR", inst).position),
			]
		)

		inst.queue_free()

	if _failures.is_empty():
		print("=== VERIFY ERA OPPONENTS 3D: ALL 5 ERA MODELS PASSED (0 FAILURES) ===")
		quit(0)
	else:
		printerr("=== VERIFY ERA OPPONENTS 3D FAILED (%d errors) ===" % _failures.size())
		quit(1)
