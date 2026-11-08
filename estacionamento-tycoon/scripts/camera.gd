extends Camera2D
## Câmera livre estilo jogos de gestão isométricos:
## arrastar com um dedo, pinça com dois (ou roda do mouse), inércia ao soltar e toque para selecionar.

signal tapped(world_pos: Vector2)

const MIN_ZOOM := 0.22
const MAX_ZOOM := 2.2
const TAP_MAX_MOVE := 14.0

var ui = null
var bounds := Rect2(-1600, 0, 3200, 1600)
var touches := {}
var velocity := Vector2.ZERO
var _moved := 0.0
var _tween: Tween


func _ready() -> void:
	position_smoothing_enabled = false
	ignore_rotation = true


func _process(delta: float) -> void:
	if touches.is_empty() and velocity.length() > 4.0:
		position += velocity * delta
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
		_clamp()


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var vs := get_viewport_rect().size
	return position + (screen_pos - vs / 2.0) / zoom.x


func zoom_at(screen_pos: Vector2, factor: float) -> void:
	_stop_tween()
	var before := screen_to_world(screen_pos)
	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	position += before - screen_to_world(screen_pos)
	_clamp()


func focus(world_pos: Vector2, z: float, instant: bool = false) -> void:
	_stop_tween()
	velocity = Vector2.ZERO
	z = clampf(z, MIN_ZOOM, MAX_ZOOM)
	if instant:
		position = world_pos
		zoom = Vector2(z, z)
		_clamp()
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", world_pos, 0.6)
	_tween.tween_property(self, "zoom", Vector2(z, z), 0.6)


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _clamp() -> void:
	var margin := 200.0
	position.x = clampf(position.x, bounds.position.x - margin, bounds.end.x + margin)
	position.y = clampf(position.y, bounds.position.y - margin, bounds.end.y + margin)


func _blocked(pos: Vector2) -> bool:
	return ui != null and ui.blocks_point(pos)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _blocked(t.position):
				return
			touches[t.index] = t.position
			_stop_tween()
			velocity = Vector2.ZERO
			if touches.size() == 1:
				_moved = 0.0
		elif touches.has(t.index):
			touches.erase(t.index)
			if touches.is_empty() and _moved < TAP_MAX_MOVE:
				velocity = Vector2.ZERO
				tapped.emit(screen_to_world(t.position))
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if not touches.has(dr.index):
			return
		if touches.size() == 1:
			var delta_world := dr.relative / zoom.x
			position -= delta_world
			var dt := maxf(get_process_delta_time(), 0.001)
			velocity = velocity.lerp(-delta_world / dt, 0.35)
			_moved += dr.relative.length()
		else:
			var other := Vector2.ZERO
			for k in touches.keys():
				if k != dr.index:
					other = touches[k]
					break
			var old_d: float = (touches[dr.index] as Vector2).distance_to(other)
			var new_d := dr.position.distance_to(other)
			if old_d > 4.0:
				zoom_at((dr.position + other) / 2.0, new_d / old_d)
			velocity = Vector2.ZERO
			_moved += 100.0
		touches[dr.index] = dr.position
		_clamp()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, 1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, 1.0 / 1.12)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.position, mg.factor)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		position += pg.delta * 10.0 / zoom.x
		_clamp()
