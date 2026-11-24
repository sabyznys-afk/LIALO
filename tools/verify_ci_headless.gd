extends SceneTree

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func():
		printerr("TIMEOUT: verify_ci_headless exceeded 30s")
		quit(124)
	)
	call_deferred("_run")


func _run() -> void:
	print("=== VERIFY CI HEADLESS SMOKE (<5s) ===")
	var scripts := [
		"res://scripts/lialo_catalog.gd",
		"res://scripts/scoring_engine.gd",
		"res://scripts/downpour_root.gd",
		"res://scripts/battle/table_relic_manager.gd",
		"res://scripts/battle/combat_log_drawer.gd",
		"res://scripts/battle_table_3d.gd",
		"res://scripts/mp/mp_config.gd",
		"res://scripts/mp/mp_lobby_overlay.gd",
		"res://scripts/mp/mp_network.gd",
		"res://scripts/mp/mp_authority.gd",
		"res://scripts/mp/mp_battle_table_3d.gd",
		"res://scripts/mp/mp_dev_entry.gd",
	]
	for sp in scripts:
		var res := ResourceLoader.load(sp)
		if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
			_fail("Compile failed: " + sp)
	print("  OK: All %d core scripts compiled" % scripts.size())

	if _failures.is_empty():
		print("=== VERIFY CI HEADLESS: ALL PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY CI HEADLESS FAILED (%d) ===" % _failures.size())
		quit(1)
