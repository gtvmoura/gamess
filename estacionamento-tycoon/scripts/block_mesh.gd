extends Node2D
## Um quarteirão inteiro (prédios, casas, árvores) desenhado em um único comando.

var batch = null


func _draw() -> void:
	if batch != null:
		batch.flush(get_canvas_item())
