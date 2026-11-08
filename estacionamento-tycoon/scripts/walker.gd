extends Node2D
## Pedestre andando pela calçada (vai e volta entre dois pontos).

const Iso := preload("res://scripts/iso.gd")

var a := Vector2.ZERO
var b := Vector2.ZERO
var t := 0.0
var speed := 0.4
var shirt := Color.RED
var skin := Color("e0b48a")
var _forward := true
var _step := 0.0
var _leg_up := false


func setup(rng: RandomNumberGenerator, p0: Vector2, p1: Vector2) -> void:
	a = p0
	b = p1
	t = rng.randf()
	speed = rng.randf_range(0.25, 0.5) / maxf(0.5, p0.distance_to(p1))
	shirt = Color.from_hsv(rng.randf(), 0.65, 0.9)
	skin = [Color("f1c9a5"), Color("e0ac7e"), Color("a86f45"), Color("6b4429")][rng.randi_range(0, 3)]
	_forward = rng.randf() < 0.5


func _process(delta: float) -> void:
	t += (speed if _forward else -speed) * delta
	if t >= 1.0:
		t = 1.0
		_forward = false
	elif t <= 0.0:
		t = 0.0
		_forward = true
	_step += delta * 8.0
	position = Iso.pg(a.lerp(b, t))
	var up := sin(_step) > 0.0
	if up != _leg_up:
		_leg_up = up
		queue_redraw()


func _draw() -> void:
	var leg := 1.5 if _leg_up else -1.5
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, 1.5), Vector2(-3, 1.5)]), Color(0, 0, 0, 0.25))
	draw_line(Vector2(-1, 0), Vector2(-1 + leg * 0.5, -5), Color("2b3550"), 1.5)
	draw_line(Vector2(1, 0), Vector2(1 - leg * 0.5, -5), Color("2b3550"), 1.5)
	draw_rect(Rect2(-2.5, -11, 5, 6), shirt)
	draw_circle(Vector2(0, -13), 2.2, skin)
