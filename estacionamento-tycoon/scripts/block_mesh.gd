extends Node2D
## Um quarteirão inteiro desenhado em poucos comandos, na ordem certa (de trás para frente):
## blocos de polígonos agrupados (Batch) intercalados com sprites (texturas).

var ops: Array = []   # ["b", Batch] ou ["t", Texture2D, Rect2]


func _draw() -> void:
	for op in ops:
		if op[0] == "b":
			op[1].flush(get_canvas_item())
		else:
			draw_texture_rect(op[1], op[2], false)
