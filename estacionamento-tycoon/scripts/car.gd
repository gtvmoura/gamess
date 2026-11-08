extends Node2D
## Carro desenhado por código. Segue uma lista de pontos e emite `arrived` ao final.

signal arrived

const COLORS := [
	Color("d93a3a"), Color("f2f2f2"), Color("2b2f3a"), Color("f2c230"), Color("3a7bd9"),
	Color("8a8f99"), Color("2e9e5b"), Color("e07b2f"), Color("6b3fa0"), Color("b5b9c2"),
]

var body_color: Color = Color.WHITE
var size := Vector2(26, 46)
var speed := 240.0
var path: PackedVector2Array = PackedVector2Array()
var spot_index := -1


func _ready() -> void:
	set_process(false)


func randomize_color(rng: RandomNumberGenerator) -> void:
	body_color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	queue_redraw()


func set_car_size(s: Vector2) -> void:
	size = s
	queue_redraw()


func go(points: PackedVector2Array, spd: float = 240.0) -> void:
	path = points
	speed = spd
	set_process(not path.is_empty())


func _process(delta: float) -> void:
	var step := speed * delta
	while step > 0.0 and not path.is_empty():
		var target: Vector2 = path[0]
		var to := target - position
		var dist := to.length()
		if dist <= step:
			position = target
			step -= dist
			path.remove_at(0)
		else:
			position += to / dist * step
			rotation = lerp_angle(rotation, to.angle() + PI / 2.0, minf(1.0, delta * 14.0))
			step = 0.0
	if path.is_empty():
		set_process(false)
		arrived.emit()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# sombra
	draw_rect(Rect2(-w / 2.0 + 2.0, -h / 2.0 + 3.0, w, h), Color(0, 0, 0, 0.25))
	# carroceria
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h), body_color)
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h), body_color.darkened(0.35), false, 1.5)
	# para-brisa (frente = topo) e vidro traseiro
	var glass := Color(0.15, 0.22, 0.32)
	draw_rect(Rect2(-w * 0.38, -h * 0.30, w * 0.76, h * 0.18), glass)
	draw_rect(Rect2(-w * 0.36, h * 0.22, w * 0.72, h * 0.12), glass)
	# teto
	draw_rect(Rect2(-w * 0.36, -h * 0.12, w * 0.72, h * 0.34), body_color.lightened(0.12))
	# faróis e lanternas
	draw_rect(Rect2(-w * 0.45, -h / 2.0, w * 0.22, h * 0.06), Color(1, 0.97, 0.75))
	draw_rect(Rect2(w * 0.23, -h / 2.0, w * 0.22, h * 0.06), Color(1, 0.97, 0.75))
	draw_rect(Rect2(-w * 0.45, h / 2.0 - h * 0.05, w * 0.2, h * 0.05), Color(0.85, 0.1, 0.1))
	draw_rect(Rect2(w * 0.25, h / 2.0 - h * 0.05, w * 0.2, h * 0.05), Color(0.85, 0.1, 0.1))
