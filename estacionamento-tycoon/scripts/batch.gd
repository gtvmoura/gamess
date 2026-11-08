extends RefCounted
## Junta muitos polígonos num único comando de desenho (triangle array).
## Imita a API de desenho do CanvasItem para os helpers do Iso funcionarem com ela.

var pts := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


## Polígonos convexos (quads, triângulos, elipses) triangulados em leque.
func draw_colored_polygon(poly: PackedVector2Array, color: Color) -> void:
	var n := poly.size()
	if n < 3:
		return
	var base := pts.size()
	pts.append_array(poly)
	for i in n:
		cols.append(color)
	for i in range(1, n - 1):
		idx.append(base)
		idx.append(base + i)
		idx.append(base + i + 1)


func draw_line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var n := Vector2(-d.y, d.x).normalized() * width * 0.5
	draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), color)


func draw_circle(c: Vector2, r: float, color: Color) -> void:
	var poly := PackedVector2Array()
	var seg := 10 if r < 6.0 else 14
	for i in seg:
		var a := TAU * i / seg
		poly.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(poly, color)


func is_empty() -> bool:
	return idx.is_empty()


func flush(item: RID) -> void:
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(item, idx, pts, cols)
