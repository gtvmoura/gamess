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
