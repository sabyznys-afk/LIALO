extends SceneTree

const Catalog = preload("res://scripts/lialo_catalog.gd")
const ScoreEng = preload("res://scripts/scoring_engine.gd")
const DownpourRootScript = preload("res://scripts/downpour_root.gd")

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	print("=== VERIFY CATALOG CLEANUP (TASK #6) START ===")

	# 1. Verify scripts load and compile with 0 errors
	for spath in [
		"res://scripts/lialo_catalog.gd",
		"res://scripts/scoring_engine.gd",
		"res://scripts/downpour_root.gd",
	]:
		var res := ResourceLoader.load(spath)
		if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
			_fail("Failed to load/compile script: %s" % spath)
		else:
			print("OK script compiles: %s" % spath)

	# 2. Verify SPEC_PRISM and REL_PRISM_ORB are completely removed from POWER_CARDS and RELICS
	if not Catalog.get_power_card("SPEC_PRISM").is_empty():
		_fail("SPEC_PRISM should be removed from POWER_CARDS")
	for pc in Catalog.POWER_CARDS:
		if str(pc.get("id", "")) == "SPEC_PRISM":
			_fail("Found SPEC_PRISM in POWER_CARDS array")
	if not Catalog.get_relic("REL_PRISM_ORB").is_empty():
		_fail("REL_PRISM_ORB should be removed from RELICS")
	for r in Catalog.RELICS:
		if str(r.get("id", "")) == "REL_PRISM_ORB":
			_fail("Found REL_PRISM_ORB in RELICS array")
	print("OK SPEC_PRISM and REL_PRISM_ORB removed from POWER_CARDS (%d) and RELICS (%d)" % [Catalog.POWER_CARDS.size(), Catalog.RELICS.size()])

	# 3. Verify REL_CHAMOIS and REL_STORMCAP are temporarily hidden but definitions & scoring remain intact
	for hid in ["REL_CHAMOIS", "REL_STORMCAP"]:
		if not (hid in Catalog.TEMPORARILY_HIDDEN_RELICS):
			_fail("%s missing from Catalog.TEMPORARILY_HIDDEN_RELICS" % hid)
		if not Catalog.is_relic_hidden(hid):
			_fail("Catalog.is_relic_hidden('%s') returned false" % hid)
		if Catalog.get_relic(hid).is_empty():
			_fail("%s definition should still exist in Catalog.RELICS" % hid)
	for vis_r in Catalog.get_visible_relics():
		var v_id := str(vis_r.get("id", ""))
		if v_id in ["REL_CHAMOIS", "REL_STORMCAP", "REL_PRISM_ORB"]:
			_fail("get_visible_relics() leaked hidden/archived relic: %s" % v_id)
	if Catalog.is_relic_hidden("REL_GREED") or Catalog.is_relic_hidden("REL_FANG"):
		_fail("Starter relics REL_GREED / REL_FANG should not be hidden")
	print("OK REL_CHAMOIS and REL_STORMCAP flagged hidden while definitions remain in RELICS (visible=%d)" % Catalog.get_visible_relics().size())

	# 4. Verify get_default_profile() and 50 iterations of generate_shop_offers()
	var def_prof := Catalog.get_default_profile()
	var def_cc: Array = def_prof.get("custom_cards", [])
	var def_ar: Array = def_prof.get("active_relics", [])
	var def_uc: Array = def_prof.get("unlocked_cards", [])
	for forbidden_card in ["SPEC_PRISM"]:
		if (forbidden_card in def_cc) or (forbidden_card in def_uc):
			_fail("get_default_profile() contains archived card: %s" % forbidden_card)
	for forbidden_rel in ["REL_PRISM_ORB", "REL_CHAMOIS", "REL_STORMCAP"]:
		if forbidden_rel in def_ar:
			_fail("get_default_profile() active_relics contains hidden/archived relic: %s" % forbidden_rel)
	if def_prof.has("prism_pts_bonus"):
		_fail("get_default_profile() still contains stale prism_pts_bonus key")
	print("OK get_default_profile() clean (active_relics=%s)" % str(def_ar))

	for i in range(50):
		var offers := Catalog.generate_shop_offers(def_prof, "en" if (i % 2 == 0) else "cs")
		if offers.is_empty():
			_fail("generate_shop_offers() returned empty array on iteration %d" % i)
		for off in offers:
			var oid := str(off.get("id", ""))
			if oid in ["SPEC_PRISM", "REL_PRISM_ORB", "REL_CHAMOIS", "REL_STORMCAP"]:
				_fail("generate_shop_offers() leaked forbidden ID '%s' on iteration %d" % [oid, i])
	print("OK 50 iterations of generate_shop_offers() free of archived/hidden items")

	# 5. Verify load_profile() sanitization on a synthetic legacy profile
	var backup_cfg := ConfigFile.new()
	var had_existing_save := (backup_cfg.load(Catalog.PROFILE_PATH) == OK)

	var legacy_cfg := ConfigFile.new()
	legacy_cfg.set_value("run", "gold", 333)
	legacy_cfg.set_value("run", "prism_pts_bonus", 16)
	legacy_cfg.set_value("deck", "custom_cards", ["SPEC_VAMPIRE", "SPEC_PRISM", "SPEC_STORM"])
	legacy_cfg.set_value("deck", "active_relics", ["REL_CHAMOIS", "REL_PRISM_ORB", "REL_STORMCAP", "REL_GREED"])
	legacy_cfg.set_value("deck", "card_editions", {"CERVEN_E": "MAGE", "SPEC_PRISM": "KNIGHT"})
	legacy_cfg.set_value("collection", "unlocked_cards", ["CERVEN_7", "SPEC_PRISM", "SPEC_VAMPIRE"])
	legacy_cfg.save(Catalog.PROFILE_PATH)

	var loaded_legacy := Catalog.load_profile()
	if "SPEC_PRISM" in (loaded_legacy.get("custom_cards", []) as Array):
		_fail("load_profile() failed to strip SPEC_PRISM from custom_cards")
	if "SPEC_PRISM" in (loaded_legacy.get("unlocked_cards", []) as Array):
		_fail("load_profile() failed to strip SPEC_PRISM from unlocked_cards")
	if (loaded_legacy.get("card_editions", {}) as Dictionary).has("SPEC_PRISM"):
		_fail("load_profile() failed to strip SPEC_PRISM from card_editions")
	for bad_rel in ["REL_PRISM_ORB", "REL_CHAMOIS", "REL_STORMCAP"]:
		if bad_rel in (loaded_legacy.get("active_relics", []) as Array):
			_fail("load_profile() failed to strip %s from active_relics" % bad_rel)
	if not ("REL_GREED" in (loaded_legacy.get("active_relics", []) as Array)):
		_fail("load_profile() stripped valid relic REL_GREED from active_relics")
	if loaded_legacy.has("prism_pts_bonus"):
		_fail("load_profile() failed to strip prism_pts_bonus")

	if had_existing_save:
		backup_cfg.save(Catalog.PROFILE_PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Catalog.PROFILE_PATH))
	print("OK load_profile() sanitization stripped archived & hidden IDs cleanly")

	# 6. Verify ScoringEngine: Prism items inactive, hidden relics (REL_CHAMOIS, REL_STORMCAP) dormant logic intact
	var prism_test_card := {"suit": "CERVEN", "rank": "PWR", "pts": 22, "rname": "Prism", "power_id": "SPEC_PRISM", "edition": "MAGE", "mage_charge": 0}
	var rem_hand := [{"suit": "CERVEN", "rank": "7", "pts": 7, "rname": "Seven"}]
	var prism_res := ScoreEng.calculate_hand_score([prism_test_card], ["REL_PRISM_ORB"], rem_hand, {"lang": "en"})
	if float(prism_res.get("x_mult_product", 1.0)) != 1.0:
		_fail("REL_PRISM_ORB should no longer apply X-Mult in ScoringEngine (got %.2f)" % float(prism_res.get("x_mult_product", 1.0)))
	if float(prism_res.get("flat_mult", 1.0)) != 1.0:
		_fail("SPEC_PRISM should no longer apply +0.6x Flat Mult in ScoringEngine (got %.2f)" % float(prism_res.get("flat_mult", 1.0)))
	for st in (prism_res.get("steps", []) as Array):
		var st_d := st as Dictionary
		if str(st_d.get("relic_id", "")) == "REL_PRISM_ORB" or str(st_d.get("phase", "")) == "power":
			_fail("ScoringEngine emitted step for removed Prism item: %s" % str(st_d))

	var pair_acorns := [
		{"suit": "ZALUD", "rank": "8", "pts": 8, "rname": "Eight", "power_id": "", "edition": "NORMAL"},
		{"suit": "ZALUD", "rank": "8", "pts": 8, "rname": "Eight", "power_id": "", "edition": "NORMAL"},
	]
	var dormant_res := ScoreEng.calculate_hand_score(pair_acorns, ["REL_CHAMOIS", "REL_STORMCAP"], [], {"lang": "en"})
	var found_chamois := false
	var found_stormcap := false
	for st in (dormant_res.get("steps", []) as Array):
		var st_rid := str((st as Dictionary).get("relic_id", ""))
		if st_rid == "REL_CHAMOIS":
			found_chamois = true
		elif st_rid == "REL_STORMCAP":
			found_stormcap = true
	if not found_chamois or not found_stormcap:
		_fail("Dormant scoring logic for REL_CHAMOIS (%s) or REL_STORMCAP (%s) missing in ScoringEngine" % [found_chamois, found_stormcap])
	print("OK ScoringEngine: Prism branches removed, REL_CHAMOIS & REL_STORMCAP dormant scoring intact")

	# 7. Verify DownpourRoot Quick Showcase loadout and Archive Doc
	var d_root := DownpourRootScript.new()
	d_root.run_profile = Catalog.get_default_profile()
	d_root.game_options = Catalog.get_default_options()
	var q_loadout: Dictionary = d_root._build_roguelite_loadout_for_era(d_root.ERAS_DATA[0], true)
	for q_c in (q_loadout.get("custom_cards", []) as Array):
		if str(q_c) == "SPEC_PRISM":
			_fail("Quick Showcase loadout still includes SPEC_PRISM")
	for q_r in (q_loadout.get("active_relics", []) as Array):
		if str(q_r) in ["REL_PRISM_ORB", "REL_CHAMOIS", "REL_STORMCAP"]:
			_fail("Quick Showcase loadout still includes forbidden relic: %s" % str(q_r))
	d_root.free()
	print("OK DownpourRoot Quick Showcase loadout clean")

	var arch_path := "res://docs/ARCHIVE_PRISM_AND_HIDDEN_ITEMS.md"
	if not FileAccess.file_exists(arch_path):
		_fail("Missing archive markdown doc: %s" % arch_path)
	else:
		var arch_txt := FileAccess.get_file_as_string(arch_path)
		for req_token in ["SPEC_PRISM", "REL_PRISM_ORB", "REL_CHAMOIS", "REL_STORMCAP", "SPEC_PRISM.png", "REL_PRISM_ORB.png", "TEMPORARILY_HIDDEN_RELICS"]:
			if not arch_txt.contains(req_token):
				_fail("Archive doc missing required section/token: %s" % req_token)
		print("OK Archive doc verified: %s (%d chars)" % [arch_path, arch_txt.length()])

	if _failures.is_empty():
		print("=== VERIFY CATALOG CLEANUP: ALL CHECKS PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY CATALOG CLEANUP FAILED (%d errors) ===" % _failures.size())
		quit(1)
