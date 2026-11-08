extends Node2D
## Mundo isométrico: cidade em quarteirões, ruas, estacionamento no centro,
## carros, pedestres, bairros bloqueados e a câmera.

const Iso := preload("res://scripts/iso.gd")
const CarScript := preload("res://scripts/car.gd")
const PropScript := preload("res://scripts/prop.gd")
const WalkerScript := preload("res://scripts/walker.gd")
const CameraScript := preload("res://scripts/camera.gd")
const Batch := preload("res://scripts/batch.gd")
const BlockMesh := preload("res://scripts/block_mesh.gd")

const MAP := 49.0                 # tamanho do mapa em casas
const NB := 6                     # 6x6 quarteirões, ruas a cada 8 casas
const ROADS := [0.5, 8.5, 16.5, 24.5, 32.5, 40.5, 48.5]  # linhas centrais das ruas
const LOT := Rect2(17, 17, 15, 15)
const LOT_BLOCKS := [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3)]
const ENTRY_X := 23.5
const EXIT_X := 26.5
const LEFT_LANE_X := 18.25
const RIGHT_LANE_X := 31.5
const TOP_AISLE_Y := 17.5
const SPOTS_PER_ROW := 24
const LANE := 0.2
const ROAD_SPEED := 3.2
const LOT_SPEED := 2.2

const BUILDING_COLORS := ["e8d6b0", "d98c6a", "f2efe6", "c9a3d6", "9ec5e8", "e6a8a8", "b5d6a8", "f2c879", "f0b48a", "d6d0c4"]
const TOWER_COLORS := ["5b8fb9", "4a6f8f", "6aa5c4", "3f5d7a", "8fb8d8", "7a8fa6"]
const ROOF_COLORS := ["c0533a", "a8432f", "8a5a3a", "d06a3a", "6a4a6a", "3a5a8a"]

var rng := RandomNumberGenerator.new()
var ui = null
var camera = null
var objects: Node2D
var fx: Node2D
var overlay: Node2D
var tint: CanvasModulate
var spot_cars: Array = []
var block_district := {}            # Vector2i -> índice do bairro
var district_centers: Array = []    # Vector2 (grade) por bairro
var work_acc := 0.0
var shop_acc := 0.0
var traffic_count := 0
var _traffic_timer := 0.0
var _fx_budget := 4.0
var _city_key := ""
var _ground_key := ""
var _static_nodes: Array = []
var _collect = null          # quando não é null, _prop() junta aqui em vez de criar nós
var _entry_gate = null
var _exit_gate = null
var _entering: Array = []
var _leaving: Array = []
var _passer_acc := 0.0


func _ready() -> void:
	rng.randomize()
	_assign_districts()
	tint = CanvasModulate.new()
	add_child(tint)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	overlay = Node2D.new()
	overlay.z_index = 5
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	fx = Node2D.new()
	fx.z_index = 10
	add_child(fx)
	var pin = PropScript.new()
	pin.setup("pin", LOT.get_center().x, LOT.position.y + 3.0)
	fx.add_child(pin)
	camera = CameraScript.new()
	camera.name = "Camera"
	add_child(camera)
	var left := Iso.p(0, MAP).x
	var right := Iso.p(MAP, 0).x
	camera.bounds = Rect2(left, 0, right - left, Iso.p(MAP, MAP).y)
	camera.tapped.connect(_on_tapped)
	camera.make_current()
	focus_lot(true)
	spot_cars.resize(Game.spots())
	_rebuild()
	Game.changed.connect(_rebuild)
	for i in 8:
		_spawn_traffic()


# ---------------------------------------------------------------- Câmera

func focus_lot(instant: bool = false) -> void:
	camera.focus(Iso.p(23.5, 20.0), 1.15, instant)


func show_map() -> void:
	camera.focus(Iso.p(MAP / 2.0, MAP / 2.0), 0.3, false)


func focus_district(i: int) -> void:
	if i >= 0 and i < district_centers.size():
		var c: Vector2 = district_centers[i]
		# desloca para o bairro aparecer acima do painel aberto
		camera.focus(Iso.pg(c) + Vector2(0, 330.0 / 0.55), 0.55, false)


func _on_tapped(world_pos: Vector2) -> void:
	if ui == null:
		return
	var g := Iso.to_grid(world_pos)
	if LOT.has_point(g):
		ui.open_tab("upgrades")
		return
	var b := Vector2i(int(floor(g.x / 8.0)), int(floor(g.y / 8.0)))
	if block_district.has(b):
		var dist: int = block_district[b]
		ui.open_tab("expansion" if dist >= Game.districts_unlocked else "city")


# ---------------------------------------------------------------- Bairros

func _assign_districts() -> void:
	var ring1: Array = []
	var ring2: Array = []
	for bx in NB:
		for by in NB:
			var b := Vector2i(bx, by)
			if LOT_BLOCKS.has(b):
				continue
			var ring := maxf(absf(bx - 2.5), absf(by - 2.5))
			if ring < 2.0:
				ring1.append(b)
			else:
				ring2.append(b)
	ring1.sort_custom(func(a, b): return _block_angle(a) < _block_angle(b))
	ring2.sort_custom(func(a, b): return _block_angle(a) < _block_angle(b))
	for i in ring1.size():
		block_district[ring1[i]] = i / 4
	for i in ring2.size():
		block_district[ring2[i]] = 3 + i / 5
	district_centers.clear()
	for dist in Game.DISTRICTS.size():
		var sum := Vector2.ZERO
		var n := 0
		for b in block_district.keys():
			if block_district[b] == dist:
				sum += Vector2(b.x * 8 + 4.5, b.y * 8 + 4.5)
				n += 1
		district_centers.append(sum / maxf(1.0, n) if n > 0 else LOT.get_center())


## Ângulo a partir do "norte" da tela, para o Centro ficar perto da entrada.
func _block_angle(b: Vector2i) -> float:
	var a := atan2(b.y - 2.5, b.x - 2.5)
	return fposmod(a + PI * 0.75 + PI / 3.0, TAU)


func _in_front_of_lot(b: Vector2i) -> bool:
	return b.x >= 1 and b.x <= 4 and b.y >= 1 and b.y <= 4 and (b.x == 4 or b.y == 4)


## Quanto o bairro é desenvolvido: depende do número de moradores.
func _pop_level() -> float:
	return maxf(0.0, log(Game.population() / 1000.0) / log(10.0))


func _dev(dist: int) -> float:
	var dev := _pop_level() * 0.48
	if dist == 0:
		dev += 0.15
	elif dist >= 3:
		dev -= 0.1
	return dev


# ---------------------------------------------------------------- Construção

func _rebuild() -> void:
	if spot_cars.size() != Game.spots():
		spot_cars.resize(Game.spots())
	var gkey := "%d|%d" % [Game.spots(), Game.districts_unlocked]
	if gkey != _ground_key:
		_ground_key = gkey
		queue_redraw()
		overlay.queue_redraw()
	var key := "%d|%d|%d|%d" % [int(_pop_level() * 8.0), Game.districts_unlocked, int(Game.lvl.attract), Game.spots() / 48]
	if key == _city_key:
		return
	_city_key = key
	for n in _static_nodes:
		n.queue_free()
	_static_nodes.clear()
	var br := RandomNumberGenerator.new()
	_build_city(br)
	_build_lot_props()
	_build_beach(br)
	_build_walkers(br)


func _prop(kind: String, x: float, y: float, w: float = 0.0, d: float = 0.0):
	var p = PropScript.new()
	p.setup(kind, x, y, w, d)
	if _collect != null:
		_collect.append(p)
		return p
	objects.add_child(p)
	_static_nodes.append(p)
	return p


## Junta todos os objetos coletados num único nó (um comando de desenho).
func _flush_block(front: Vector2) -> void:
	var node = BlockMesh.new()
	node.position = Iso.pg(front)
	var b = Batch.new()
	_collect.sort_custom(func(a, c): return a.position.y < c.position.y)
	for p in _collect:
		p.draw_into(b, node.position)
		p.free()
	_collect = null
	node.batch = b
	objects.add_child(node)
	_static_nodes.append(node)


func _tree(x: float, y: float, r: RandomNumberGenerator, palm: bool) -> void:
	var t = _prop("palm" if palm else "tree", x, y)
	t.size_f = r.randf_range(-0.15, 0.25)
	t.color = Color.from_hsv(r.randf_range(0.25, 0.36), r.randf_range(0.55, 0.75), r.randf_range(0.5, 0.72))
	t.queue_redraw()


func _build_city(br: RandomNumberGenerator) -> void:
	var phase := Game.phase_index()
	var lit: float = [0.04, 0.12, 0.5][phase]
	for b in block_district.keys():
		var dist: int = block_district[b]
		var locked: bool = dist >= Game.districts_unlocked
		var ox: float = b.x * 8 + 1.0
		var oy: float = b.y * 8 + 1.0
		br.seed = hash(b) + 17
		_collect = []
		# palmeiras na calçada
		if not locked:
			_tree(ox + 0.15, oy + 0.15, br, true)
			_tree(ox + 6.85, oy + 6.85, br, true)
		for pi in 4:
			var px := ox + 0.4 + (pi % 2) * 3.3
			var py := oy + 0.4 + (pi / 2) * 3.3
			var r := br.randf()
			var r2 := br.randf()
			var r3 := br.randf()
			if locked:
				for k in int(r2 * 4.0):
					_tree(px + br.randf() * 2.8, py + br.randf() * 2.8, br, false)
				continue
			if dist == 3 or dist == 6:
				var wh = _prop("warehouse", px + 0.1, py + 0.1, 2.7, 2.6)
				wh.floors = 1 + int(r * 2.0)
				wh.color = Color("c9ccd2") if r2 < 0.5 else Color("d9c9a8")
				continue
			var s := _dev(dist) + r * 0.5 - 0.15
			if r3 < 0.12:
				for k in 3 + int(r2 * 3.0):
					_tree(px + br.randf() * 2.8, py + br.randf() * 2.8, br, dist == 4)
			elif s < 0.3:
				var hw := br.randf_range(1.5, 2.1)
				var hx := px + br.randf_range(0.0, 2.9 - hw)
				var hy := py + br.randf_range(0.0, 2.9 - hw)
				var h = _prop("house", hx, hy, hw, hw * br.randf_range(0.8, 1.0))
				h.floors = 2 if r2 > 0.7 else 1
				h.color = Color(BUILDING_COLORS[br.randi_range(0, BUILDING_COLORS.size() - 1)])
				h.color2 = Color(ROOF_COLORS[br.randi_range(0, ROOF_COLORS.size() - 1)])
				h.seed_value = br.randi()
				h.lit_chance = lit
				if hx - px > 0.8:
					_tree(px + 0.4, py + 2.5, br, dist == 4)
				else:
					_tree(px + 2.6, py + 0.4, br, dist == 4)
			else:
				var tower := s >= 1.0 and phase >= 2
				var floors := 0
				if s < 0.65:
					floors = 2 + int((s - 0.3) * 14.0)
				elif not tower:
					floors = mini(6 + int((s - 0.65) * 16.0), 12)
				else:
					floors = mini(12 + int((s - 1.0) * 24.0), 26)
				# quarteirões na frente do estacionamento (mais perto da câmera) ficam baixos
				if _in_front_of_lot(b):
					tower = false
					floors = mini(floors, 4)
				var bw := 2.4 if tower else 2.7
				var bld = _prop("tower" if tower else "building", px + (2.9 - bw) / 2.0, py + (2.9 - bw) / 2.0, bw, bw)
				bld.floors = maxi(2, floors)
				var pal: Array = TOWER_COLORS if tower else BUILDING_COLORS
				bld.color = Color(pal[br.randi_range(0, pal.size() - 1)])
				bld.seed_value = br.randi()
				bld.lit_chance = lit
		_flush_block(Vector2(ox + 7.0, oy + 7.0))


func _build_lot_props() -> void:
	var a := int(Game.lvl.attract)
	var units := ceili(float(Game.spots()) / (SPOTS_PER_ROW * 2))
	_prop("booth", ENTRY_X - 1.0, LOT.position.y + 0.05, 0.5, 0.4)
	_entry_gate = _prop("gate", ENTRY_X - 0.45, LOT.position.y + 0.12, 0.9, 0.0)
	_exit_gate = _prop("gate", EXIT_X - 0.45, LOT.position.y + 0.12, 0.9, 0.0)
	if a >= 3:
		var k = _prop("kiosk", LOT.position.x + 0.05, LOT.position.y + 0.05, 0.9, 0.85)
		k.color = Color("f2efe6")
		k.color2 = Color("e23b3b")
	var lamps: Array = []
	for i in 6:
		lamps.append(Vector2(19.0 + i * 2.4, LOT.position.y + 0.1))
	for u in units:
		lamps.append(Vector2(LOT.position.x + 0.1, 19.5 + 3.0 * u))
		lamps.append(Vector2(LOT.end.x - 0.1, 19.5 + 3.0 * u))
	var lit := 1.0
	for i in mini(lamps.size(), a * 3):
		var l = _prop("lamp", lamps[i].x, lamps[i].y)
		l.lit_chance = lit
	# árvores no terreno reservado para futuras vagas
	var tr := RandomNumberGenerator.new()
	tr.seed = 555
	var free_y := 21.6 + 3.0 * (units - 1) + 0.6
	var yy := free_y
	while yy < LOT.end.y - 0.4:
		var xx := LOT.position.x + 0.6
		while xx < LOT.end.x - 0.4:
			if tr.randf() < 0.45:
				_tree(xx + tr.randf_range(-0.3, 0.3), yy + tr.randf_range(-0.3, 0.3), tr, false)
			xx += 1.3
		yy += 1.3
	var canopies := 0
	if a >= 4:
		canopies = 1
	if a >= 8:
		canopies = 2
	for c in mini(canopies, units * 2):
		var u := c / 2
		var y := 18.0 + 3.0 * u + (2.0 if c % 2 == 1 else 0.0)
		_prop("canopy", 19.0, y, 12.0, 1.0)


func _build_beach(br: RandomNumberGenerator) -> void:
	br.seed = 99
	for i in 40:
		var t := br.randf() * MAP
		var side := br.randi_range(0, 3)
		var off := br.randf_range(-1.3, -0.5)
		var pos := Vector2(t, off)
		match side:
			1: pos = Vector2(off, t)
			2: pos = Vector2(t, MAP - off)
			3: pos = Vector2(MAP - off, t)
		if br.randf() < 0.65:
			_tree(pos.x, pos.y, br, true)
		else:
			var u = _prop("umbrella", pos.x, pos.y)
			u.color = Color.from_hsv(br.randf(), 0.75, 0.95)


func _build_walkers(br: RandomNumberGenerator) -> void:
	br.seed = 4242 + Game.districts_unlocked
	var count := clampi(int(Game.population() / 400.0), 8, 70)
	var blocks: Array = []
	for b in block_district.keys():
		if block_district[b] < Game.districts_unlocked:
			blocks.append(b)
	if blocks.is_empty():
		return
	for i in count:
		var b: Vector2i = blocks[br.randi_range(0, blocks.size() - 1)]
		var ox: float = b.x * 8 + 1.0
		var oy: float = b.y * 8 + 1.0
		var p0: Vector2
		var p1: Vector2
		match br.randi_range(0, 3):
			0:
				p0 = Vector2(ox + 0.2, oy + 0.15)
				p1 = Vector2(ox + 6.8, oy + 0.15)
			1:
				p0 = Vector2(ox + 0.2, oy + 6.85)
				p1 = Vector2(ox + 6.8, oy + 6.85)
			2:
				p0 = Vector2(ox + 0.15, oy + 0.2)
				p1 = Vector2(ox + 0.15, oy + 6.8)
			_:
				p0 = Vector2(ox + 6.85, oy + 0.2)
				p1 = Vector2(ox + 6.85, oy + 6.8)
		var wk = WalkerScript.new()
		wk.setup(br, p0, p1)
		objects.add_child(wk)
		_static_nodes.append(wk)


# ---------------------------------------------------------------- Vagas

func spot_center(i: int) -> Vector2:
	var u := i / (SPOTS_PER_ROW * 2)
	var k := i % (SPOTS_PER_ROW * 2)
	var row := k / SPOTS_PER_ROW
	var c := k % SPOTS_PER_ROW
	return Vector2(19.25 + 0.5 * c, 18.5 + 3.0 * u + (2.0 if row == 1 else 0.0))


func spot_aisle(i: int) -> float:
	return 19.5 + 3.0 * (i / (SPOTS_PER_ROW * 2))


# ---------------------------------------------------------------- Simulação

func _process(delta: float) -> void:
	work_acc = minf(work_acc + Game.work_arrivals_per_sec() * delta, 4.0)
	shop_acc = minf(shop_acc + Game.shop_arrivals_per_sec() * delta, 4.0)
	while work_acc >= 1.0:
		work_acc -= 1.0
		_try_arrival(true)
	while shop_acc >= 1.0:
		shop_acc -= 1.0
		_try_arrival(false)
	_update_daylight()
	_update_gates(delta)
	# carros que passam na frente do estacionamento sem entrar
	_passer_acc += minf(Game.passing_per_sec() * (1.0 - Game.enter_chance()), 1.0) * delta
	if _passer_acc >= 1.0:
		_passer_acc = 0.0
		_spawn_passer()
	_traffic_timer += delta
	var target := clampi(int(Game.passing_per_sec() * 3.0), 4, 22)
	if _traffic_timer >= 0.35 and traffic_count < target:
		_traffic_timer = 0.0
		_spawn_traffic()
	_fx_budget = minf(_fx_budget + delta * 4.0, 4.0)
	var n := 0
	for c in spot_cars:
		if c != null:
			n += 1
	Game.occupied = n


func _update_gates(delta: float) -> void:
	_entering = _entering.filter(func(c): return is_instance_valid(c) and c.is_processing())
	_leaving = _leaving.filter(func(c): return is_instance_valid(c) and c.is_processing())
	_move_gate(_entry_gate, _entering, Vector2(ENTRY_X, LOT.position.y), delta)
	_move_gate(_exit_gate, _leaving, Vector2(EXIT_X, LOT.position.y), delta)


func _move_gate(gate, cars: Array, at: Vector2, delta: float) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	var near := false
	for c in cars:
		if (c.grid as Vector2).distance_to(at) < 1.3:
			near = true
			break
	var target := 1.0 if near else 0.0
	var v := move_toward(gate.open, target, delta * 3.0)
	if not is_equal_approx(v, gate.open):
		gate.open = v
		gate.queue_redraw()


func _spawn_passer() -> void:
	var pts: Array = [Vector2(0.5, 16.5), Vector2(MAP - 0.5, 16.5)]
	if rng.randf() < 0.5:
		pts.reverse()
	var route := _lane(pts)
	var car = _new_car(route[0])
	car.arrived.connect(_despawn.bind(car), CONNECT_ONE_SHOT)
	car.go(route.slice(1), ROAD_SPEED * rng.randf_range(0.9, 1.1))


func _try_arrival(worker: bool) -> void:
	var idx := _free_spot()
	if idx == -1:
		Game.lost_customers += 1
	else:
		_spawn_arrival(idx, worker)


## Cor da luz conforme a hora do dia (amanhecer, dia, entardecer, noite).
func _update_daylight() -> void:
	var h: float = Game.hour
	var keys := [
		[0.0, Color(0.42, 0.47, 0.72)], [5.0, Color(0.45, 0.5, 0.75)], [6.5, Color(1.0, 0.82, 0.72)],
		[8.0, Color(1, 1, 1)], [16.5, Color(1, 1, 1)], [18.0, Color(1.0, 0.82, 0.66)],
		[19.5, Color(0.62, 0.58, 0.8)], [21.0, Color(0.42, 0.47, 0.72)], [24.0, Color(0.42, 0.47, 0.72)]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t := (h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			tint.color = (a[1] as Color).lerp(b[1] as Color, t)
			return


func _free_spot() -> int:
	var free: Array[int] = []
	for i in spot_cars.size():
		if spot_cars[i] == null:
			free.append(i)
	if free.is_empty():
		return -1
	# preenche primeiro as vagas da frente (mais perto da entrada)
	free.sort()
	return free[rng.randi_range(0, mini(free.size() - 1, 5))]


func _new_car(start: Vector2):
	var car = CarScript.new()
	objects.add_child(car)
	car.setup(rng, start)
	car.modulate.a = 0.0
	car.create_tween().tween_property(car, "modulate:a", 1.0, 0.4)
	return car


func _despawn(car) -> void:
	var tw = car.create_tween()
	tw.tween_property(car, "modulate:a", 0.0, 0.4)
	tw.tween_callback(car.queue_free)


func _right(d: Vector2) -> Vector2:
	var n := d.normalized()
	return Vector2(-n.y, n.x) * LANE


## Desloca a rota para a faixa da direita da rua.
func _lane(pts: Array) -> Array:
	var clean: Array = []
	for p in pts:
		if clean.is_empty() or (clean[-1] as Vector2).distance_to(p) > 0.01:
			clean.append(p)
	if clean.size() < 2:
		return clean
	var out: Array = []
	for i in clean.size():
		var off := Vector2.ZERO
		if i == 0:
			off = _right(clean[1] - clean[0])
		elif i == clean.size() - 1:
			off = _right(clean[i] - clean[i - 1])
		else:
			var d1: Vector2 = (clean[i] - clean[i - 1]).normalized()
			var d2: Vector2 = (clean[i + 1] - clean[i]).normalized()
			off = _right(d1) if absf(d1.dot(d2)) > 0.9 else _right(d1) + _right(d2)
		out.append(clean[i] + off)
	return out


func _crosses_lot(a: Vector2, b: Vector2) -> bool:
	if is_equal_approx(a.x, b.x):
		return a.x > LOT.position.x and a.x < LOT.end.x and maxf(a.y, b.y) > LOT.position.y and minf(a.y, b.y) < LOT.end.y
	return a.y > LOT.position.y and a.y < LOT.end.y and maxf(a.x, b.x) > LOT.position.x and minf(a.x, b.x) < LOT.end.x


func _rand_road() -> float:
	return ROADS[rng.randi_range(0, ROADS.size() - 1)]


func _random_route() -> Array:
	var e := MAP - 0.5
	var pts: Array = []
	if rng.randf() < 0.5:
		var r1 := _rand_road()
		var ry := _rand_road()
		var r2 := _rand_road()
		pts = [Vector2(r1, 0.5), Vector2(r1, ry), Vector2(r2, ry), Vector2(r2, e)]
	else:
		var ry1 := _rand_road()
		var rx := _rand_road()
		var ry2 := _rand_road()
		pts = [Vector2(0.5, ry1), Vector2(rx, ry1), Vector2(rx, ry2), Vector2(e, ry2)]
	if rng.randf() < 0.5:
		pts.reverse()
	for i in pts.size() - 1:
		if _crosses_lot(pts[i], pts[i + 1]):
			return []
	return pts


func _spawn_traffic() -> void:
	var pts: Array = []
	for attempt in 8:
		pts = _random_route()
		if not pts.is_empty():
			break
	if pts.is_empty():
		pts = [Vector2(0.5, 0.5), Vector2(MAP - 0.5, 0.5)]
	var route := _lane(pts)
	var car = _new_car(route[0])
	traffic_count += 1
	car.arrived.connect(_traffic_done.bind(car), CONNECT_ONE_SHOT)
	car.go(route.slice(1), ROAD_SPEED * rng.randf_range(0.85, 1.15))


func _traffic_done(car) -> void:
	traffic_count -= 1
	_despawn(car)


func _arrival_road() -> Array:
	match rng.randi_range(0, 3):
		0:
			return _lane([Vector2(0.5, 16.5), Vector2(ENTRY_X, 16.5)])
		1:
			return _lane([Vector2(MAP - 0.5, 16.5), Vector2(ENTRY_X, 16.5)])
	var r := _rand_road()
	return _lane([Vector2(r, 0.5), Vector2(r, 16.5), Vector2(ENTRY_X, 16.5)])


func _exit_road() -> Array:
	match rng.randi_range(0, 3):
		0:
			return _lane([Vector2(EXIT_X, 16.5), Vector2(0.5, 16.5)])
		1:
			return _lane([Vector2(EXIT_X, 16.5), Vector2(MAP - 0.5, 16.5)])
	var r := _rand_road()
	return _lane([Vector2(EXIT_X, 16.5), Vector2(r, 16.5), Vector2(r, 0.5)])


func _spawn_arrival(idx: int, worker: bool) -> void:
	var road := _arrival_road()
	var car = _new_car(road[0])
	if car.kind == 2:
		car.kind = 0
		car.body_color = CarScript.COLORS[rng.randi_range(0, 5)]
		car.queue_redraw()
	car.spot_index = idx
	car.worker = worker
	spot_cars[idx] = car
	var c := spot_center(idx)
	var aisle := spot_aisle(idx)
	var pts: Array = road.slice(1)
	pts.append_array([
		Vector2(ENTRY_X, TOP_AISLE_Y), Vector2(LEFT_LANE_X, TOP_AISLE_Y),
		Vector2(LEFT_LANE_X, aisle), Vector2(c.x, aisle), c])
	car.arrived.connect(_on_car_parked.bind(car), CONNECT_ONE_SHOT)
	car.go(pts, ROAD_SPEED)
	_entering.append(car)


func _on_car_parked(car) -> void:
	var idx: int = car.spot_index
	if idx < 0 or idx >= spot_cars.size() or spot_cars[idx] != car:
		_despawn(car)
		return
	Game.car_parked()
	var base: float = (Game.STAY_WORK_SECONDS if car.worker else Game.STAY_SHOP_SECONDS) * Game.stay_factor()
	var stay := rng.randf_range(base * 0.7, base * 1.3)
	get_tree().create_timer(stay).timeout.connect(_car_leave.bind(car))


func _car_leave(car) -> void:
	if not is_instance_valid(car):
		return
	var idx: int = car.spot_index
	var hours: float = rng.randf_range(4.0, 8.0) if car.worker else rng.randf_range(1.0, 2.0)
	var paid := Game.car_paid(Game.price() * roundf(hours * 2.0) / 2.0)
	_floating_text("+" + Game.money_str(paid), Iso.pg(car.grid, 26.0))
	var aisle := spot_aisle(idx)
	var pts: Array = [
		Vector2(car.grid.x, aisle), Vector2(RIGHT_LANE_X, aisle),
		Vector2(RIGHT_LANE_X, TOP_AISLE_Y), Vector2(EXIT_X, TOP_AISLE_Y)]
	pts.append_array(_exit_road())
	if idx >= 0 and idx < spot_cars.size() and spot_cars[idx] == car:
		spot_cars[idx] = null
	car.spot_index = -1
	car.arrived.connect(_despawn.bind(car), CONNECT_ONE_SHOT)
	car.go(pts, LOT_SPEED)
	_leaving.append(car)


func _floating_text(text: String, pos: Vector2) -> void:
	if _fx_budget < 1.0 or camera.zoom.x < 0.45:
		return
	_fx_budget -= 1.0
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("7dff7a"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.position = pos - Vector2(30, 10)
	fx.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", pos.y - 50.0, 1.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------------- Chão

func _draw() -> void:
	var g = Batch.new()
	_draw_ground(g)
	g.flush(get_canvas_item())


func _draw_ground(g) -> void:
	var o := Vector2.ZERO
	# mar com ondinhas
	Iso.quad(g, o, -70, -70, MAP + 140, MAP + 140, 0, Color("1e9fb4"))
	var wr := RandomNumberGenerator.new()
	wr.seed = 7
	for i in 500:
		var x := wr.randf_range(-40, MAP + 40)
		var y := wr.randf_range(-40, MAP + 40)
		if x > -3 and x < MAP + 3 and y > -3 and y < MAP + 3:
			continue
		Iso.quad(g, o, x, y, 0.7, 0.1, 0, Color(1, 1, 1, 0.22))
	# areia e grama
	Iso.quad(g, o, -2.2, -2.2, MAP + 4.4, MAP + 4.4, 0, Color("ecd79c"))
	Iso.quad(g, o, -2.2, -2.2, MAP + 4.4, 0.25, 0, Color("f7ead0"))
	Iso.quad(g, o, -2.2, -2.2, 0.25, MAP + 4.4, 0, Color("f7ead0"))
	Iso.quad(g, o, -0.3, -0.3, MAP + 0.6, MAP + 0.6, 0, Color("4fae4a"))
	for x in int(MAP):
		for y in int(MAP):
			if (x + y) % 2 == 0:
				Iso.quad(g, o, x, y, 1, 1, 0, Color("55b54f"))
	# quarteirões
	for b in block_district.keys():
		var dist: int = block_district[b]
		var locked: bool = dist >= Game.districts_unlocked
		var ox: float = b.x * 8 + 1.0
		var oy: float = b.y * 8 + 1.0
		Iso.quad(g, o, ox, oy, 7, 7, 0, Color("d4cdbd"))
		var inner := Color("5fb85a")
		if locked:
			inner = Color("7a9a55")
		elif dist == 3 or dist == 6:
			inner = Color("a8a69c")
		Iso.quad(g, o, ox + 0.3, oy + 0.3, 6.4, 6.4, 0, inner)
		if not locked and dist != 3 and dist != 6:
			Iso.quad(g, o, ox + 3.25, oy + 0.3, 0.5, 6.4, 0, Color("d4cdbd"))
			Iso.quad(g, o, ox + 0.3, oy + 3.25, 6.4, 0.5, 0, Color("d4cdbd"))
	# ruas
	var road := Color("4a4d55")
	for c in ROADS:
		var k: float = c - 0.5
		Iso.quad(g, o, 0, k, MAP, 1, 0, road)
		Iso.quad(g, o, k, 0, 1, MAP, 0, road)
	for c in ROADS:
		var k: float = c - 0.5
		for t in int(MAP):
			if t % 8 == 0:
				continue
			Iso.quad(g, o, t + 0.25, k + 0.47, 0.45, 0.06, 0, Color(1, 1, 1, 0.75))
			Iso.quad(g, o, k + 0.47, t + 0.25, 0.06, 0.45, 0, Color(1, 1, 1, 0.75))
	# faixas de pedestre
	for cx in ROADS:
		for cy in ROADS:
			var kx: float = cx - 0.5
			var ky: float = cy - 0.5
			for s in 5:
				var q := 0.1 + s * 0.17
				if kx + 1.4 < MAP:
					Iso.quad(g, o, kx + 1.05, ky + q, 0.35, 0.09, 0, Color("f2f2f2"))
				if ky + 1.4 < MAP:
					Iso.quad(g, o, kx + q, ky + 1.05, 0.09, 0.35, 0, Color("f2f2f2"))
	_draw_lot(g, o)


func _draw_lot(g, o: Vector2) -> void:
	var units := ceili(float(Game.spots()) / (SPOTS_PER_ROW * 2))
	var pave_end := minf(LOT.end.y - 0.1, 21.4 + 3.0 * (units - 1))
	Iso.quad(g, o, LOT.position.x, LOT.position.y, LOT.size.x, LOT.size.y, 0, Color("5fb85a"))
	if pave_end < LOT.end.y - 0.3:
		# área de expansão (terra)
		for i in 12:
			Iso.quad(g, o, LOT.position.x + 0.6 + i * 1.2, pave_end + 0.25, 0.5, 0.1, 0, Color("f2a33a"))
	Iso.quad(g, o, LOT.position.x, LOT.position.y, LOT.size.x, pave_end - LOT.position.y, 0, Color("2f3238"))
	Iso.quad(g, o, LOT.position.x + 0.08, LOT.position.y, LOT.size.x - 0.16, pave_end - LOT.position.y - 0.08, 0, Color("43464e"))
	var yellow := Color("f2d23a")
	for i in Game.spots():
		var c := spot_center(i)
		var x0 := c.x - 0.25
		var y0 := c.y - 0.5
		Iso.quad(g, o, x0 - 0.02, y0, 0.04, 1.0, 0, yellow)
		Iso.quad(g, o, x0 + 0.48, y0, 0.04, 1.0, 0, yellow)
		var back_y := y0 if (i % (SPOTS_PER_ROW * 2)) < SPOTS_PER_ROW else y0 + 0.96
		Iso.quad(g, o, x0 - 0.02, back_y, 0.54, 0.04, 0, yellow)
	# setas de entrada e saída
	_arrow(g, o, ENTRY_X, 17.3, 1.0)
	_arrow(g, o, EXIT_X, 17.3, -1.0)


func _arrow(g, o: Vector2, x: float, y: float, dirv: float) -> void:
	var white := Color(1, 1, 1, 0.85)
	Iso.quad(g, o, x - 0.04, y - 0.25, 0.08, 0.5, 0, white)
	var tip := y + 0.4 * dirv
	var base := y + 0.15 * dirv
	g.draw_colored_polygon(PackedVector2Array([Iso.p(x - 0.15, base), Iso.p(x + 0.15, base), Iso.p(x, tip)]), white)


# ---------------------------------------------------------------- Bairros bloqueados (por cima)

func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	var next := Game.districts_unlocked
	for b in block_district.keys():
		var dist: int = block_district[b]
		if dist < next:
			continue
		var ox: float = b.x * 8 + 1.0
		var oy: float = b.y * 8 + 1.0
		overlay.draw_colored_polygon(PackedVector2Array([Iso.p(ox, oy), Iso.p(ox + 7, oy), Iso.p(ox + 7, oy + 7), Iso.p(ox, oy + 7)]), Color(0.05, 0.1, 0.15, 0.35))
		if dist == next:
			var pts := PackedVector2Array([Iso.p(ox, oy), Iso.p(ox + 7, oy), Iso.p(ox + 7, oy + 7), Iso.p(ox, oy + 7), Iso.p(ox, oy)])
			overlay.draw_polyline(pts, Color("3ff0ff"), 4.0)
	for dist in range(next, Game.DISTRICTS.size()):
		var c := Iso.pg(district_centers[dist])
		var d: Dictionary = Game.DISTRICTS[dist]
		var body := Rect2(c + Vector2(-16, -30), Vector2(32, 26))
		overlay.draw_arc(c + Vector2(0, -30), 11.0, PI, TAU, 16, Color("c9ced6"), 5.0)
		overlay.draw_rect(body, Color("8a919c"))
		overlay.draw_rect(body.grow(-3), Color("b8bec8"))
		overlay.draw_circle(c + Vector2(0, -19), 3.5, Color("4a4f58"))
		var title: String = d.name
		var price := Game.money_str(float(d.cost))
		var col := Color("3ff0ff") if dist == next else Color.WHITE
		overlay.draw_string_outline(font, c + Vector2(-150, 20), title, HORIZONTAL_ALIGNMENT_CENTER, 300, 26, 6, Color(0, 0, 0, 0.85))
		overlay.draw_string(font, c + Vector2(-150, 20), title, HORIZONTAL_ALIGNMENT_CENTER, 300, 26, col)
		overlay.draw_string_outline(font, c + Vector2(-150, 46), price, HORIZONTAL_ALIGNMENT_CENTER, 300, 22, 6, Color(0, 0, 0, 0.85))
		overlay.draw_string(font, c + Vector2(-150, 46), price, HORIZONTAL_ALIGNMENT_CENTER, 300, 22, Color("ffd23f"))
