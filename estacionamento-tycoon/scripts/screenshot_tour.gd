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


func _tabs(prefix: String) -> void:
	var ui = _ui()
	for tab in ["upgrades", "city", "expansion", "missions"]:
		ui._open_tab(tab)
		await _wait(0.5)
		await _shot("%s_%s" % [prefix, tab])
	ui.close_window()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.reset_game()
	Game.money = 1200.0
	Game.changed.emit()
	await _wait(14.0)
	await _shot("01_inicio")
	await _tabs("02_inicio")

	# Cidade em crescimento
	Game.lvl = {"spots": 6, "attract": 5, "price": 6, "fleet": 5, "city": 8}
	Game.districts_unlocked = 3
	Game.money = 186450.0
	Game.gems = 75
	Game.level = 14
	Game.total_cars = 640
	Game.changed.emit()
	await _wait(16.0)
	await _shot("03_crescimento")
	await _tabs("04_crescimento")

	# Metrópole
	Game.lvl = {"spots": 18, "attract": 14, "price": 18, "fleet": 12, "city": 16}
	Game.districts_unlocked = 6
	Game.money = 48700000.0
	Game.gems = 320
	Game.level = 41
	Game.boost_until = Time.get_unix_time_from_system() + 420.0
	Game.changed.emit()
	await _wait(16.0)
	await _shot("05_metropole")
	await _tabs("06_metropole")
	Game.reset_game()
	get_tree().quit()
