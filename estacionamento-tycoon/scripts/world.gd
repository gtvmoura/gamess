extends Node2D
## Mundo do jogo: cidade ao fundo, rua com trânsito e o estacionamento com carros.

const CarScript := preload("res://scripts/car.gd")

const ROAD_TOP := 410.0
const LANE_RIGHT_Y := 432.0   # carros indo para a direita
const LANE_LEFT_Y := 472.0    # carros indo para a esquerda (os que entram)
const ROAD_BOTTOM := 494.0
const LOT := Rect2(30, 520, 660, 600)
const LEFT_LANE_X := 62.0
const RIGHT_LANE_X := 658.0
const SPOTS_X0 := 96.0
const SPOTS_X1 := 624.0
const ENTRY_X := 420.0
const EXIT_X := 300.0
const OFFSCREEN := 140.0
const STAY_SECONDS := 12.0  # igual a Game.AVG_STAY_SECONDS

var rng := RandomNumberGenerator.new()
var spot_pos: Array[Vector2] = []
var aisle_y: Array[float] = []   # y do corredor de cada vaga
var spot_size := Vector2(30, 54)
var spot_cars: Array = []        # Car ou null por vaga
var arrival_acc := 0.0
var traffic_acc := 0.0
var _layout_spots := -1
var _city_key := ""
var _buildings: Array = []
var _trees: Array = []
var _time := 0.0

@onready var cars_layer := Node2D.new()
@onready var fx_layer := Node2D.new()


func _ready() -> void:
	rng.randomize()
	add_child(cars_layer)
	add_child(fx_layer)
	_relayout()
	_rebuild_city()
	Game.changed.connect(_on_game_changed)


func _on_game_changed() -> void:
	if Game.spots() != _layout_spots:
		_relayout()
	_rebuild_city()


# ---------------------------------------------------------------- Layout

func _relayout() -> void:
	var n := Game.spots()
	_layout_spots = n
	var width := SPOTS_X1 - SPOTS_X0
	var height := LOT.size.y - 30.0
	var cols := 4
	var sw := 0.0
	var sh := 0.0
	var aisle := 0.0
	while true:
		sw = width / cols
		sh = sw * 1.75
		aisle = maxf(sw * 1.1, 34.0)
		var rows := ceili(float(n) / cols)
		if rows * (aisle + sh) <= height or cols >= 40:
			break
		cols += 1
	spot_size = Vector2(sw, sh)
	spot_pos.clear()
	aisle_y.clear()
	for i in n:
		var r := i / cols
		var c := i % cols
		var top := LOT.position.y + 10.0 + r * (aisle + sh)
		aisle_y.append(top + aisle / 2.0)
		spot_pos.append(Vector2(SPOTS_X0 + (c + 0.5) * sw, top + aisle + sh / 2.0))
	spot_cars.resize(n)
	var car_size := _car_size()
	for i in n:
		var car = spot_cars[i]
		if car != null and is_instance_valid(car):
			car.set_car_size(car_size)
			if not car.is_processing():
				car.position = spot_pos[i]
	queue_redraw()


func _car_size() -> Vector2:
	return Vector2(minf(spot_size.x * 0.72, 26.0), minf(spot_size.y * 0.8, 46.0))


# ---------------------------------------------------------------- Simulação

func _process(delta: float) -> void:
	_time += delta
	# Carros que entram no estacionamento
	arrival_acc = minf(arrival_acc + Game.arrivals_per_sec() * delta, 4.0)
	while arrival_acc >= 1.0:
		arrival_acc -= 1.0
		var idx := _free_spot()
		if idx == -1:
			Game.lost_customers += 1
		else:
			_spawn_arrival(idx)
	# Trânsito decorativo (carros que só passam)
	var passing := minf(Game.passing_per_sec() * (1.0 - Game.enter_chance()), 1.6)
	traffic_acc += passing * delta
	while traffic_acc >= 1.0:
		traffic_acc -= 1.0
		_spawn_traffic()
	Game.occupied = _count_occupied()
	if fmod(_time, 1.0) < delta:
		queue_redraw()  # piscar das luzes/sinais


func _count_occupied() -> int:
	var n := 0
	for c in spot_cars:
		if c != null:
			n += 1
	return n


func _free_spot() -> int:
	var free: Array[int] = []
	for i in spot_cars.size():
		if spot_cars[i] == null:
			free.append(i)
	if free.is_empty():
		return -1
	return free[rng.randi_range(0, free.size() - 1)]


func _new_car():
	var car = CarScript.new()
	cars_layer.add_child(car)
	car.randomize_color(rng)
	return car


func _spawn_traffic() -> void:
	var car = _new_car()
	var w := get_viewport_rect().size.x
	var points := PackedVector2Array()
	if rng.randf() < 0.5:
		car.position = Vector2(-OFFSCREEN, LANE_RIGHT_Y)
		points.append(Vector2(w + OFFSCREEN, LANE_RIGHT_Y))
	else:
		car.position = Vector2(w + OFFSCREEN, LANE_LEFT_Y)
		points.append(Vector2(-OFFSCREEN, LANE_LEFT_Y))
	car.rotation = (points[0] - car.position).angle() + PI / 2.0
	car.arrived.connect(car.queue_free)
	car.go(points, rng.randf_range(200.0, 300.0))


func _spawn_arrival(idx: int) -> void:
	var car = _new_car()
	car.spot_index = idx
	spot_cars[idx] = car
	car.set_car_size(_car_size())
	var w := get_viewport_rect().size.x
	car.position = Vector2(w + OFFSCREEN, LANE_LEFT_Y)
	car.rotation = -PI / 2.0
	var p := spot_pos[idx]
	var ay := aisle_y[idx]
	var first_aisle := aisle_y[0]
	var points := PackedVector2Array([
		Vector2(ENTRY_X, LANE_LEFT_Y),
		Vector2(ENTRY_X, first_aisle),
	])
	if not is_equal_approx(ay, first_aisle):
		points.append(Vector2(LEFT_LANE_X, first_aisle))
		points.append(Vector2(LEFT_LANE_X, ay))
	points.append(Vector2(p.x, ay))
	points.append(p)
	car.arrived.connect(_on_car_parked.bind(car), CONNECT_ONE_SHOT)
	car.go(points, 260.0)


func _on_car_parked(car) -> void:
	var idx: int = car.spot_index
	if idx >= spot_pos.size():
		return
	car.position = spot_pos[idx]
	car.rotation = PI
	Game.car_parked()
	var stay := rng.randf_range(STAY_SECONDS - 4.0, STAY_SECONDS + 4.0)
	get_tree().create_timer(stay).timeout.connect(_car_leave.bind(car))


func _car_leave(car) -> void:
	if not is_instance_valid(car):
		return
	var idx: int = car.spot_index
	var hours := rng.randi_range(1, 3)
	var paid := Game.car_paid(Game.price() * hours)
	_floating_text("+" + Game.money_str(paid), car.position + Vector2(0, -20))
	var w := get_viewport_rect().size.x
	var ay := aisle_y[mini(idx, aisle_y.size() - 1)]
	var first_aisle := aisle_y[0]
	var points := PackedVector2Array([Vector2(car.position.x, ay)])
	if not is_equal_approx(ay, first_aisle):
		points.append(Vector2(RIGHT_LANE_X, ay))
		points.append(Vector2(RIGHT_LANE_X, first_aisle))
	points.append(Vector2(EXIT_X, first_aisle))
	points.append(Vector2(EXIT_X, LANE_RIGHT_Y))
	points.append(Vector2(w + OFFSCREEN, LANE_RIGHT_Y))
	if idx < spot_cars.size() and spot_cars[idx] == car:
		spot_cars[idx] = null
	car.spot_index = -1
	car.arrived.connect(car.queue_free, CONNECT_ONE_SHOT)
	car.go(points, 260.0)


func _floating_text(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("7dff7a"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.position = pos - Vector2(40, 10)
	fx_layer.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", pos.y - 70.0, 1.2)
	tw.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------------- Cidade

func _rebuild_city() -> void:
	var key := "%d-%d-%d" % [int(Game.lvl.city), Game.districts_unlocked, Game.phase_index()]
	if key == _city_key:
		return
	_city_key = key
	var r := RandomNumberGenerator.new()
	r.seed = 2026
	_buildings.clear()
	var phase := Game.phase_index()
	var growth := clampf(float(Game.lvl.city) / 20.0 + Game.districts_unlocked * 0.05, 0.0, 1.0)
	var x := -40.0
	while x < 1400.0:
		var kind := 0  # 0 casa, 1 prédio, 2 arranha-céu
		var roll := r.randf()
		if phase >= 2 and roll < 0.25 + growth * 0.3:
			kind = 2
		elif phase >= 1 and roll < 0.55 + growth * 0.2:
			kind = 1
		elif phase == 0 and roll < growth * 1.5:
			kind = 1
		var bw := 0.0
		var bh := 0.0
		match kind:
			0:
				bw = r.randf_range(50, 70)
				bh = r.randf_range(40, 60)
			1:
				bw = r.randf_range(55, 85)
				bh = r.randf_range(90, 160) * (0.8 + growth * 0.4)
			2:
				bw = r.randf_range(50, 75)
				bh = r.randf_range(180, 300) * (0.8 + growth * 0.4)
		var col := Color.from_hsv(r.randf_range(0.0, 1.0), r.randf_range(0.1, 0.3), r.randf_range(0.65, 0.9))
		if kind == 2:
			col = Color.from_hsv(r.randf_range(0.55, 0.65), 0.35, r.randf_range(0.45, 0.7))
		_buildings.append({"x": x, "w": bw, "h": bh, "kind": kind, "color": col, "seed": r.randi()})
		x += bw + r.randf_range(4, 18)
	_trees.clear()
	for i in 14:
		_trees.append(Vector2(r.randf_range(0, 1400), r.randf_range(372, 400)))
	queue_redraw()


func _draw() -> void:
	var vw := get_viewport_rect().size.x
	var night := Game.phase_index() >= 2
	# céu e grama
	var sky_top := Color("4f8fd8") if not night else Color("1b2350")
	var sky_bottom := Color("a9d4f5") if not night else Color("e08a5a")
	for i in 20:
		var t := i / 20.0
		draw_rect(Rect2(-400, -400 + t * 805.0, vw + 800, 41), sky_top.lerp(sky_bottom, t))
	draw_rect(Rect2(-400, 360, vw + 800, 2000), Color("5c9a45"))
	# montanha
	draw_colored_polygon(PackedVector2Array([Vector2(-100, 400), Vector2(180, 250), Vector2(420, 400)]), Color("6d8c6a"))
	draw_colored_polygon(PackedVector2Array([Vector2(250, 400), Vector2(560, 230), Vector2(900, 400)]), Color("5e7d5b"))
	# prédios
	for b in _buildings:
		_draw_building(b, night)
	for t in _trees:
		_draw_tree(t, 16.0)
	# calçadas e rua
	draw_rect(Rect2(-400, ROAD_TOP - 12, vw + 800, 12), Color("bdb7aa"))
	draw_rect(Rect2(-400, ROAD_TOP, vw + 800, ROAD_BOTTOM - ROAD_TOP), Color("3b3d42"))
	draw_rect(Rect2(-400, ROAD_BOTTOM, vw + 800, 14), Color("bdb7aa"))
	var dash := -400.0
	while dash < vw + 400:
		draw_rect(Rect2(dash, (ROAD_TOP + ROAD_BOTTOM) / 2.0 - 2, 30, 4), Color("f2d24b"))
		dash += 60.0
	# estacionamento
	draw_rect(LOT.grow(8), Color("2a2c30"))
	draw_rect(LOT, Color("4a4d54"))
	draw_rect(Rect2(LOT.position.x, LOT.position.y, LOT.size.x, 4), Color("2a2c30"))
	# entrada/saída
	draw_rect(Rect2(EXIT_X - 34, ROAD_BOTTOM, 164, LOT.position.y - ROAD_BOTTOM + 4), Color("4a4d54"))
	_draw_arrow(Vector2(ENTRY_X, LOT.position.y + 4), true)
	_draw_arrow(Vector2(EXIT_X, LOT.position.y + 4), false)
	# cancela
	var blink := int(_time * 2.0) % 2 == 0
	draw_rect(Rect2(ENTRY_X + 30, ROAD_BOTTOM + 2, 22, 22), Color("f2c230"))
	draw_circle(Vector2(ENTRY_X + 41, ROAD_BOTTOM + 13), 4, Color("3aff6a") if blink else Color("1a6a2a"))
	# vagas
	var line_col := Color(1, 1, 1, 0.85)
	for i in spot_pos.size():
		var p := spot_pos[i]
		var r := Rect2(p - spot_size / 2.0, spot_size)
		draw_line(r.position, r.position + Vector2(0, r.size.y), line_col, 2.0)
		draw_line(r.position + Vector2(r.size.x, 0), r.end, line_col, 2.0)
		draw_line(r.position + Vector2(0, r.size.y), r.end, line_col, 2.0)
	# faixas laterais de circulação
	for y in range(int(LOT.position.y) + 30, int(LOT.end.y) - 10, 40):
		draw_rect(Rect2(LEFT_LANE_X - 2, y, 4, 18), Color(1, 1, 1, 0.4))
		draw_rect(Rect2(RIGHT_LANE_X - 2, y, 4, 18), Color(1, 1, 1, 0.4))
	# árvores e postes ao redor
	for y in range(int(LOT.position.y) + 40, int(LOT.end.y), 120):
		_draw_tree(Vector2(14, y), 14.0)
		_draw_tree(Vector2(vw - 14, y + 60), 14.0)
	draw_rect(Rect2(-400, LOT.end.y + 8, vw + 800, 400), Color("5c9a45"))
	# placa "P"
	var sign_pos := Vector2(570, ROAD_BOTTOM + 2)
	draw_rect(Rect2(sign_pos.x + 16, sign_pos.y - 4, 4, 26), Color("555555"))
	draw_rect(Rect2(sign_pos, Vector2(36, 22)), Color("2f6fe0"))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(10, 19), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _draw_arrow(pos: Vector2, down: bool) -> void:
	var d := 1.0 if down else -1.0
	var c := Color(1, 1, 1, 0.8)
	draw_rect(Rect2(pos.x - 3, pos.y + 4, 6, 18), c)
	var tip := pos + Vector2(0, 22 + 10 * d) if down else pos + Vector2(0, 4 + 10 * d)
	var base_y := pos.y + (22.0 if down else 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 9, base_y), Vector2(pos.x + 9, base_y), tip]), c)


func _draw_tree(p: Vector2, r: float) -> void:
	draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.2))
	draw_circle(p, r, Color("2f7a33"))
	draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.55, Color("3f9443"))


func _draw_building(b: Dictionary, night: bool) -> void:
	var base_y := ROAD_TOP - 14.0
	var x: float = b.x
	var w: float = b.w
	var h: float = b.h
	var col: Color = b.color
	var r := Rect2(x, base_y - h, w, h)
	draw_rect(r, col.darkened(0.25) if night else col)
	draw_rect(Rect2(x + w * 0.82, base_y - h, w * 0.18, h), col.darkened(0.4))
	var kind: int = b.kind
	if kind == 0:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base_y - h), Vector2(x + w + 4, base_y - h), Vector2(x + w / 2.0, base_y - h - 22)]), Color("b0503a"))
		draw_rect(Rect2(x + w * 0.4, base_y - 22, 12, 22), Color("6b4429"))
		return
	var wr := RandomNumberGenerator.new()
	wr.seed = int(b.seed)
	var lit := Color("ffd76a")
	var dark := Color(0.2, 0.28, 0.38)
	var yy := base_y - h + 10.0
	while yy < base_y - 16.0:
		var xx := x + 6.0
		while xx < x + w * 0.78 - 8.0:
			var on := wr.randf() < (0.6 if night else 0.1)
			draw_rect(Rect2(xx, yy, 7, 9), lit if on else dark)
			xx += 13.0
		yy += 16.0
