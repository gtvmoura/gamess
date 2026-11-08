extends Node2D
## Objeto estático do mapa (prédio, casa, árvore, poste...). Desenhado por código em isométrico.

const Iso := preload("res://scripts/iso.gd")
const Batch := preload("res://scripts/batch.gd")
const FLOOR_H := 9.5

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
var open := 0.0  # cancela: 0 fechada, 1 aberta
var _c = null   # alvo do desenho (o próprio nó ou um Batch)


## Prepara o objeto. O nó fica na quina da frente (para o y-sort funcionar).
func setup(k: String, gx: float, gy: float, gw: float = 0.0, gd: float = 0.0) -> void:
	kind = k
	x0 = gx
	y0 = gy
	w = gw
	d = gd
	position = Iso.p(x0 + w, y0 + d)
	set_process(kind == "pin")
	_c = self


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if kind == "pin":
		draw_into(self, position)
		return
	var b = Batch.new()
	draw_into(b, position)
	b.flush(get_canvas_item())


## Desenha o objeto em `target` (CanvasItem ou Batch), relativo à origem `o`.
func draw_into(target, o: Vector2) -> void:
	_c = target
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
		"gate":
			_draw_gate(o)
		"fence":
			_draw_fence(o)
		"svc_wash":
			_draw_wash(o)
		"svc_cafe":
			_draw_cafe(o)
		"svc_ev":
			_draw_ev(o)
		"svc_tire":
			_draw_tire(o)
		"kiosk":
			_draw_kiosk(o)
		"umbrella":
			_draw_umbrella(o)
		"pin":
			_draw_pin(o)


func _draw_house(o: Vector2) -> void:
	var wall_h := FLOOR_H * 1.6 * floors
	Iso.shadow(_c, o, x0, y0, w, d, wall_h)
	Iso.prism(_c, o, x0, y0, w, d, 0.0, wall_h, color)
	# porta e janelas
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	Iso.windows(_c, o, x0, y0, w, d, 2.0, floors, FLOOR_H * 1.6, "x", rng, lit_chance, Color("3b5068"))
	var door := PackedVector2Array([
		Iso.p(x0 + w * 0.3, y0 + d, 0) - o, Iso.p(x0 + w * 0.48, y0 + d, 0) - o,
		Iso.p(x0 + w * 0.48, y0 + d, 12) - o, Iso.p(x0 + w * 0.3, y0 + d, 12) - o])
	_c.draw_colored_polygon(door, Color("6b4429"))
	# telhado de duas águas (cumeeira ao longo de x)
	var z1 := wall_h
	var rh := 14.0
	var ym := y0 + d * 0.5
	var r1 := Iso.p(x0 - 0.08, ym, z1 + rh) - o
	var r2 := Iso.p(x0 + w + 0.08, ym, z1 + rh) - o
	var back := PackedVector2Array([Iso.p(x0 - 0.08, y0 - 0.08, z1) - o, Iso.p(x0 + w + 0.08, y0 - 0.08, z1) - o, r2, r1])
	var front := PackedVector2Array([Iso.p(x0 - 0.08, y0 + d + 0.08, z1) - o, Iso.p(x0 + w + 0.08, y0 + d + 0.08, z1) - o, r2, r1])
	_c.draw_colored_polygon(back, color2.darkened(0.15))
	_c.draw_colored_polygon(front, color2)
	var gable := PackedVector2Array([Iso.p(x0 + w, y0, z1) - o, Iso.p(x0 + w, y0 + d, z1) - o, Iso.p(x0 + w, ym, z1 + rh) - o])
	_c.draw_colored_polygon(gable, color.darkened(0.3))
	_c.draw_line(r1, r2, color2.lightened(0.25), 2.0)


func _draw_building(o: Vector2, tower: bool) -> void:
	var h := FLOOR_H * floors + 6.0
	Iso.shadow(_c, o, x0, y0, w, d, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# térreo com toldo/loja
	Iso.prism(_c, o, x0, y0, w, d, 0.0, 12.0, color.darkened(0.15))
	Iso.prism(_c, o, x0, y0, w, d, 12.0, h - 12.0, color)
	var glass := Color("8fc4e8") if tower else Color("3b5068")
	Iso.windows(_c, o, x0, y0, w, d, 12.0, floors - 1, FLOOR_H, "y", rng, lit_chance, glass)
	Iso.windows(_c, o, x0, y0, w, d, 12.0, floors - 1, FLOOR_H, "x", rng, lit_chance, glass)
	# vitrine e toldo da loja
	var aw := Color.from_hsv(rng.randf(), 0.7, 0.85)
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + 0.15, y0 + d, 2) - o, Iso.p(x0 + w - 0.15, y0 + d, 2) - o,
		Iso.p(x0 + w - 0.15, y0 + d, 9) - o, Iso.p(x0 + 0.15, y0 + d, 9) - o]), Color("a8d8f0"))
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + 0.1, y0 + d, 12) - o, Iso.p(x0 + w - 0.1, y0 + d, 12) - o,
		Iso.p(x0 + w - 0.1, y0 + d + 0.3, 8) - o, Iso.p(x0 + 0.1, y0 + d + 0.3, 8) - o]), aw)
	# topo: platibanda e equipamentos
	Iso.prism(_c, o, x0 + 0.1, y0 + 0.1, w - 0.2, d - 0.2, h, 0.0, color.darkened(0.45))
	if tower:
		Iso.prism(_c, o, x0 + w * 0.3, y0 + d * 0.3, w * 0.4, d * 0.4, h, 10.0, color.lightened(0.1))
		_c.draw_line(Iso.p(x0 + w * 0.5, y0 + d * 0.5, h + 10) - o, Iso.p(x0 + w * 0.5, y0 + d * 0.5, h + 34) - o, Color("dddddd"), 2.0)
		_c.draw_circle(Iso.p(x0 + w * 0.5, y0 + d * 0.5, h + 34) - o, 2.5, Color("ff3b3b"))
	else:
		Iso.prism(_c, o, x0 + w * 0.6, y0 + d * 0.2, 0.5, 0.4, h, 6.0, Color("b8b8b8"))


func _draw_warehouse(o: Vector2) -> void:
	var h := 22.0 * floors
	Iso.shadow(_c, o, x0, y0, w, d, h)
	Iso.prism(_c, o, x0, y0, w, d, 0.0, h, color, Color("9aa3ad"))
	for i in 4:
		var t := (i + 0.5) / 4.0
		_c.draw_line(Iso.p(x0 + w * t, y0, h) - o, Iso.p(x0 + w * t, y0 + d, h) - o, Color("7d8590"), 2.0)
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + w * 0.3, y0 + d, 0) - o, Iso.p(x0 + w * 0.7, y0 + d, 0) - o,
		Iso.p(x0 + w * 0.7, y0 + d, h * 0.6) - o, Iso.p(x0 + w * 0.3, y0 + d, h * 0.6) - o]), Color("5c6670"))


func _draw_tree(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	var s := 0.7 + size_f
	_c.draw_colored_polygon(_ellipse(base + Vector2(6, 2), 13.0 * s, 5.0 * s), Color(0, 0, 0, 0.22))
	_c.draw_line(base, base - Vector2(0, 12 * s), Color("6b4429"), 3.0)
	var c := color
	_c.draw_circle(base - Vector2(0, 20 * s), 10.0 * s, c.darkened(0.25))
	_c.draw_circle(base - Vector2(-3, 23 * s), 8.0 * s, c)
	_c.draw_circle(base - Vector2(2, 27 * s), 5.5 * s, c.lightened(0.2))


func _draw_palm(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	var s := 0.8 + size_f
	_c.draw_colored_polygon(_ellipse(base + Vector2(8, 2), 12.0 * s, 4.0 * s), Color(0, 0, 0, 0.2))
	var top := base + Vector2(4 * s, -34 * s)
	_c.draw_line(base, base + Vector2(2 * s, -18 * s), Color("8a6a3e"), 3.0)
	_c.draw_line(base + Vector2(2 * s, -18 * s), top, Color("8a6a3e"), 3.0)
	var leaf := color
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var tip := top + Vector2(cos(a) * 16 * s, sin(a) * 7 * s + 6 * s)
		var mid := top + Vector2(cos(a) * 9 * s, sin(a) * 4 * s - 3 * s)
		_c.draw_colored_polygon(PackedVector2Array([top, mid + Vector2(0, -2), tip, mid + Vector2(0, 2)]), leaf if i % 2 == 0 else leaf.darkened(0.2))
	_c.draw_circle(top, 2.5 * s, Color("6b4f2a"))


func _draw_lamp(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	_c.draw_line(base, base - Vector2(0, 34), Color("3a3d44"), 2.0)
	_c.draw_line(base - Vector2(0, 34), base - Vector2(-7, 36), Color("3a3d44"), 2.0)
	if lit_chance > 0.3:
		_c.draw_circle(base - Vector2(-7, 34), 9.0, Color(1, 0.9, 0.5, 0.25))
	_c.draw_circle(base - Vector2(-7, 35), 2.5, Color("fff2b0"))


func _draw_canopy(o: Vector2) -> void:
	var h := 26.0
	for t in [0.0, 0.33, 0.66, 1.0]:
		var px: float = x0 + w * t
		_c.draw_line(Iso.p(px, y0 + d, 0) - o, Iso.p(px, y0 + d, h) - o, Color("c9ccd2"), 2.0)
	var col := Color("2f5fb3")
	Iso.prism(_c, o, x0, y0, w, d, h, 2.0, col.darkened(0.2), col)
	var cells := int(w * 2.0)
	for i in cells:
		var a := x0 + w * (i + 0.1) / cells
		var b := x0 + w * (i + 0.9) / cells
		Iso.quad(_c, o, a, y0 + 0.1, b - a, d - 0.2, h + 2.1, Color("4a86e8"))


func _draw_booth(o: Vector2) -> void:
	Iso.shadow(_c, o, x0, y0, w, d, 20)
	Iso.prism(_c, o, x0, y0, w, d, 0.0, 18.0, Color("f2f2f2"))
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + w, y0 + 0.1, 8) - o, Iso.p(x0 + w, y0 + d - 0.1, 8) - o,
		Iso.p(x0 + w, y0 + d - 0.1, 15) - o, Iso.p(x0 + w, y0 + 0.1, 15) - o]), Color("7fc2ea"))
	Iso.prism(_c, o, x0 - 0.05, y0 - 0.05, w + 0.1, d + 0.1, 18.0, 3.0, Color("f2c230"))


func _draw_gate(o: Vector2) -> void:
	# poste com a cancela listrada que sobe (open = 0..1)
	var base := Iso.p(x0, y0) - o
	Iso.prism(_c, o, x0 - 0.06, y0 - 0.06, 0.12, 0.12, 0.0, 12.0, Color("f2c230"))
	var pivot := base - Vector2(0, 11)
	var along := (Iso.p(x0 + w, y0) - Iso.p(x0, y0)).normalized()
	var length := (Iso.p(x0 + w, y0) - Iso.p(x0, y0)).length()
	var ang := open * PI * 0.45
	var dir := along * cos(ang) + Vector2(0, -1) * sin(ang)
	var segs := 5
	for i in segs:
		var a := pivot + dir * length * (float(i) / segs)
		var b := pivot + dir * length * (float(i + 1) / segs)
		_c.draw_line(a, b, Color("e23b3b") if i % 2 == 0 else Color("f4f4f4"), 3.0)


func _draw_fence(o: Vector2) -> void:
	var a := Vector2(x0, y0)
	var b := Vector2(x0 + w, y0 + d)
	var metal := Color("3b3f47")
	var light := Color("8a919c")
	var n := maxi(1, int(round(a.distance_to(b) / 0.33)))
	for i in n + 1:
		var g := a.lerp(b, float(i) / n)
		_c.draw_line(Iso.pg(g, 0.0) - o, Iso.pg(g, 13.0) - o, metal, 2.0)
	for zr in [5.0, 12.0]:
		_c.draw_line(Iso.pg(a, zr) - o, Iso.pg(b, zr) - o, light, 2.0)
	# base de concreto
	_c.draw_line(Iso.pg(a, 0.5) - o, Iso.pg(b, 0.5) - o, Color("b8b2a4"), 3.0)


func _pad(o: Vector2) -> void:
	Iso.quad(_c, o, x0 - 0.1, y0 - 0.1, w + 0.2, d + 0.2, 0.0, Color("b8b2a4"))


func _sign(o: Vector2, text_color: Color, h: float) -> void:
	# placa no topo, na face da frente
	Iso.prism(_c, o, x0 + w * 0.2, y0 + d - 0.12, w * 0.6, 0.1, h, 9.0, text_color, text_color.lightened(0.2))


func _draw_wash(o: Vector2) -> void:
	_pad(o)
	var h := 24.0
	Iso.shadow(_c, o, x0, y0, w, d, h)
	# túnel de lavagem: paredes e teto, aberto na frente
	Iso.prism(_c, o, x0, y0, 0.25, d, 0.0, h, Color("e8f4fb"))
	Iso.prism(_c, o, x0 + 0.25, y0, w - 0.5, 0.2, 0.0, h, Color("cfe6f2"))
	# rolos azuis dentro
	for i in 2:
		var gx := x0 + 0.7 + i * 0.9
		Iso.prism(_c, o, gx, y0 + 0.3, 0.2, d - 0.5, 2.0, 16.0, Color("2f7fe0"), Color("5aa0ff"))
	Iso.prism(_c, o, x0 + w - 0.25, y0, 0.25, d, 0.0, h, Color("e8f4fb"))
	Iso.prism(_c, o, x0, y0, w, d, h, 3.0, Color("2f9be0"), Color("49b4f5"))
	# gotas
	for i in 6:
		_c.draw_circle(Iso.p(x0 + 0.5 + i * 0.3, y0 + d + 0.15, 4.0 + (i % 3) * 3.0) - o, 1.6, Color("7fd4ff"))
	_sign(o, Color("1f6fd0"), h + 3.0)


func _draw_cafe(o: Vector2) -> void:
	_pad(o)
	var bw := minf(w, 1.2)
	Iso.shadow(_c, o, x0, y0, bw, d * 0.7, 20)
	Iso.prism(_c, o, x0, y0, bw, d * 0.7, 0.0, 18.0, Color("f2e6d0"))
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0, y0 + d * 0.7, 19) - o, Iso.p(x0 + bw, y0 + d * 0.7, 19) - o,
		Iso.p(x0 + bw, y0 + d * 0.7 + 0.35, 12) - o, Iso.p(x0, y0 + d * 0.7 + 0.35, 12) - o]), Color("8a4b2a"))
	Iso.prism(_c, o, x0, y0, bw, d * 0.7, 18.0, 3.0, Color("6b3a20"))
	# mesinhas com guarda-sol
	var n := mini(1 + floors / 3, 3)
	for i in n:
		var tx := x0 + bw + 0.3 + (i % 2) * 0.35
		var ty := y0 + 0.3 + i * 0.35
		var base := Iso.p(tx, ty) - o
		_c.draw_line(base, base - Vector2(0, 14), Color("dddddd"), 1.5)
		_c.draw_colored_polygon(_ellipse(base - Vector2(0, 15), 9.0, 4.0), Color("e23b3b") if i % 2 == 0 else Color("f2f2f2"))


func _draw_ev(o: Vector2) -> void:
	_pad(o)
	Iso.quad(_c, o, x0, y0, w, d, 0.05, Color("2e9e5b"))
	var n := mini(2 + floors / 2, 6)
	for i in n:
		var px := x0 + 0.2 + (w - 0.4) * (float(i) / maxf(1.0, n - 1))
		Iso.prism(_c, o, px - 0.08, y0 + 0.15, 0.16, 0.12, 0.0, 16.0, Color("f4f4f4"), Color("2fd47a"))
		_c.draw_colored_polygon(PackedVector2Array([
			Iso.p(px - 0.06, y0 + 0.271, 9) - o, Iso.p(px + 0.06, y0 + 0.271, 9) - o,
			Iso.p(px + 0.06, y0 + 0.271, 13) - o, Iso.p(px - 0.06, y0 + 0.271, 13) - o]), Color("1fbf6a"))
	# raio pintado no chão
	var c := Iso.p(x0 + w * 0.5, y0 + d * 0.65) - o
	var white := Color("f2f2f2")
	_c.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(6, -10), c + Vector2(-1, 1)]), white)
	_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -1), c + Vector2(5, -1), c + Vector2(4, 1), c + Vector2(-5, 1)]), white)
	_c.draw_colored_polygon(PackedVector2Array([c + Vector2(1, -1), c + Vector2(4, -1), c + Vector2(-5, 10)]), white)


func _draw_tire(o: Vector2) -> void:
	_pad(o)
	var h := 20.0
	Iso.shadow(_c, o, x0, y0, w * 0.75, d, h)
	Iso.prism(_c, o, x0, y0, w * 0.75, d, 0.0, h, Color("8a8f99"), Color("a3a8b2"))
	# porta de enrolar e faixa laranja
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0 + 0.2, y0 + d, 0) - o, Iso.p(x0 + w * 0.6, y0 + d, 0) - o,
		Iso.p(x0 + w * 0.6, y0 + d, 13) - o, Iso.p(x0 + 0.2, y0 + d, 13) - o]), Color("4a4f58"))
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0, y0 + d, 15) - o, Iso.p(x0 + w * 0.75, y0 + d, 15) - o,
		Iso.p(x0 + w * 0.75, y0 + d, 18) - o, Iso.p(x0, y0 + d, 18) - o]), Color("f28c1a"))
	# pilha de pneus
	var base := Iso.p(x0 + w * 0.88, y0 + d * 0.6) - o
	for i in mini(2 + floors / 3, 5):
		_c.draw_colored_polygon(_ellipse(base - Vector2(0, i * 4.0), 8.0, 3.5), Color("1e1e22"))
		_c.draw_colored_polygon(_ellipse(base - Vector2(0, i * 4.0 + 0.5), 3.0, 1.3), Color("4a4f58"))


func _draw_kiosk(o: Vector2) -> void:
	Iso.shadow(_c, o, x0, y0, w, d, 20)
	Iso.prism(_c, o, x0, y0, w, d, 0.0, 16.0, color)
	var aw := color2
	_c.draw_colored_polygon(PackedVector2Array([
		Iso.p(x0, y0 + d, 18) - o, Iso.p(x0 + w, y0 + d, 18) - o,
		Iso.p(x0 + w, y0 + d + 0.35, 12) - o, Iso.p(x0, y0 + d + 0.35, 12) - o]), aw)
	Iso.prism(_c, o, x0, y0, w, d, 16.0, 4.0, aw.darkened(0.2))


func _draw_umbrella(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	_c.draw_line(base, base - Vector2(0, 16), Color("eeeeee"), 1.5)
	var top := base - Vector2(0, 18)
	_c.draw_colored_polygon(_ellipse(top, 11.0, 5.0), color)
	_c.draw_colored_polygon(_ellipse(top + Vector2(-3, -1), 5.0, 2.5), color.lightened(0.4))


func _draw_pin(o: Vector2) -> void:
	var base := Iso.p(x0, y0) - o
	var bob := sin(_t * 2.5) * 5.0
	var c := base - Vector2(0, 150 + bob)
	_c.draw_colored_polygon(_ellipse(base, 26.0, 11.0), Color(0.2, 0.6, 1.0, 0.25))
	_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 10), c + Vector2(16, 10), c + Vector2(0, 40)]), Color("1d4fb8"))
	_c.draw_circle(c, 26.0, Color("1d4fb8"))
	_c.draw_circle(c, 21.0, Color("3a7bff"))
	_c.draw_string(ThemeDB.fallback_font, c + Vector2(-11, 13), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
