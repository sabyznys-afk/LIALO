extends SceneTree

const RelicMesh = preload("res://scripts/relic_mesh_factory.gd")
const BlenderVfx = preload("res://scripts/blender_vfx_animator.gd")

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _set_owner_recursive(node: Node, root_owner: Node) -> void:
	for ch in node.get_children():
		ch.owner = root_owner
		_set_owner_recursive(ch, root_owner)


func _sync_imported_scn_cache(glb_paths: Array[String]) -> void:
	for res_path in glb_paths:
		var import_cfg_path := res_path + ".import"
		if not FileAccess.file_exists(import_cfg_path):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(import_cfg_path) != OK:
			continue
		var scn_path := str(cfg.get_value("remap", "path", ""))
		if scn_path == "":
			continue
		var abs_p := ProjectSettings.globalize_path(res_path)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(abs_p, st) == OK:
			var gen := doc.generate_scene(st)
			if gen != null:
				_set_owner_recursive(gen, gen)
				var ps := PackedScene.new()
				if ps.pack(gen) == OK:
					ResourceSaver.save(ps, scn_path)
				gen.free()


func _load_glb(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var ps := ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			if inst is Node3D:
				return inst as Node3D
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(abs_p, st) == OK:
			var gen := doc.generate_scene(st)
			if gen is Node3D:
				return gen as Node3D
	return null


func _count_meshes(node: Node) -> int:
	var c := 1 if (node is MeshInstance3D and (node as MeshInstance3D).mesh != null) else 0
	for ch in node.get_children():
		c += _count_meshes(ch)
	return c


func _count_vertices(node: Node) -> int:
	var v := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var m := (node as MeshInstance3D).mesh
		for si in range(m.get_surface_count()):
			var arr := m.surface_get_arrays(si)
			if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				v += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for ch in node.get_children():
		v += _count_vertices(ch)
	return v


func _compute_aabb(root_node: Node3D) -> AABB:
	var has_first := false
	var combined := AABB()
	var stack: Array = [[root_node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var cur: Node = item[0]
		var xf: Transform3D = item[1]
		if cur is Node3D and cur != root_node:
			xf = xf * (cur as Node3D).transform
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
			var maabb := (cur as MeshInstance3D).mesh.get_aabb()
			for ix in [0.0, 1.0]:
				for iy in [0.0, 1.0]:
					for iz in [0.0, 1.0]:
						var pt := xf * (maabb.position + maabb.size * Vector3(ix, iy, iz))
						if not has_first:
							combined = AABB(pt, Vector3.ZERO)
							has_first = true
						else:
							combined = combined.expand(pt)
		for ch in cur.get_children():
			stack.append([ch, xf])
	return combined


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== VERIFY HERO TABLE PROPS START ===")

	_sync_imported_scn_cache([
		"res://assets/models/sword_oath.glb",
		"res://assets/models/swords/SWORD_IRON.glb",
		"res://assets/models/swords/SWORD_GILDED.glb",
		"res://assets/models/swords/SWORD_CRIMSON.glb",
		"res://assets/models/swords/SWORD_RUNE.glb",
		"res://assets/models/swords/SWORD_DRAGON.glb",
		"res://assets/models/tavern_mug.glb",
		"res://assets/models/phial_ignis.glb",
		"res://assets/models/vfx/hellfire_phial_hero.glb",
	])

	# 1. Verify scripts compile cleanly
	for spath in [
		"res://scripts/relic_mesh_factory.gd",
		"res://scripts/blender_vfx_animator.gd",
	]:
		var res := ResourceLoader.load(spath)
		if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
			_fail("Failed to compile script: %s" % spath)
		else:
			print("OK script: %s" % spath)

	# 2. Verify all 6 Hero Swords (sword_oath.glb + 5 SWORD_*.glb)
	var sword_checks := {
		"res://assets/models/sword_oath.glb": ["Blade", "Fuller", "GuardCross", "GuardEcusson", "GripCore", "GripWireWrap", "PommelBody", "GemCross", "GemPommel"],
		"res://assets/models/swords/SWORD_IRON.glb": ["FalchionBlade", "Fuller", "ForteCollar", "SGuard", "NagelSideRing", "Grip", "GripWireWrap", "PommelDisc", "PommelGem"],
		"res://assets/models/swords/SWORD_GILDED.glb": ["ClaymoreBlade", "GoldFuller", "RoyalRicassoCollar", "VGuard", "Quatrefoil_1_0", "PasDAne_1", "Grip", "GripWireWrap", "PommelDisc", "PommelGem"],
		"res://assets/models/swords/SWORD_CRIMSON.glb": ["SaberBlade", "BloodVein", "BloodBarb_0", "BatKnuckleBow", "BatWingSpine_0", "Grip", "GripWireWrap", "PommelDisc", "PommelGem"],
		"res://assets/models/swords/SWORD_RUNE.glb": ["RuneBlade", "RuneInlay", "RuneGlyph_0", "StormQuillon_1", "QuillonCrystal_1", "Grip", "GripWireWrap", "PommelDisc", "PommelGem"],
		"res://assets/models/swords/SWORD_DRAGON.glb": ["DragonBlade", "LavaCore", "Serr_1_0", "LavaVent_1_0", "DragonWing_1", "DragonHorn_1", "Grip", "GripWireWrap", "PommelDisc", "PommelGem"],
	}

	for spath in sword_checks.keys():
		var inst := _load_glb(spath)
		if inst == null:
			_fail("Failed to load sword GLB: %s" % spath)
			continue
		var mcnt := _count_meshes(inst)
		var vcnt := _count_vertices(inst)
		if mcnt < 15:
			_fail("%s has too few meshes: %d (< 15)" % [spath, mcnt])
		if vcnt < 600:
			_fail("%s has too few vertices for close-up hero prop: %d (< 600)" % [spath, vcnt])
		var req_nodes: Array = sword_checks[spath]
		for rname in req_nodes:
			if inst.find_child(rname, true, false) == null:
				_fail("%s missing required sculpted part node: %s" % [spath, rname])
		var aabb := _compute_aabb(inst)
		var z_min := aabb.position.z
		var z_max := aabb.position.z + aabb.size.z
		if z_min > -0.60 or z_max < 0.16:
			_fail("%s orientation/length mismatch: z_min=%.3f (expected <= -0.60), z_max=%.3f (expected >= 0.16)" % [spath, z_min, z_max])
		if aabb.position.y < -0.005 or aabb.position.y > 0.015:
			_fail("%s resting Y bottom out of range: y_min=%.4f" % [spath, aabb.position.y])
		print("OK Hero Sword: %s (meshes=%d, verts=%d, aabb_size=%s)" % [spath, mcnt, vcnt, str(aabb.size)])
		inst.free()

	# 3. Verify Hero Beer Mug (tavern_mug.glb)
	var mug_path := "res://assets/models/tavern_mug.glb"
	var mug_inst := _load_glb(mug_path)
	if mug_inst == null:
		_fail("Failed to load %s" % mug_path)
	else:
		var mcnt := _count_meshes(mug_inst)
		var vcnt := _count_vertices(mug_inst)
		if mcnt < 60:
			_fail("tavern_mug.glb expected >= 60 individual sculpted parts, got %d" % mcnt)
		if vcnt < 2500:
			_fail("tavern_mug.glb expected >= 2500 vertices, got %d" % vcnt)
		for mpart in [
			"MugStave_0", "MugStave_15", "MugBottomDisc",
			"MugHoop_2", "MugHoop_10", "MugBrassRim",
			"MugCrest_Front", "MugHandle", "MugThumbRest",
			"MugAleSurface", "MugFoamCap", "FoamBubble_0", "FoamDrip_0", "FoamDrip_3",
		]:
			if mug_inst.find_child(mpart, true, false) == null:
				_fail("tavern_mug.glb missing required close-up part: %s" % mpart)
		var maabb := _compute_aabb(mug_inst)
		if absf(maabb.position.y) > 0.004:
			_fail("tavern_mug.glb base must rest at Y=0, got y_min=%.4f" % maabb.position.y)
		if maabb.size.y < 0.14 or maabb.size.y > 0.175:
			_fail("tavern_mug.glb height out of range: %.4f" % maabb.size.y)
		print("OK Hero Beer Mug: %s (meshes=%d, verts=%d, aabb_size=%s)" % [mug_path, mcnt, vcnt, str(maabb.size)])
		mug_inst.free()

	# 4. Verify Hero Hellfire Phials (phial_ignis.glb & vfx/hellfire_phial_hero.glb)
	for ppath in [
		"res://assets/models/phial_ignis.glb",
		"res://assets/models/vfx/hellfire_phial_hero.glb",
	]:
		var pinst := _load_glb(ppath)
		if pinst == null:
			_fail("Failed to load %s" % ppath)
			continue
		var mcnt := _count_meshes(pinst)
		var vcnt := _count_vertices(pinst)
		if mcnt < 45:
			_fail("%s expected >= 45 sculpted parts, got %d" % [ppath, mcnt])
		if vcnt < 2500:
			_fail("%s expected >= 2500 vertices, got %d" % [ppath, vcnt])
		for ppart in [
			"IgnitedPlume", "IgniteSpiral", "IgniteTongue_0",
			"PhialCoaster", "PhialCoasterRim", "PhialGlass",
			"PhialIronCage", "CageEquator", "CageShoulderBand", "CageMeridian_0", "CageMeridian_7",
			"PhialHandle_L", "PhialHandle_R", "PhialCollar", "HempCord_0", "AlchemicalTagSeal",
			"PhialCork", "PhialWaxSeal", "WaxDrip_0", "WaxDrip_5", "PhialWick", "PhialWickFlame",
			"PhialMagmaCore", "MagmaInnerNucleus", "MagmaSwirl_0", "PhialEmber_0", "PhialEmber_9",
		]:
			if pinst.find_child(ppart, true, false) == null:
				_fail("%s missing required close-up part: %s" % [ppath, ppart])
		var paabb := _compute_aabb(pinst)
		if absf(paabb.position.y) > 0.004:
			_fail("%s base must rest at Y=0, got y_min=%.4f" % [ppath, paabb.position.y])
		if paabb.size.y < 0.20 or paabb.size.y > 0.27:
			_fail("%s height out of range: %.4f" % [ppath, paabb.size.y])
		print("OK Hero Hellfire Phial: %s (meshes=%d, verts=%d, aabb_size=%s)" % [ppath, mcnt, vcnt, str(paabb.size)])
		pinst.free()

	# 5. Verify RelicMeshFactory live builders in SceneTree
	var stage := Node3D.new()
	root.add_child(stage)

	for sid in ["SWORD_IRON", "SWORD_GILDED", "SWORD_CRIMSON", "SWORD_RUNE", "SWORD_DRAGON", "sword_oath"]:
		var sw_node := RelicMesh.build_sword_3d_mesh(sid)
		stage.add_child(sw_node)
		if not sw_node.get_meta("blender_glb", false) or _count_meshes(sw_node) < 15:
			_fail("RelicMesh.build_sword_3d_mesh('%s') failed to wire hero GLB" % sid)

	var mug_holder := Node3D.new()
	stage.add_child(mug_holder)
	RelicMesh.build_tavern_mug_meshes(mug_holder)
	if not mug_holder.get_meta("blender_glb", false) or _count_meshes(mug_holder) < 60:
		_fail("RelicMesh.build_tavern_mug_meshes failed to wire hero tavern_mug.glb")

	var phial_holder := Node3D.new()
	stage.add_child(phial_holder)
	RelicMesh.build_hellfire_phial_meshes(phial_holder)
	var hero_phial := phial_holder.find_child("BlenderHellfirePhial", true, false)
	if hero_phial == null or _count_meshes(phial_holder) < 45:
		_fail("RelicMesh.build_hellfire_phial_meshes failed to wire BlenderHellfirePhial")
	else:
		var plume := hero_phial.find_child("IgnitedPlume", true, false) as Node3D
		if plume == null:
			_fail("Wired BlenderHellfirePhial missing IgnitedPlume node")
		elif plume.visible:
			_fail("Wired BlenderHellfirePhial IgnitedPlume must be hidden on idle table placement")

	stage.queue_free()
	print("OK RelicMeshFactory live builders (Swords, Beer Mug, Hellfire Phial)")

	if _failures.is_empty():
		print("VERIFY_HERO_TABLE_PROPS_ALL_PASSED")
		quit(0)
	else:
		printerr("TOTAL FAILURES: %d" % _failures.size())
		quit(1)
