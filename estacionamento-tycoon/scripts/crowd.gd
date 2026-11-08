extends Node2D
## Multidão: muitos pedestres andando pelas calçadas e atravessando nas faixas.
## Simulados aqui num só lugar e desenhados em lotes por quarteirão (2 camadas: atrás e na
## frente dos prédios), para a ordem de desenho ficar certa e o custo baixo.

const Iso := preload("res://scripts/iso.gd")
const Batch := preload("res://scripts/batch.gd")

const INSET := 0.16          # distância da calçada para a borda do quarteirão
const REDRAW_HZ := 20.0
const SKINS := [Color("f1c9a5"), Color("e0ac7e"), Color("c68a5c"), Color("8d5a3b"), Color("5e3a24")]
const PANTS := [Color("2b3550"), Color("3a3a3a"), Color("5a4632"), Color("23395d"), Color("6b6b6b")]

var perf_us := 0.0   # tempo médio de _process (microssegundos), para medição
var world = null
var rng := RandomNumberGenerator.new()
var peds: Array = []          # cada um: Dictionary
var open_blocks: Array = []   # quarteirões desbloqueados (Vector2i)
var layers := {}
var crossing: Array = []      # posições de quem está atravessando a rua agora (carros esperam)              # "bx,by,f" -> Node2D (f = 0 atrás, 1 na frente)
var _acc := 0.0
var _t := 0.0


func _ready() -> void:
	rng.randomize()
	z_index = 0


func refresh_blocks() -> void:
	open_blocks.clear()
	for b in world.block_district.keys():
		if world.block_district[b] < Game.districts_unlocked:
			open_blocks.append(b)
	_ensure_layers()
	var target := clampi(int(Game.population() / 120.0), 40, 320)
	while peds.size() < target and not open_blocks.is_empty():
		peds.append(_new_ped())
	while peds.size() > target:
		peds.pop_back()


func _ensure_layers() -> void:
	for b in open_blocks:
		for f in 2:
			var key := "%d,%d,%d" % [b.x, b.y, f]
			if layers.has(key):
				continue
			var n := Node2D.new()
			var ox: float = b.x * 8 + 1.0
			var oy: float = b.y * 8 + 1.0
			# camada de trás fica antes do quarteirão; a da frente, depois (y-sort)
			n.position = Iso.p(ox, oy) - Vector2(0, 2) if f == 0 else Iso.p(ox + 7.0, oy + 7.0) + Vector2(0, 2)
			n.set_meta("peds", [])
			n.draw.connect(_draw_layer.bind(n))
			world.objects.add_child(n)
			layers[key] = n


func _corner(b: Vector2i, k: int) -> Vector2:
	var ox: float = b.x * 8 + 1.0
	var oy: float = b.y * 8 + 1.0
	match k % 4:
		0:
			return Vector2(ox + INSET, oy + INSET)
		1:
			return Vector2(ox + 7.0 - INSET, oy + INSET)
		2:
			return Vector2(ox + 7.0 - INSET, oy + 7.0 - INSET)
	return Vector2(ox + INSET, oy + 7.0 - INSET)


func _new_ped() -> Dictionary:
	var b: Vector2i = open_blocks[rng.randi_range(0, open_blocks.size() - 1)]
	var k := rng.randi_range(0, 3)
	var dirn := 1 if rng.randf() < 0.5 else -1
	var a := _corner(b, k)
	var c := _corner(b, k + dirn + 4)
	return {
		"b": b, "k": k, "dir": dirn,
		"pos": a.lerp(c, rng.randf()), "to": c,
		"speed": rng.randf_range(0.28, 0.5),
		"shirt": Color.from_hsv(rng.randf(), rng.randf_range(0.45, 0.8), rng.randf_range(0.6, 0.95)),
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"pants": PANTS[rng.randi_range(0, PANTS.size() - 1)],
		"phase": rng.randf() * TAU,
		"cross": false,
		"lat": rng.randf_range(0.03, 0.11),
		"v": Vector2.ZERO,
	}


## Na esquina: segue pela calçada ou atravessa a rua na faixa para o quarteirão vizinho.
func _next_leg(p: Dictionary) -> void:
	var b: Vector2i = p.b
	if p.cross:
		p.cross = false
		p.k = p.next_k
		p.b = p.next_b
		b = p.b
	else:
		p.k = (int(p.k) + int(p.dir) + 4) % 4
		if rng.randf() < 0.3:
			# vizinho na direção da esquina atual
			var k: int = p.k
			var offs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
			var side := k if rng.randf() < 0.5 else (k + 3) % 4
			var nb: Vector2i = b + offs[side]
			if open_blocks.has(nb):
				var here := _corner(b, k)
				# canto equivalente do vizinho
				var nk := k
				if side == 0:
					nk = 3 if k == 0 else 2
				elif side == 1:
					nk = 0 if k == 1 else 3
				elif side == 2:
					nk = 1 if k == 2 else 0
				else:
					nk = 2 if k == 3 else 1
				p.cross = true
				p.next_b = nb
				p.next_k = nk
				p.to = _corner(nb, nk)
				p.pos = here
				# espera o sinal na esquina antes de atravessar
				p.wait = true
				p.along_x = absf((p.to as Vector2).x - here.x) > absf((p.to as Vector2).y - here.y)
				return
	p.to = _corner(b, int(p.k) + int(p.dir) + 4)


func _process(delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_us = perf_us * 0.95 + float(Time.get_ticks_usec() - _t0) * 0.05


func _process_inner(delta: float) -> void:
	if world == null:
		return
	_t += delta
	for p in peds:
		if p.get("wait", false):
			if world.ped_can_cross(bool(p.along_x)):
				p.wait = false
			else:
				continue
		var to: Vector2 = p.to
		var pos: Vector2 = p.pos
		var d := pos.distance_to(to)
		var step: float = p.speed * delta
		if d <= step:
			p.pos = to
			_next_leg(p)
		else:
			p.v = (to - pos) / d
			p.pos = pos + p.v * step
	crossing.clear()
	for p in peds:
		if p.cross and not p.get("wait", false):
			crossing.append(p.pos)
	_acc += delta
	if _acc < 1.0 / REDRAW_HZ:
		return
	_acc = 0.0
	if not world.camera or world.camera.zoom.x < 0.32:
		for key in layers.keys():
			var n: Node2D = layers[key]
			if not (n.get_meta("peds") as Array).is_empty():
				n.set_meta("peds", [])
				n.queue_redraw()
		return
	# distribui os pedestres nas camadas (atrás/na frente do quarteirão)
	var buckets := {}
	for p in peds:
		var b: Vector2i = p.b
		var pos: Vector2 = p.pos
		var ox: float = b.x * 8 + 1.0
		var oy: float = b.y * 8 + 1.0
		var front := 1 if (pos.x - ox) + (pos.y - oy) > 7.0 or p.cross else 0
		var key := "%d,%d,%d" % [b.x, b.y, front]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(p)
	for key in layers.keys():
		var n: Node2D = layers[key]
		var list: Array = buckets.get(key, [])
		if list.is_empty() and (n.get_meta("peds") as Array).is_empty():
			continue
		n.set_meta("peds", list)
		n.queue_redraw()


func _draw_layer(n: Node2D) -> void:
	var list: Array = n.get_meta("peds")
	if list.is_empty():
		return
	var b = Batch.new()
	for p in list:
		# cada um anda do seu lado (mão direita), sem se atravessar com quem vem no sentido oposto
		var v: Vector2 = p.v
		var gp: Vector2 = p.pos + Vector2(-v.y, v.x) * float(p.lat)
		var c := Iso.pg(gp, 2.6) - n.position
		var leg := 1.4 if sin(_t * 9.0 + float(p.phase)) > 0.0 else -1.4
		var shirt: Color = p.shirt
		var skin: Color = p.skin
		var pants: Color = p.pants
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(3, 0), c + Vector2(3, 1.4), c + Vector2(-3, 1.4)]), Color(0, 0, 0, 0.22))
		b.draw_line(c + Vector2(-1, 0), c + Vector2(-1 + leg * 0.5, -5), pants, 1.6)
		b.draw_line(c + Vector2(1, 0), c + Vector2(1 - leg * 0.5, -5), pants, 1.6)
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, -11), c + Vector2(2.6, -11), c + Vector2(2.6, -5), c + Vector2(-2.6, -5)]), shirt)
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(0.6, -11), c + Vector2(2.6, -11), c + Vector2(2.6, -5), c + Vector2(0.6, -5)]), shirt.darkened(0.2))
		b.draw_circle(c + Vector2(0, -13), 2.2, skin)
	b.flush(n.get_canvas_item())
