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
const CrowdScript := preload("res://scripts/crowd.gd")

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
const FIRST_NAMES := ["Ana", "Bruno", "Carla", "Diego", "Eduarda", "Felipe", "Gabriela", "Henrique", "Isabela", "João", "Larissa", "Lucas", "Mariana", "Mateus", "Natália", "Otávio", "Paula", "Rafael", "Sofia", "Thiago", "Vitória", "Gustavo", "Beatriz", "Pedro", "Camila", "Rodrigo", "Juliana", "André"]
const LAST_NAMES := ["Silva", "Souza", "Oliveira", "Santos", "Pereira", "Lima", "Costa", "Ferreira", "Almeida", "Carvalho", "Ribeiro", "Martins", "Rocha", "Moura", "Barbosa", "Gomes"]
const JOBS := ["Enfermeira(o)", "Professor(a)", "Engenheiro(a)", "Vendedor(a)", "Programador(a)", "Advogado(a)", "Contador(a)", "Médico(a)", "Arquiteto(a)", "Bancário(a)", "Recepcionista", "Gerente de loja", "Analista", "Designer"]
const ERRANDS := ["Fazendo compras", "Indo ao banco", "Almoçando no centro", "Indo ao cinema", "Consulta médica", "Passeando no comércio", "Buscando encomenda"]
const SERVICE_Y0 := 30.35   # faixa no fundo do estacionamento reservada aos serviços
const SERVICE_SLOTS := {"wash": [18.2, 2.6], "cafe": [21.3, 1.9], "ev": [23.7, 2.6], "tire": [26.8, 2.6]}
const LANE := 0.2
const ROAD_SPEED := 3.2
const LOT_SPEED := 2.2

const BUILDING_COLORS := ["e8d6b0", "d98c6a", "f2efe6", "c9a3d6", "9ec5e8", "e6a8a8", "b5d6a8", "f2c879", "f0b48a", "d6d0c4"]
const TOWER_COLORS := ["5b8fb9", "4a6f8f", "6aa5c4", "3f5d7a", "8fb8d8", "7a8fa6"]
const ROOF_COLORS := ["c0533a", "a8432f", "8a5a3a", "d06a3a", "6a4a6a", "3a5a8a"]

var perf_us := 0.0   # tempo médio de _process (microssegundos), para medição
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
var _block_nodes := {}
var _block_keys := {}
var _pending_blocks: Array = []
var _last_block_node = null
var _lot_key := ""
var _beach_built := false
var crowd = null
var _gb := Vector2i(1, 2)        # quarteirão do edifício-garagem
var _g_side := "left"
var _lot_block := {}              # bairro -> quarteirão com o estacionamento do bairro
var _lot_text_acc := 0.0
var cars: Array = []              # carros ativos (para manter distância)
var _arriving := 0                # carros a caminho de uma vaga
const MAX_ARRIVING := 8
var _frame := 0
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
	signals = Node2D.new()
	signals.position = Vector2(0, -100000)  # desenhado antes (y-sort), abaixo dos prédios
	signals.draw.connect(_draw_signals)
	objects.add_child(signals)
	crowd = CrowdScript.new()
	crowd.world = self
	add_child(crowd)
	_rebuild()
	_process_pending(999)
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
	var car = car_at(world_pos)
	if car != null:
		ui.show_customer(car)
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
	# edifício-garagem num quarteirão do Centro vizinho ao estacionamento (lado de trás)
	for cand in [[Vector2i(1, 2), "left"], [Vector2i(1, 3), "left"], [Vector2i(2, 1), "top"], [Vector2i(3, 1), "top"]]:
		if block_district.get(cand[0], -1) == 0:
			_gb = cand[0]
			_g_side = cand[1]
			break
	# estacionamento de cada bairro: o quarteirão do bairro mais perto do centro
	for dd in range(1, Game.DISTRICTS.size()):
		var best = null
		var best_d := 1e9
		for bb in block_district.keys():
			if block_district[bb] == dd:
				var dist2 := Vector2(bb.x - 2.5, bb.y - 2.5).length()
				if dist2 < best_d:
					best_d = dist2
					best = bb
		if best != null:
			_lot_block[dd] = best
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
	var gkey := "%d|%d" % [Game.surface_spots(), Game.districts_unlocked]
	if gkey != _ground_key:
		_ground_key = gkey
		queue_redraw()
		overlay.queue_redraw()
	# quarteirões: só os que mudaram, alguns por quadro (evita travadas)
	for b in block_district.keys():
		var k := _block_key(b)
		if _block_keys.get(b, "") != k:
			_block_keys[b] = k
			if not _pending_blocks.has(b):
				_pending_blocks.append(b)
	var lkey := "%d|%d|%s|%s|%d" % [int(Game.lvl.attract), Game.surface_spots() / 48, str(Game.services), str(Game.staff), Game.phase_index()]
	if lkey != _lot_key:
		_lot_key = lkey
		for n in _static_nodes:
			if is_instance_valid(n):
				n.queue_free()
		_static_nodes.clear()
		_build_lot_props()
	if not _beach_built:
		_beach_built = true
		_build_beach(RandomNumberGenerator.new())
	if crowd:
		crowd.refresh_blocks()


func _block_key(b: Vector2i) -> String:
	var dist: int = block_district[b]
	var locked := dist >= Game.districts_unlocked
	if locked:
		return "L"
	var extra := ""
	if b == _gb:
		extra += "g%d" % int(Game.lvl.get("garage", 0))
	if _lot_block.has(dist) and _lot_block[dist] == b:
		extra += "l%d/%d" % [Game.lot_lvl(dist), Game.lot_floors(dist)]
	return "%d|%d|%s" % [int(_dev(dist) * 20.0), Game.phase_index(), extra]


## Reconstrói até `n` quarteirões pendentes por quadro.
func _process_pending(n: int) -> void:
	while n > 0 and not _pending_blocks.is_empty():
		n -= 1
		var b: Vector2i = _pending_blocks.pop_front()
		var old = _block_nodes.get(b, null)
		_build_block(b)
		_block_nodes[b] = _last_block_node
		if old != null and is_instance_valid(old):
			old.queue_free()


func _prop(kind: String, x: float, y: float, w: float = 0.0, d: float = 0.0):
	var p = PropScript.new()
	p.setup(kind, x, y, w, d)
	if _collect != null:
		_collect.append(p)
		return p
	objects.add_child(p)
	_static_nodes.append(p)
	return p


## Junta os objetos coletados num único nó, na ordem de trás para frente,
## agrupando polígonos e intercalando os sprites.
func _flush_block(front: Vector2) -> void:
	var node = BlockMesh.new()
	node.position = Iso.pg(front)
	var b = Batch.new()
	_collect.sort_custom(func(a, c): return a.position.y < c.position.y)
	for p in _collect:
		if p.kind == "sprite":
			Iso.shadow(b, node.position, p.x0, p.y0, p.w, p.d, 40.0)
			node.ops.append(["b", b])
			b = Batch.new()
			node.ops.append(["t", p.tex, Rect2(p.tex_rect.position - node.position, p.tex_rect.size)])
		else:
			p.draw_into(b, node.position)
		p.free()
	_collect = null
	if not b.is_empty():
		node.ops.append(["b", b])
	objects.add_child(node)
	_last_block_node = node


# ---------------------------------------------------------------- Sprites (Kenney, CC0)

var _sprite_meta := {}
var _tex_cache := {}


func _sprite(key: String):
	if _sprite_meta.is_empty():
		var txt := FileAccess.get_file_as_string("res://assets/sprites/sprites.json")
		var d = JSON.parse_string(txt)
		if typeof(d) == TYPE_DICTIONARY:
			_sprite_meta = d
	if not _sprite_meta.has(key):
		return null
	if not _tex_cache.has(key):
		_tex_cache[key] = load("res://assets/sprites/%s.png" % key)
	return [_tex_cache[key], _sprite_meta[key]]


## Prédio da Kenney ocupando a área (x, y, w, w); escala o sprite para caber.
func _kenney_building(model: String, rot: int, x: float, y: float, w: float):
	var spr = _sprite("%s_r%d" % [model, rot])
	if spr == null:
		return null
	var m: Dictionary = spr[1]
	var s := w * 0.5          # sprites foram feitos em 2x (1 casa = 128 px)
	var p = _prop("sprite", x, y, w, w)
	p.tex = spr[0]
	var anchor := Vector2(float(m.ax), float(m.ay)) * s
	p.tex_rect = Rect2(Iso.p(x + w / 2.0, y + w / 2.0) - anchor, Vector2(float(m.w), float(m.h)) * s)
	return p


## Quadros de um veículo da Kenney nas 4 direções da grade.
func vehicle_frames(model: String, length_tiles: float) -> Dictionary:
	var out := {}
	var dirs := {"px": 90, "py": 0, "nx": 270, "ny": 180}
	for k in dirs.keys():
		var spr = _sprite("%s_r%d" % [model, dirs[k]])
		if spr == null:
			return {}
		var m: Dictionary = spr[1]
		var size: Array = m.size
		var real_len := maxf(float(size[0]), float(size[2]))
		var s := length_tiles / real_len * 0.5
		out[k] = [spr[0], Rect2(-Vector2(float(m.ax), float(m.ay)) * s, Vector2(float(m.w), float(m.h)) * s)]
	return out


func _tree(x: float, y: float, r: RandomNumberGenerator, palm: bool) -> void:
	var t = _prop("palm" if palm else "tree", x, y)
	t.size_f = r.randf_range(-0.15, 0.25)
	t.color = Color.from_hsv(r.randf_range(0.25, 0.36), r.randf_range(0.55, 0.75), r.randf_range(0.5, 0.72))
	t.queue_redraw()


func _build_block(b: Vector2i) -> void:
	var br := RandomNumberGenerator.new()
	var phase := Game.phase_index()
	var lit: float = [0.04, 0.12, 0.5][phase]
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
	var skip := []
	if b == _gb and int(Game.lvl.get("garage", 0)) > 0:
		skip = [1, 3] if _g_side == "left" else [2, 3]
		var gx := ox + 3.6 if _g_side == "left" else ox + 0.4
		var gy := oy + 0.4 if _g_side == "left" else oy + 3.6
		var gw := 3.1 if _g_side == "left" else 6.2
		var gd := 6.2 if _g_side == "left" else 3.1
		var gar = _prop("parking_garage", gx, gy, gw, gd)
		gar.floors = int(Game.lvl.garage)
		gar.seed_value = 7
	if _lot_block.get(dist, null) == b and Game.lot_lvl(dist) > 0:
		skip.append(0)
		var kind := "parking_garage" if Game.lot_floors(dist) > 0 else "district_lot"
		var lp = _prop(kind, ox + 0.35, oy + 0.35, 3.0, 3.0)
		lp.floors = Game.lot_floors(dist) if Game.lot_floors(dist) > 0 else Game.lot_lvl(dist)
		lp.seed_value = dist * 31
	for pi in 4:
		if skip.has(pi):
			continue
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
	var units := ceili(float(Game.surface_spots()) / (SPOTS_PER_ROW * 2))
	# cabine na ilha entre a entrada e a saída (fora do caminho dos carros)
	_prop("booth", 24.6, LOT.position.y + 0.06, 0.55, 0.35)
	_entry_gate = _prop("gate", 24.45, LOT.position.y + 0.12, -1.15, 0.0)
	_exit_gate = _prop("gate", 25.55, LOT.position.y + 0.12, 1.2, 0.0)
	_build_fence()
	_build_services()
	_build_staff()
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
	while yy < SERVICE_Y0 - 0.3:
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


func _build_services() -> void:
	for k in SERVICE_SLOTS.keys():
		if Game.service_lvl(k) <= 0:
			continue
		var slot: Array = SERVICE_SLOTS[k]
		var sp = _prop("svc_" + k, float(slot[0]), SERVICE_Y0, float(slot[1]), 1.3)
		sp.floors = Game.service_lvl(k)
		sp.queue_redraw()


## Funcionários andando pelo estacionamento (colete laranja).
func _build_staff() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var n := mini(Game.staff_total(), 16)
	for i in n:
		var wk = WalkerScript.new()
		var y := TOP_AISLE_Y if i % 2 == 0 else 19.5 + 3.0 * float(r.randi_range(0, 1))
		var p0 := Vector2(r.randf_range(18.5, 22.0), y)
		var p1 := Vector2(r.randf_range(27.0, 31.0), y)
		if i % 3 == 2:
			p0 = Vector2(LEFT_LANE_X, 18.0)
			p1 = Vector2(LEFT_LANE_X, r.randf_range(22.0, 29.0))
		wk.setup(r, p0, p1)
		wk.shirt = Color("ff7a1a")
		objects.add_child(wk)
		_static_nodes.append(wk)


## Cerca metálica em volta do estacionamento, aberta na entrada/saída.
func _build_fence() -> void:
	var x0 := LOT.position.x
	var y0 := LOT.position.y
	var x1 := LOT.end.x
	var y1 := LOT.end.y
	var x := x0
	while x < x1 - 0.01:
		var nx := minf(x + 1.0, x1)
		if nx <= 22.9 or x >= 27.2:
			_fence_seg(x, y0, nx - x, 0.0, true)
		elif x < 22.9:
			_fence_seg(x, y0, 22.9 - x, 0.0, true)
		elif nx > 27.2:
			_fence_seg(27.2, y0, nx - 27.2, 0.0, true)
		_fence_seg(x, y1, nx - x, 0.0, false)
		x = nx
	var y := y0
	while y < y1 - 0.01:
		var ny := minf(y + 1.0, y1)
		_fence_seg(x0, y, 0.0, ny - y, true)
		_fence_seg(x1, y, 0.0, ny - y, false)
		y = ny


func _fence_seg(x: float, y: float, w: float, d: float, back: bool) -> void:
	var f = _prop("fence", x, y, w, d)
	# lados de trás ficam atrás dos carros; os da frente, na frente
	if back:
		f.position = Iso.p(x, y) - Vector2(0, 1)


func _build_beach(br: RandomNumberGenerator) -> void:
	br.seed = 99
	var keep := _static_nodes
	_static_nodes = []
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
	_static_nodes = keep


# ---------------------------------------------------------------- Vagas

func is_garage_spot(i: int) -> bool:
	return i >= Game.surface_spots()


## Ponto da rua em frente ao edifício-garagem e ponto dentro dele.
func garage_points() -> Array:
	var ox: float = _gb.x * 8 + 1.0
	var oy: float = _gb.y * 8 + 1.0
	if _g_side == "top":
		var xm := ox + 5.2
		return [Vector2(xm, 16.5), Vector2(xm, oy + 6.2)]
	var ym := oy + 3.5
	return [Vector2(16.5, ym), Vector2(ox + 6.2, ym)]


func spot_center(i: int) -> Vector2:
	if is_garage_spot(i):
		return garage_points()[1]
	var u := i / (SPOTS_PER_ROW * 2)
	var k := i % (SPOTS_PER_ROW * 2)
	var row := k / SPOTS_PER_ROW
	var c := k % SPOTS_PER_ROW
	return Vector2(19.25 + 0.5 * c, 18.5 + 3.0 * u + (2.0 if row == 1 else 0.0))


func spot_aisle(i: int) -> float:
	return 19.5 + 3.0 * (i / (SPOTS_PER_ROW * 2))


# ---------------------------------------------------------------- Simulação

func _process(delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_us = perf_us * 0.95 + float(Time.get_ticks_usec() - _t0) * 0.05


func _process_inner(delta: float) -> void:
	work_acc = minf(work_acc + Game.work_arrivals_per_sec() * delta, 4.0)
	shop_acc = minf(shop_acc + Game.shop_arrivals_per_sec() * delta, 4.0)
	while work_acc >= 1.0:
		work_acc -= 1.0
		_try_arrival(true)
	while shop_acc >= 1.0:
		shop_acc -= 1.0
		_try_arrival(false)
	_update_daylight()
	_process_pending(2)
	_update_lights(delta)
	_frame += 1
	if _frame % 2 == 0:
		_keep_distance()
	_lot_texts(delta)
	_update_gates(delta)
	# carros que passam na frente do estacionamento sem entrar
	_passer_acc += minf(Game.passing_per_sec() * (1.0 - Game.enter_chance()), 0.6) * delta
	if _passer_acc >= 1.0:
		_passer_acc = 0.0
		_spawn_passer()
	_traffic_timer += delta
	var target := clampi(int(Game.passing_per_sec() * 3.0), 4, 12)
	if _traffic_timer >= 0.35 and traffic_count < target:
		_traffic_timer = 0.0
		_spawn_traffic()
	_fx_budget = minf(_fx_budget + delta * 4.0, 4.0)
	_angry_cd = maxf(0.0, _angry_cd - delta)
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


## Cliente chega, vê o estacionamento lotado e vai embora.
var _angry_cd := 0.0


func _angry_customer() -> void:
	if _angry_cd > 0.0:
		return
	_angry_cd = 2.5
	var from_left := rng.randf() < 0.5
	var x0 := 0.5 if from_left else MAP - 0.5
	var x1 := MAP - 0.5 if from_left else 0.5
	var road := _lane([Vector2(x0, 16.5), Vector2(x1, 16.5)])
	var car = _new_car(road[0])
	car.angry = true
	car.cname = _random_name()
	car.job = "Queria estacionar"
	car.status = "Desistiu: estacionamento lotado!"
	car.arrived.connect(_despawn.bind(car), CONNECT_ONE_SHOT)
	car.go(road.slice(1), ROAD_SPEED * 0.8)
	var t := get_tree().create_timer(absf(ENTRY_X - x0) / (ROAD_SPEED * 0.8))
	t.timeout.connect(_angry_text.bind(car))


func _angry_text(car) -> void:
	if is_instance_valid(car):
		Sfx.play("skid", -14.0, 1.5)
		_floating_text("Lotado!", Iso.pg(car.grid, 30.0), Color("ff5a5a"), true)


func _random_name() -> String:
	return "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]]


## Carro mais perto do toque (para mostrar os dados do cliente).
func car_at(world_pos: Vector2):
	var best = null
	var best_d := 28.0 / maxf(0.3, camera.zoom.x)
	for c in objects.get_children():
		if c.get_script() == CarScript and c.cname != "":
			var d: float = (c.position - Vector2(0, 8)).distance_to(world_pos)
			if d < best_d:
				best_d = d
				best = c
	return best


# ---------------------------------------------------------------- Semáforos

const LIGHT_CYCLE := 16.0
var light_t := 0.0
var _light_state := ""
var signals: Node2D


## Ruas horizontais (ao longo de x) com sinal verde para carros.
func h_green() -> bool:
	return light_t < 6.5


func v_green() -> bool:
	return light_t >= 8.0 and light_t < 14.5


## Pedestre pode começar a atravessar uma rua vertical (andando em x) ou horizontal (em y).
func ped_can_cross(along_x: bool) -> bool:
	if along_x:
		return light_t < 3.5
	return light_t >= 8.0 and light_t < 11.5


func _light_color(green: bool, t_end: float) -> Color:
	if green:
		return Color("ffd23f") if light_t > t_end - 1.5 else Color("3fe06a")
	return Color("ff4a4a")


func _update_lights(delta: float) -> void:
	light_t = fmod(light_t + delta, LIGHT_CYCLE)
	var st := "%s%s%s" % [h_green(), v_green(), light_t > 5.0 and light_t < 6.5 or light_t > 13.0 and light_t < 14.5]
	if st != _light_state:
		_light_state = st
		signals.queue_redraw()


func _draw_signals() -> void:
	var b = Batch.new()
	var hc := _light_color(h_green(), 6.5)
	var vc := _light_color(v_green(), 14.5)
	for cx in ROADS:
		for cy in ROADS:
			var kx: float = cx - 0.5
			var ky: float = cy - 0.5
			if LOT.has_point(Vector2(kx + 0.5, ky + 0.5)) or kx <= 0.0 or ky <= 0.0 or kx >= MAP - 1.0 or ky >= MAP - 1.0:
				continue
			# poste para quem anda em x (canto de baixo) e para quem anda em y (canto de cima)
			for pole in [[Vector2(kx + 1.08, ky + 1.08), hc], [Vector2(kx - 0.08, ky - 0.08), vc]]:
				var base := Iso.pg(pole[0], 2.6) - signals.position
				b.draw_line(base, base - Vector2(0, 20), Color("2b2f36"), 2.0)
				b.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, -27), base + Vector2(3, -27), base + Vector2(3, -18), base + Vector2(-3, -18)]), Color("1b1e24"))
				b.draw_circle(base - Vector2(0, 22.5), 2.3, pole[1])
	b.flush(signals.get_canvas_item())


## Para no sinal vermelho antes da faixa de pedestres.
func _red_light_stop(g: Vector2, dir: Vector2) -> bool:
	if LOT.grow(-0.2).has_point(g):
		return false
	if absf(dir.x) > 0.7:
		if h_green():
			return false
		for c in ROADS:
			var k: float = c - 0.5
			if dir.x > 0.0 and g.x > k - 1.05 and g.x < k - 0.68:
				return true
			if dir.x < 0.0 and g.x < k + 2.05 and g.x > k + 1.68:
				return true
	elif absf(dir.y) > 0.7:
		if v_green():
			return false
		for c in ROADS:
			var k: float = c - 0.5
			if dir.y > 0.0 and g.y > k - 1.05 and g.y < k - 0.68:
				return true
			if dir.y < 0.0 and g.y < k + 2.05 and g.y > k + 1.68:
				return true
	return false


## Carros mantêm distância do carro da frente na mesma faixa (sem se atravessar).
func _keep_distance() -> void:
	var cells := {}
	var moving: Array = []
	for c in cars:
		if not is_instance_valid(c) or not c.is_processing() or not c.visible:
			continue
		moving.append(c)
		var key := Vector2i(int(floor(c.grid.x)), int(floor(c.grid.y)))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(c)
	var crowd_crossing: Array = crowd.crossing if crowd else []
	for c in moving:
		var g: Vector2 = c.grid
		var dir: Vector2 = c.dir
		var blocked := false
		var cx := int(floor(g.x))
		var cy := int(floor(g.y))
		for ox in range(-1, 2):
			if blocked:
				break
			for oy in range(-1, 2):
				var list = cells.get(Vector2i(cx + ox, cy + oy), null)
				if list == null:
					continue
				for o in list:
					if o == c:
						continue
					var d: Vector2 = o.grid - g
					var along := d.dot(dir)
					if along <= 0.02 or along > 0.62:
						continue
					if absf(d.x * dir.y - d.y * dir.x) > 0.16:
						continue
					if (o.dir as Vector2).dot(dir) < -0.5:
						continue
					blocked = true
					break
				if blocked:
					break
		if not blocked and c.visible:
			blocked = _red_light_stop(g, dir)
		# nunca passa por cima de pedestre atravessando
		if not blocked:
			for pp in crowd_crossing:
				var dp: Vector2 = pp - g
				var al := dp.dot(dir)
				if al > 0.0 and al < 0.8 and absf(dp.x * dir.y - dp.y * dir.x) < 0.35:
					blocked = true
					break
		c.hold = blocked


func _lot_texts(delta: float) -> void:
	_lot_text_acc += delta
	if _lot_text_acc < 4.0:
		return
	_lot_text_acc = 0.0
	if camera.zoom.x < 0.4:
		return
	for dd in _lot_block.keys():
		if Game.lot_lvl(dd) > 0 and dd < Game.districts_unlocked:
			var b: Vector2i = _lot_block[dd]
			var amount := Game.lot_income_at(dd, Game.price()) * 4.0
			if amount >= 1.0:
				_floating_text("+" + Game.money_str(amount), Iso.p(b.x * 8 + 2.8, b.y * 8 + 2.8, 40.0), Color("7dff7a"), true)


func _try_arrival(worker: bool) -> void:
	var idx := _free_spot()
	if idx == -1:
		Game.note_lost_customer()
		_angry_customer()
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


const VEHICLE_SPRITES := {}  # sprites da Kenney desativados (estilo próprio)
var _frames_cache := {}


func _new_car(start: Vector2):
	var car = CarScript.new()
	objects.add_child(car)
	car.setup(rng, start)
	cars.append(car)
	if VEHICLE_SPRITES.has(car.kind):
		var list: Array = VEHICLE_SPRITES[car.kind]
		var model: String = list[rng.randi_range(0, list.size() - 1)]
		if not _frames_cache.has(model):
			_frames_cache[model] = vehicle_frames(model, 0.38 if car.kind == 7 else 0.56)
		car.frames = _frames_cache[model]
		car.queue_redraw()
	car.modulate.a = 0.0
	car.create_tween().tween_property(car, "modulate:a", 1.0, 0.4)
	return car


func _despawn(car) -> void:
	cars.erase(car)
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


func _arrival_road_to(tx: float, tail: Array = []) -> Array:
	var pts: Array = []
	match rng.randi_range(0, 3):
		0:
			pts = [Vector2(0.5, 16.5), Vector2(tx, 16.5)]
		1:
			pts = [Vector2(MAP - 0.5, 16.5), Vector2(tx, 16.5)]
		_:
			var r := _rand_road()
			pts = [Vector2(r, 0.5), Vector2(r, 16.5), Vector2(tx, 16.5)]
	pts.append_array(tail)
	return _lane(pts)


func _exit_road_from(head: Array, sx: float) -> Array:
	var pts: Array = head.duplicate()
	match rng.randi_range(0, 3):
		0:
			pts.append_array([Vector2(sx, 16.5), Vector2(0.5, 16.5)])
		1:
			pts.append_array([Vector2(sx, 16.5), Vector2(MAP - 0.5, 16.5)])
		_:
			var r := _rand_road()
			pts.append_array([Vector2(sx, 16.5), Vector2(r, 16.5), Vector2(r, 0.5)])
	return _lane(pts)


func _spawn_arrival(idx: int, worker: bool) -> void:
	var garage := is_garage_spot(idx)
	var gp := garage_points()
	var road: Array
	# rua cheia: os excedentes já aparecem na entrada (ou dentro da garagem), sem engarrafar
	var busy := _arriving >= MAX_ARRIVING
	if busy and garage:
		var hid = _new_car(gp[1])
		hid.visible = false
		hid.spot_index = idx
		hid.worker = worker
		hid.cname = _random_name()
		hid.job = JOBS[rng.randi_range(0, JOBS.size() - 1)] if worker else ERRANDS[rng.randi_range(0, ERRANDS.size() - 1)]
		hid.hours = roundf((rng.randf_range(4.0, 8.0) if worker else rng.randf_range(1.0, 2.0)) * 2.0) / 2.0
		spot_cars[idx] = hid
		_arriving += 1
		_on_car_parked(hid)
		return
	if busy:
		road = [Vector2(ENTRY_X - 0.2, 16.7), Vector2(ENTRY_X, 16.7)]
	elif not garage:
		road = _arrival_road()
	elif _g_side == "top":
		road = _arrival_road_to(gp[0].x)
	else:
		road = _arrival_road_to(16.5, [gp[0]])
	var car = _new_car(road[0])
	if car.kind == 2:
		car.kind = 0
		car.body_color = CarScript.COLORS[rng.randi_range(0, 5)]
		car.queue_redraw()
	car.spot_index = idx
	car.worker = worker
	car.cname = _random_name()
	car.job = JOBS[rng.randi_range(0, JOBS.size() - 1)] if worker else ERRANDS[rng.randi_range(0, ERRANDS.size() - 1)]
	car.hours = roundf((rng.randf_range(4.0, 8.0) if worker else rng.randf_range(1.0, 2.0)) * 2.0) / 2.0
	car.status = "Chegando ao estacionamento"
	spot_cars[idx] = car
	var c := spot_center(idx)
	var aisle := spot_aisle(idx)
	var pts: Array = road.slice(1)
	if garage:
		pts.append(c)
		car.status = "Indo para o edifício-garagem"
	else:
		pts.append_array([
			Vector2(ENTRY_X, TOP_AISLE_Y), Vector2(LEFT_LANE_X, TOP_AISLE_Y),
			Vector2(LEFT_LANE_X, aisle), Vector2(c.x, aisle), c])
		_entering.append(car)
	car.arrived.connect(_on_car_parked.bind(car), CONNECT_ONE_SHOT)
	car.go(pts, ROAD_SPEED)
	_arriving += 1


func _on_car_parked(car) -> void:
	_arriving = maxi(0, _arriving - 1)
	var idx: int = car.spot_index
	if idx < 0 or idx >= spot_cars.size() or spot_cars[idx] != car:
		_despawn(car)
		return
	Game.car_parked()
	if is_garage_spot(idx):
		car.visible = false
		car.status = "Estacionado no edifício-garagem"
	else:
		car.status = "Estacionado"
		_driver_walks(car)
	var base: float = (Game.STAY_WORK_SECONDS if car.worker else Game.STAY_SHOP_SECONDS) * Game.stay_factor()
	var stay := rng.randf_range(base * 0.7, base * 1.3)
	get_tree().create_timer(stay).timeout.connect(_car_leave.bind(car))


## O motorista desce do carro e caminha até a calçada.
var _drivers := 0


func _driver_walks(car) -> void:
	if _drivers >= 8 or camera.zoom.x < 0.45:
		return
	_drivers += 1
	var c: Vector2 = car.grid
	var aisle := spot_aisle(car.spot_index)
	var side := 0.18 if rng.randf() < 0.5 else -0.18
	var pts: Array = [c + Vector2(side, 0), Vector2(c.x + side, aisle), Vector2(25.35, aisle), Vector2(25.35, TOP_AISLE_Y),
		Vector2(25.35, LOT.position.y - 0.1), Vector2(25.35, 15.84), Vector2(rng.randf_range(26.0, 31.5), 15.84)]
	var wk = WalkerScript.new()
	wk.setup_path(rng, pts)
	objects.add_child(wk)
	wk.tree_exited.connect(func(): _drivers -= 1)


func _car_leave(car) -> void:
	if not is_instance_valid(car):
		return
	var idx: int = car.spot_index
	var hours: float = car.hours if car.hours > 0.0 else 1.0
	var paid := Game.car_paid(Game.price() * hours)
	car.spent += paid
	car.status = "Indo embora"
	if camera.zoom.x >= 0.5:
		Sfx.play("coin", -16.0, 0.35, 0.12)
	_floating_text("+" + Game.money_str(paid), Iso.pg(car.grid, 26.0))
	var extra := Game.roll_services(rng)
	for i in extra.size():
		var e: Array = extra[i]
		_floating_text("+%s %s" % [Game.money_str(e[1]), e[0]], Iso.pg(car.grid, 44.0 + 16.0 * i), Color("7fe7ff"))
		car.spent += float(e[1])
	var pts: Array = []
	if idx >= 0 and is_garage_spot(idx):
		var gp := garage_points()
		car.visible = true
		car.grid = gp[1]
		if _g_side == "top":
			pts = _exit_road_from([gp[1], gp[0]], gp[0].x)
		else:
			pts = _exit_road_from([gp[1], gp[0]], 16.5)
		pts = pts.slice(1)
	else:
		var aisle := spot_aisle(idx)
		pts = [
			Vector2(car.grid.x, aisle), Vector2(RIGHT_LANE_X, aisle),
			Vector2(RIGHT_LANE_X, TOP_AISLE_Y), Vector2(EXIT_X, TOP_AISLE_Y)]
		pts.append_array(_exit_road())
		_leaving.append(car)
	if idx >= 0 and idx < spot_cars.size() and spot_cars[idx] == car:
		spot_cars[idx] = null
	car.spot_index = -1
	car.arrived.connect(_despawn.bind(car), CONNECT_ONE_SHOT)
	car.go(pts, LOT_SPEED)


func _floating_text(text: String, pos: Vector2, color: Color = Color("7dff7a"), force: bool = false) -> void:
	if camera.zoom.x < 0.45 or (_fx_budget < 1.0 and not force):
		return
	_fx_budget = maxf(0.0, _fx_budget - 1.0)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
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
	var gn := RandomNumberGenerator.new()
	gn.seed = 11
	for x in int(MAP):
		for y in int(MAP):
			var v := gn.randf_range(-0.035, 0.035)
			Iso.quad(g, o, x, y, 1, 1, 0, Color("51b14c").lightened(v) if v > 0.0 else Color("51b14c").darkened(-v))
	# quarteirões
	for b in block_district.keys():
		var dist: int = block_district[b]
		var locked: bool = dist >= Game.districts_unlocked
		var ox: float = b.x * 8 + 1.0
		var oy: float = b.y * 8 + 1.0
		# calçada elevada com meio-fio
		Iso.prism(g, o, ox, oy, 7, 7, 0.0, 2.5, Color("bfb7a6"), Color("d8d1c1"))
		for t in range(1, 7):
			Iso.quad(g, o, ox + t, oy, 0.03, 0.3, 2.6, Color(0, 0, 0, 0.06))
			Iso.quad(g, o, ox, oy + t, 0.3, 0.03, 2.6, Color(0, 0, 0, 0.06))
		var inner := Color("5fb85a")
		if locked:
			inner = Color("7a9a55")
		elif dist == 3 or dist == 6:
			inner = Color("a8a69c")
		Iso.quad(g, o, ox + 0.3, oy + 0.3, 6.4, 6.4, 2.6, inner)
		if not locked and dist != 3 and dist != 6:
			Iso.quad(g, o, ox + 3.25, oy + 0.3, 0.5, 6.4, 2.6, Color("d8d1c1"))
			Iso.quad(g, o, ox + 0.3, oy + 3.25, 6.4, 0.5, 2.6, Color("d8d1c1"))
	# ruas
	var road := Color("4a4d55")
	for c in ROADS:
		var k: float = c - 0.5
		Iso.quad(g, o, 0, k, MAP, 1, 0, road)
		Iso.quad(g, o, k, 0, 1, MAP, 0, road)
	# linhas de borda das ruas
	for c in ROADS:
		var k: float = c - 0.5
		Iso.quad(g, o, 0, k + 0.06, MAP, 0.025, 0, Color(1, 1, 1, 0.35))
		Iso.quad(g, o, 0, k + 0.915, MAP, 0.025, 0, Color(1, 1, 1, 0.35))
		Iso.quad(g, o, k + 0.06, 0, 0.025, MAP, 0, Color(1, 1, 1, 0.35))
		Iso.quad(g, o, k + 0.915, 0, 0.025, MAP, 0, Color(1, 1, 1, 0.35))
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
				if kx - 0.4 > 0.0:
					Iso.quad(g, o, kx - 0.4, ky + q, 0.35, 0.09, 0, Color("f2f2f2"))
				if ky - 0.4 > 0.0:
					Iso.quad(g, o, kx + q, ky - 0.4, 0.09, 0.35, 0, Color("f2f2f2"))
	_draw_lot(g, o)


func _draw_lot(g, o: Vector2) -> void:
	var units := ceili(float(Game.surface_spots()) / (SPOTS_PER_ROW * 2))
	var pave_end := minf(LOT.end.y - 0.1, 21.4 + 3.0 * (units - 1))
	Iso.quad(g, o, LOT.position.x, LOT.position.y, LOT.size.x, LOT.size.y, 0, Color("5fb85a"))
	if pave_end < LOT.end.y - 0.3:
		# área de expansão (terra)
		for i in 12:
			Iso.quad(g, o, LOT.position.x + 0.6 + i * 1.2, pave_end + 0.25, 0.5, 0.1, 0, Color("f2a33a"))
	Iso.quad(g, o, LOT.position.x, LOT.position.y, LOT.size.x, pave_end - LOT.position.y, 0, Color("2f3238"))
	Iso.quad(g, o, LOT.position.x + 0.08, LOT.position.y, LOT.size.x - 0.16, pave_end - LOT.position.y - 0.08, 0, Color("43464e"))
	var yellow := Color("f2d23a")
	for i in Game.surface_spots():
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
