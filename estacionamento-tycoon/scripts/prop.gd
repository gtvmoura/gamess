extends Node2D
## Objeto estático do mapa (prédio, casa, árvore, poste...). Desenhado por código em isométrico.

const Iso := preload("res://scripts/iso.gd")
const FLOOR_H := 11.0

var kind := "tree"
var x0 := 0.0
var y0 := 0.0
var w := 1.0
var d := 1.0
var floors := 1
var color := Color.WHITE
var color2 := Color.WHITE
var seed_value := 0
var lit_chance := 0.05
var size_f := 0.0
var _t := 0.0


## Prepara o objeto. O nó fica na quina da frente (para o y-sort funcionar).
func setup(k: String, gx: float, gy: float, gw: float = 0.0, gd: float = 0.0) -> void:
	kind = k
	x0 = gx
	y0 = gy
	w = gw
	d = gd
	position = Iso.p(x0 + w, y0 + d)
	set_process(kind == "pin")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var o := position
	match kind:
		"house":
			_draw_house(o)
		"building":
			_draw_building(o, false)
		"tower":
			_draw_building(o, true)
		"warehouse":
			_draw_warehouse(o)
		"tree":
			_draw_tree(o)
		"palm":
			_draw_palm(o)
		"lamp":
			_draw_lamp(o)
		"canopy":
			_draw_canopy(o)
		"booth":
			_draw_booth(o)
		"kiosk":
			_draw_kiosk(o)
		"umbrella":
			_draw_umbrella(o)
		"pin":
			_draw_pin(o)


func _draw_house(o: Vector2) -> void:
	var wall_h := FLOOR_H * 1.6 * floors
	Iso.shadow(self, o, x0, y0, w, d, wall_h)
	Iso.prism(self, o, x0, y0, w, d, 0.0, wall_h, color)
	# porta e janelas
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	Iso.windows(self, o, x0, y0, w, d, 2.0, floors, FLOOR_H * 1.6, "x", rng, lit_chance, Color("3b5068"))
	var door := PackedVector2Array([
		Iso.p(x0 + w * 0.3, y0 + d, 0) - o, Iso.p(x0 + w * 0.48, y0 + d, 0) - o,
		Iso.p(x0 + w * 0.48, y0 + d, 12) - o, Iso.p(x0 + w * 0.3, y0 + d, 12) - o])
	draw_colored_polygon(door, Color("6b4429"))
	# telhado de duas águas (cumeeira ao longo de x)
	var z1 := wall_h
	var rh := 14.0
	var ym := y0 + d * 0.5
	var r1 := Iso.p(x0 - 0.08, ym, z1 + rh) - o
	var r2 := Iso.p(x0 + w + 0.08, ym, z1 + rh) - o
	var back := PackedVector2Array([Iso.p(x0 - 0.08, y0 - 0.08, z1) - o, Iso.p(x0 + w + 0.08, y0 - 0.08, z1) - o, r2, r1])
	var front := PackedVector2Array([Iso.p(x0 - 0.08, y0 + d + 0.08, z1) - o, Iso.p(x0 + w + 0.08, y0 + d + 0.08, z1) - o, r2, r1])
	draw_colored_polygon(back, color2.darkened(0.15))
	draw_colored_polygon(front, color2)
	var gable := PackedVector2Array([Iso.p(x0 + w, y0, z1) - o, Iso.p(x0 + w, y0 + d, z1) - o, Iso.p(x0 + w, ym, z1 + rh) - o])
	draw_colored_polygon(gable, color.darkened(0.3))
	draw_line(r1, r2, color2.lightened(0.25), 2.0)


func _draw_building(o: Vector2, tower: bool) -> void:
	var h := FLOOR_H * floors + 6.0
	Iso.shadow(self, o, x0, y0, w, d, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# térreo com toldo/loja
	Iso.prism(self, o, x0, y0, w, d, 0.0, 12.0, color.darkened(0.15))
	Iso.prism(self, o, x0, y0, w, d, 12.0, h - 12.0, color)
	var glass := Color("8fc4e8") if tower else Color("3b5068")
	Iso.windows(self, o, x0, y0, w, d, 12.0, floors - 1, FLOOR_H, "y", rng, lit_chance, glass)
	Iso.windows(self, o, x0, y0, w, d, 12.0, floors - 1, FLOOR_H, "x", rng, lit_chance, glass)
	# vitrine e toldo da loja
	var aw := Color.from_hsv(rng.randf(), 0.7, 0.85)
	draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + 0.15, y0 + d, 2) - o, Iso.p(x0 + w - 0.15, y0 + d, 2) - o,
		Iso.p(x0 + w - 0.15, y0 + d, 9) - o, Iso.p(x0 + 0.15, y0 + d, 9) - o]), Color("a8d8f0"))
	draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + 0.1, y0 + d, 12) - o, Iso.p(x0 + w - 0.1, y0 + d, 12) - o,
		Iso.p(x0 + w - 0.1, y0 + d + 0.3, 8) - o, Iso.p(x0 + 0.1, y0 + d + 0.3, 8) - o]), aw)
	# topo: platibanda e equipamentos
	Iso.prism(self, o, x0 + 0.1, y0 + 0.1, w - 0.2, d - 0.2, h, 0.0, color.darkened(0.45))
	if tower:
		Iso.prism(self, o, x0 + w * 0.3, y0 + d * 0.3, w * 0.4, d * 0.4, h, 10.0, color.lightened(0.1))
		draw_line(Iso.p(x0 + w * 0.5, y0 + d * 0.5, h + 10) - o, Iso.p(x0 + w * 0.5, y0 + d * 0.5, h + 34) - o, Color("dddddd"), 2.0)
		draw_circle(Iso.p(x0 + w * 0.5, y0 + d * 0.5, h + 34) - o, 2.5, Color("ff3b3b"))
	else:
		Iso.prism(self, o, x0 + w * 0.6, y0 + d * 0.2, 0.5, 0.4, h, 6.0, Color("b8b8b8"))


func _draw_warehouse(o: Vector2) -> void:
	var h := 22.0 * floors
	Iso.shadow(self, o, x0, y0, w, d, h)
	Iso.prism(self, o, x0, y0, w, d, 0.0, h, color, Color("9aa3ad"))
	for i in 4:
		var t := (i + 0.5) / 4.0
		draw_line(Iso.p(x0 + w * t, y0, h) - o, Iso.p(x0 + w * t, y0 + d, h) - o, Color("7d8590"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + w * 0.3, y0 + d, 0) - o, Iso.p(x0 + w * 0.7, y0 + d, 0) - o,
		Iso.p(x0 + w * 0.7, y0 + d, h * 0.6) - o, Iso.p(x0 + w * 0.3, y0 + d, h * 0.6) - o]), Color("5c6670"))


func _draw_tree(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	var s := 0.7 + size_f
	draw_colored_polygon(_ellipse(base + Vector2(6, 2), 13.0 * s, 5.0 * s), Color(0, 0, 0, 0.22))
	draw_line(base, base - Vector2(0, 12 * s), Color("6b4429"), 3.0)
	var c := color
	draw_circle(base - Vector2(0, 20 * s), 10.0 * s, c.darkened(0.25))
	draw_circle(base - Vector2(-3, 23 * s), 8.0 * s, c)
	draw_circle(base - Vector2(2, 27 * s), 5.5 * s, c.lightened(0.2))


func _draw_palm(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	var s := 0.8 + size_f
	draw_colored_polygon(_ellipse(base + Vector2(8, 2), 12.0 * s, 4.0 * s), Color(0, 0, 0, 0.2))
	var top := base + Vector2(4 * s, -34 * s)
	draw_line(base, base + Vector2(2 * s, -18 * s), Color("8a6a3e"), 3.0)
	draw_line(base + Vector2(2 * s, -18 * s), top, Color("8a6a3e"), 3.0)
	var leaf := color
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var tip := top + Vector2(cos(a) * 16 * s, sin(a) * 7 * s + 6 * s)
		var mid := top + Vector2(cos(a) * 9 * s, sin(a) * 4 * s - 3 * s)
		draw_colored_polygon(PackedVector2Array([top, mid + Vector2(0, -2), tip, mid + Vector2(0, 2)]), leaf if i % 2 == 0 else leaf.darkened(0.2))
	draw_circle(top, 2.5 * s, Color("6b4f2a"))


func _draw_lamp(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	draw_line(base, base - Vector2(0, 34), Color("3a3d44"), 2.0)
	draw_line(base - Vector2(0, 34), base - Vector2(-7, 36), Color("3a3d44"), 2.0)
	if lit_chance > 0.3:
		draw_circle(base - Vector2(-7, 34), 9.0, Color(1, 0.9, 0.5, 0.25))
	draw_circle(base - Vector2(-7, 35), 2.5, Color("fff2b0"))


func _draw_canopy(o: Vector2) -> void:
	var h := 26.0
	for t in [0.0, 0.33, 0.66, 1.0]:
		var px: float = x0 + w * t
		draw_line(Iso.p(px, y0 + d, 0) - o, Iso.p(px, y0 + d, h) - o, Color("c9ccd2"), 2.0)
	var col := Color("2f5fb3")
	Iso.prism(self, o, x0, y0, w, d, h, 2.0, col.darkened(0.2), col)
	var cells := int(w * 2.0)
	for i in cells:
		var a := x0 + w * (i + 0.1) / cells
		var b := x0 + w * (i + 0.9) / cells
		Iso.quad(self, o, a, y0 + 0.1, b - a, d - 0.2, h + 2.1, Color("4a86e8"))


func _draw_booth(o: Vector2) -> void:
	Iso.shadow(self, o, x0, y0, w, d, 20)
	Iso.prism(self, o, x0, y0, w, d, 0.0, 18.0, Color("f2f2f2"))
	draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + w, y0 + 0.1, 8) - o, Iso.p(x0 + w, y0 + d - 0.1, 8) - o,
		Iso.p(x0 + w, y0 + d - 0.1, 15) - o, Iso.p(x0 + w, y0 + 0.1, 15) - o]), Color("7fc2ea"))
	Iso.prism(self, o, x0 - 0.05, y0 - 0.05, w + 0.1, d + 0.1, 18.0, 3.0, Color("f2c230"))
	# cancela
	draw_line(Iso.p(x0 + w, y0 + d, 10) - o, Iso.p(x0 + w + 0.9, y0 + d, 10) - o, Color("e23b3b"), 3.0)


func _draw_kiosk(o: Vector2) -> void:
	Iso.shadow(self, o, x0, y0, w, d, 20)
	Iso.prism(self, o, x0, y0, w, d, 0.0, 16.0, color)
	var aw := color2
	draw_colored_polygon(PackedVector2Array([
		Iso.p(x0, y0 + d, 18) - o, Iso.p(x0 + w, y0 + d, 18) - o,
		Iso.p(x0 + w, y0 + d + 0.35, 12) - o, Iso.p(x0, y0 + d + 0.35, 12) - o]), aw)
	Iso.prism(self, o, x0, y0, w, d, 16.0, 4.0, aw.darkened(0.2))


func _draw_umbrella(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	draw_line(base, base - Vector2(0, 16), Color("eeeeee"), 1.5)
	var top := base - Vector2(0, 18)
	draw_colored_polygon(_ellipse(top, 11.0, 5.0), color)
	draw_colored_polygon(_ellipse(top + Vector2(-3, -1), 5.0, 2.5), color.lightened(0.4))


func _draw_pin(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	var bob := sin(_t * 2.5) * 5.0
	var c := base - Vector2(0, 150 + bob)
	draw_colored_polygon(_ellipse(base, 26.0, 11.0), Color(0.2, 0.6, 1.0, 0.25))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 10), c + Vector2(16, 10), c + Vector2(0, 40)]), Color("1d4fb8"))
	draw_circle(c, 26.0, Color("1d4fb8"))
	draw_circle(c, 21.0, Color("3a7bff"))
	draw_string(ThemeDB.fallback_font, c + Vector2(-11, 13), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
