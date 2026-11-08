extends Node
## Tour automático que tira prints do jogo (usado pelo CI).
## Ativado com: godot --path . -- --screenshots=/caminho/da/pasta

var out_dir := ""


func _ready() -> void:
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("print salvo: ", path)


func _ui():
	return get_tree().current_scene.get_node("UI")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _world():
	return get_tree().current_scene.get_node("World")


func _tabs(prefix: String) -> void:
	var ui = _ui()
	for tab in ["upgrades", "business", "city", "research", "expansion", "missions"]:
		ui.open_tab(tab)
		await _wait(1.0)
		await _shot("%s_%s" % [prefix, tab])
	ui.close_window()
	var w = _world()
	w.show_map()
	await _wait(1.0)
	await _shot("%s_mapa" % prefix)
	w.camera.focus(w.camera.position, 0.55, true)
	w.focus_district(0)
	await _wait(1.0)
	await _shot("%s_zoom_cidade" % prefix)
	w.focus_lot(true)
	await _wait(0.5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.reset_game()
	Game.money = 1200.0
	Game.hour = 7.6
	Game.changed.emit()
	await _wait(14.0)
	await _shot("01_inicio")
	await _tabs("02_inicio")

	# Cidade em crescimento
	Game.lvl = {"spots": 6, "attract": 5, "comfort": 4, "fleet": 5, "city": 8, "jobs": 8}
	Game.hour = 12.5
	Game.price_value = 14.0
	Game.services = {"wash": 2, "cafe": 1}
	Game.staff = {"washer": 1, "valet": 2, "cleaner": 1}
	Game.research_lvl = {"digital": 2, "marketing": 1}
	Game.research_key = "valet"
	Game.research_end = Time.get_unix_time_from_system() + 40.0
	Game.districts_unlocked = 3
	Game.money = 186450.0
	Game.gems = 75
	Game.level = 14
	Game.total_cars = 640
	Game.settle_population()
	Game.changed.emit()
	await _wait(16.0)
	await _shot("03_crescimento")
	await _tabs("04_crescimento")

	# Metrópole
	Game.lvl = {"spots": 18, "attract": 14, "comfort": 12, "fleet": 12, "city": 16, "jobs": 16}
	Game.hour = 17.6
	Game.price_value = 26.0
	Game.services = {"wash": 5, "cafe": 4, "ev": 3, "tire": 2}
	Game.staff = {"washer": 2, "valet": 4, "cleaner": 3, "guard": 2, "cashier": 2, "mechanic": 1}
	Game.research_key = ""
	Game.districts_unlocked = 6
	Game.money = 48700000.0
	Game.gems = 320
	Game.level = 41
	Game.boost_until = Time.get_unix_time_from_system() + 420.0
	Game.settle_population()
	Game.changed.emit()
	await _wait(16.0)
	await _shot("05_metropole")
	await _tabs("06_metropole")
	# serviços e funcionários no fundo do estacionamento
	_world().camera.focus(Vector2((24.0 - 29.5) * 32.0, (24.0 + 29.5) * 16.0), 1.2, true)
	await _wait(1.5)
	await _shot("08_servicos")
	_world().focus_lot(true)
	# a mesma cidade à noite
	Game.hour = 22.5
	await _wait(2.0)
	await _shot("07_noite")
	Game.reset_game()
	get_tree().quit()
