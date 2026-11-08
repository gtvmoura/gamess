extends Node2D
## Carro isométrico. Anda na grade seguindo uma lista de pontos e emite `arrived` ao final.

const Iso := preload("res://scripts/iso.gd")
const Batch := preload("res://scripts/batch.gd")

signal arrived

const COLORS := [
	Color("e03b3b"), Color("f4f4f4"), Color("2b2f3a"), Color("f2c230"), Color("3a7bd9"),
	Color("9aa0aa"), Color("2e9e5b"), Color("e07b2f"), Color("8a4fd0"), Color("2fb8c9"),
	Color("ff7ab0"), Color("b8302f"),
]

var body_color: Color = Color.WHITE
var grid := Vector2.ZERO
var dir := Vector2(1, 0)
var speed := 3.0  # casas por segundo
var path: Array[Vector2] = []
var spot_index := -1
var worker := false
# dados do "cliente" (aparecem ao tocar no carro)
var cname := ""
var job := ""
var hours := 0.0
var spent := 0.0
var status := ""
var angry := false
var hold := false   # parado esperando o carro da frente
var _go := 1.0
var frames := {}   # sprites da Kenney por direção: "px","py","nx","ny" -> [tex, rect]
var kind := 0  # 0 carro, 1 caminhonete, 2 ônibus


func _ready() -> void:
	set_process(false)


func setup(rng: RandomNumberGenerator, start: Vector2) -> void:
	body_color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	var r := rng.randf()
	# 0 sedã, 1 picape, 2 ônibus, 3 hatch, 4 SUV, 5 van, 6 táxi
	if r < 0.04:
		kind = 2
	elif r < 0.36:
		kind = 0
	elif r < 0.56:
		kind = 3
	elif r < 0.72:
		kind = 4
	elif r < 0.82:
		kind = 1
	elif r < 0.9:
		kind = 5
	else:
		kind = 6
	if kind == 2:
		body_color = Color("f2c230") if rng.randf() < 0.5 else Color("3a8fd9")
	elif kind == 6:
		body_color = Color("f5c518")
	elif kind == 5 and rng.randf() < 0.6:
		body_color = Color("eeeeee")
	grid = start
	position = Iso.pg(grid)
	queue_redraw()


func go(points: Array, spd: float = 3.0) -> void:
	path.assign(points)
	speed = spd
	set_process(not path.is_empty())


func _process(delta: float) -> void:
	_go = move_toward(_go, 0.0 if hold else 1.0, delta * (6.0 if hold else 2.5))
	var step := speed * delta * _go
	while step > 0.0 and not path.is_empty():
		var to := path[0] - grid
		var dist := to.length()
		if dist < 0.0001:
			path.remove_at(0)
			continue
		var nd := to / dist
		if not nd.is_equal_approx(dir):
			dir = nd
			queue_redraw()
		if dist <= step:
			grid = path[0]
			step -= dist
			path.remove_at(0)
		else:
			grid += nd * step
			step = 0.0
	position = Iso.pg(grid)
	if path.is_empty():
		set_process(false)
		arrived.emit()


func _draw() -> void:
	if not frames.is_empty():
		var key := "px"
		if absf(dir.x) >= absf(dir.y):
			key = "px" if dir.x >= 0.0 else "nx"
		else:
			key = "py" if dir.y >= 0.0 else "ny"
		var f: Array = frames[key]
		var sh := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			sh.append(Vector2(cos(a) * 15.0 + 3.0, sin(a) * 6.0 + 2.0))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
		draw_texture_rect(f[0], f[1], false)
		return
	var b = Batch.new()
	_draw_body(b)
	b.flush(get_canvas_item())


var _b = null
var _ax := true      # anda ao longo do eixo x?
var _fd := 1.0       # sentido (+1/-1) ao longo do eixo


## Caixa em coordenadas do carro: f = frente/trás, s = lado. Converte para a grade.
func _box(f0: float, f1: float, s0: float, s1: float, z0: float, h: float, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var a := minf(f0 * _fd, f1 * _fd)
	var c := maxf(f0 * _fd, f1 * _fd)
	if _ax:
		Iso.prism(_b, Vector2.ZERO, a, s0, c - a, s1 - s0, z0, h, color, top)
	else:
		Iso.prism(_b, Vector2.ZERO, s0, a, s1 - s0, c - a, z0, h, color, top)


func _draw_body(b) -> void:
	_b = b
	_ax = absf(dir.x) >= absf(dir.y)
	_fd = signf(dir.x if _ax else dir.y)
	if _fd == 0.0:
		_fd = 1.0
	var glass := Color("2a3d55")
	var tire := Color("1e1e22")
	var L := 0.46
	var W := 0.24
	var dims := {1: Vector2(0.52, 0.26), 2: Vector2(0.95, 0.3), 3: Vector2(0.40, 0.23), 4: Vector2(0.50, 0.27), 5: Vector2(0.52, 0.27)}
	if dims.has(kind):
		var dv: Vector2 = dims[kind]
		L = dv.x
		W = dv.y
	var hl := L / 2.0
	var hw := W / 2.0
	# sombra
	if _ax:
		Iso.quad(b, Vector2.ZERO, -hl + 0.06, -hw + 0.07, L, W, 0.0, Color(0, 0, 0, 0.3))
	else:
		Iso.quad(b, Vector2.ZERO, -hw + 0.06, -hl + 0.07, W, L, 0.0, Color(0, 0, 0, 0.3))
	# rodas (aparecem um pouco abaixo da carroceria)
	for fw in [-hl * 0.62, hl * 0.62]:
		_box(fw - 0.05, fw + 0.05, -hw - 0.01, hw + 0.01, 0.0, 4.0, tire)
	var c := body_color
	match kind:
		2:  # ônibus
			_box(-hl, hl, -hw, hw, 2.0, 18.0, c, c.lightened(0.15))
			_band(-hl + 0.06, hl - 0.12, hw, 10.0, 16.0, glass)
			_box(-hl + 0.1, -hl + 0.3, -hw * 0.6, hw * 0.6, 20.0, 2.0, Color("c9ccd2"))
		1:  # picape: cabine na frente, caçamba atrás
			_box(-hl, hl, -hw, hw, 2.0, 7.0, c)
			_box(-0.02, hl * 0.55, -hw * 0.9, hw * 0.9, 9.0, 6.0, glass, c.lightened(0.12))
			_box(-hl + 0.03, -0.05, -hw + 0.03, hw - 0.03, 8.9, 0.2, c.darkened(0.45))
		4:  # SUV
			_box(-hl, hl, -hw, hw, 2.5, 8.5, c)
			_box(-hl * 0.8, hl * 0.45, -hw * 0.88, hw * 0.88, 11.0, 6.0, glass, c.lightened(0.1))
			_box(-hl * 0.7, hl * 0.3, -hw * 0.6, -hw * 0.5, 17.0, 1.0, Color("333333"))
			_box(-hl * 0.7, hl * 0.3, hw * 0.5, hw * 0.6, 17.0, 1.0, Color("333333"))
		5:  # van
			_box(-hl, hl, -hw, hw, 2.0, 15.0, c, c.lightened(0.1))
			_band(hl * 0.35, hl - 0.02, hw, 9.0, 14.0, glass)
			if _fd > 0.0:
				_box(hl - 0.005, hl + 0.002, -hw * 0.8, hw * 0.8, 9.0, 5.0, glass)
		3:  # hatch
			_box(-hl, hl, -hw, hw, 2.0, 6.5, c)
			_box(-hl * 0.95, hl * 0.3, -hw * 0.86, hw * 0.86, 8.5, 5.0, glass, c.lightened(0.12))
		_:  # sedã e táxi
			_box(-hl, hl, -hw, hw, 2.0, 6.5, c)
			_box(-hl * 0.45, hl * 0.35, -hw * 0.86, hw * 0.86, 8.5, 5.0, glass, c.lightened(0.12))
			if kind == 6:
				_box(-0.04, 0.04, -hw * 0.4, hw * 0.4, 13.5, 3.0, Color("ffffff"), Color("e23b3b"))
	# faróis (frente) ou lanternas (trás), só no lado virado para a câmera
	var z := 4.0 if kind != 2 else 6.0
	if _fd > 0.0:
		_lights(hl, hw, z, Color("fff6c0"))
	else:
		_lights(-hl, hw, z, Color("e0302a"))


## Faixa de janelas na lateral visível do carro.
func _band(f0: float, f1: float, hw: float, za: float, zb: float, color: Color) -> void:
	var side := hw + 0.003
	var a := minf(f0 * _fd, f1 * _fd)
	var c := maxf(f0 * _fd, f1 * _fd)
	if _ax:
		_b.draw_colored_polygon(PackedVector2Array([Iso.p(a, side, za), Iso.p(c, side, za), Iso.p(c, side, zb), Iso.p(a, side, zb)]), color)
	else:
		_b.draw_colored_polygon(PackedVector2Array([Iso.p(side, a, za), Iso.p(side, c, za), Iso.p(side, c, zb), Iso.p(side, a, zb)]), color.darkened(0.2))


func _lights(f: float, hw: float, z: float, color: Color) -> void:
	var ff := f * _fd + 0.004
	for s0 in [-hw * 0.85, hw * 0.45]:
		var s1: float = s0 + hw * 0.4
		if _ax:
			_b.draw_colored_polygon(PackedVector2Array([Iso.p(ff, s0, z), Iso.p(ff, s1, z), Iso.p(ff, s1, z + 2.5), Iso.p(ff, s0, z + 2.5)]), color)
		else:
			_b.draw_colored_polygon(PackedVector2Array([Iso.p(s0, ff, z), Iso.p(s1, ff, z), Iso.p(s1, ff, z + 2.5), Iso.p(s0, ff, z + 2.5)]), color)
