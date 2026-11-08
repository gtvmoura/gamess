extends Node2D
## Cena principal: monta o mundo e a interface.

const WorldScript := preload("res://scripts/world.gd")
const UIScript := preload("res://scripts/ui.gd")


func _ready() -> void:
	var world = WorldScript.new()
	world.name = "World"
	add_child(world)
	var ui = UIScript.new()
	ui.name = "UI"
	add_child(ui)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			var tour = load("res://scripts/screenshot_tour.gd").new()
			tour.out_dir = arg.trim_prefix("--screenshots=")
			add_child(tour)
