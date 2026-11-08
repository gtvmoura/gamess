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
var kind := 0  # 0 carro, 1 caminhonete, 2 ônibus


func _ready() -> void:
	set_process(false)


func setup(rng: RandomNumberGenerator, start: Vector2) -> void:
	body_color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	var r := rng.randf()
	kind = 2 if r < 0.04 else (1 if r < 0.2 else 0)
	if kind == 2:
		body_color = Color("f2c230") if rng.randf() < 0.5 else Color("3a8fd9")
	grid = start
	position = Iso.pg(grid)
	queue_redraw()


func go(points: Array, spd: float = 3.0) -> void:
	path.assign(points)
	speed = spd
	set_process(not path.is_empty())


func _process(delta: float) -> void:
	var step := speed * delta
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
	var b = Batch.new()
	_draw_body(b)
	b.flush(get_canvas_item())


func _draw_body(b) -> void:
	var length := 0.46
	var width := 0.24
	var body_h := 7.0
	var cab_h := 5.0
	if kind == 1:
		length = 0.52
		width = 0.26
		body_h = 9.0
	elif kind == 2:
		length = 0.95
		width = 0.3
		body_h = 16.0
		cab_h = 0.0
	var along_x := absf(dir.x) >= absf(dir.y)
	var lx := length if along_x else width
	var ly := width if along_x else length
	var o := Vector2.ZERO
	Iso.quad(b, o, -lx / 2.0 + 0.06, -ly / 2.0 + 0.06, lx, ly, 0.0, Color(0, 0, 0, 0.3))
	Iso.prism(b, o, -lx / 2.0, -ly / 2.0, lx, ly, 2.0, body_h, body_color)
	if kind == 2:
		# janelas do ônibus
		var glass := Color("26384f")
		for i in 5:
			var t0 := 0.08 + i * 0.18
			if along_x:
				_face_quad(b, -lx / 2.0 + lx * t0, ly / 2.0, -lx / 2.0 + lx * (t0 + 0.12), ly / 2.0, 9.0, 15.0, glass)
			else:
				_face_quad(b, lx / 2.0, -ly / 2.0 + ly * t0, lx / 2.0, -ly / 2.0 + ly * (t0 + 0.12), 9.0, 15.0, glass.darkened(0.2))
		return
	# cabine: deslocada para trás em relação ao sentido
	var cl := 0.55
	var cx := -lx / 2.0 + lx * 0.12
	var cy := -ly / 2.0 + ly * 0.12
	var cw := lx * 0.76
	var cd := ly * 0.76
	if along_x:
		cw = lx * cl
		cx = -cw / 2.0 - dir.x * lx * 0.1
	else:
		cd = ly * cl
		cy = -cd / 2.0 - dir.y * ly * 0.1
	if kind == 1:
		# caminhonete: cabine na frente, caçamba atrás
		if along_x:
			cw = lx * 0.4
			cx = (lx * 0.1 if dir.x > 0 else -lx * 0.5)
		else:
			cd = ly * 0.4
			cy = (ly * 0.1 if dir.y > 0 else -ly * 0.5)
	Iso.prism(b, o, cx, cy, cw, cd, 2.0 + body_h, cab_h, Color("26384f"), body_color.lightened(0.1))


func _face_quad(b, ax: float, ay: float, bx: float, by: float, za: float, zb: float, c: Color) -> void:
	b.draw_colored_polygon(PackedVector2Array([Iso.p(ax, ay, za), Iso.p(bx, by, za), Iso.p(bx, by, zb), Iso.p(ax, ay, zb)]), c)
