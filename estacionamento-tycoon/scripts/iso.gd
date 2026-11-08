extends RefCounted
## Projeção isométrica 2:1 e primitivas de desenho em "3D falso".
## Coordenadas de grade: x desce para a direita, y desce para a esquerda, z é altura em pixels.

const TW := 64.0
const TH := 32.0


static func p(x: float, y: float, z: float = 0.0) -> Vector2:
	return Vector2((x - y) * TW * 0.5, (x + y) * TH * 0.5 - z)


static func pg(g: Vector2, z: float = 0.0) -> Vector2:
	return p(g.x, g.y, z)


static func to_grid(s: Vector2) -> Vector2:
	var a := s.x / (TW * 0.5)
	var b := s.y / (TH * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Losango/retângulo plano na altura z. `o` é a origem (posição do nó) a subtrair.
static func quad(ci, o: Vector2, x0: float, y0: float, w: float, d: float, z: float, color: Color) -> void:
	if w <= 0.001 or d <= 0.001:
		return
	ci.draw_colored_polygon(PackedVector2Array([
		p(x0, y0, z) - o, p(x0 + w, y0, z) - o, p(x0 + w, y0 + d, z) - o, p(x0, y0 + d, z) - o]), color)


## Caixa com as duas faces visíveis e o topo, com sombreamento.
static func prism(ci, o: Vector2, x0: float, y0: float, w: float, d: float, z0: float, h: float, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	if w <= 0.001 or d <= 0.001:
		return
	var z1 := z0 + h
	if h > 0.01:
		var left := color
		var right := color.darkened(0.3)
		if h >= 6.0:
			# degradê: base mais escura (oclusão), topo mais claro
			var ao := clampf(h / 120.0, 0.12, 0.3)
			ci.draw_polygon(PackedVector2Array([
				p(x0, y0 + d, z0) - o, p(x0 + w, y0 + d, z0) - o, p(x0 + w, y0 + d, z1) - o, p(x0, y0 + d, z1) - o]),
				PackedColorArray([left.darkened(ao), left.darkened(ao), left.lightened(0.04), left.lightened(0.04)]))
			ci.draw_polygon(PackedVector2Array([
				p(x0 + w, y0, z0) - o, p(x0 + w, y0 + d, z0) - o, p(x0 + w, y0 + d, z1) - o, p(x0 + w, y0, z1) - o]),
				PackedColorArray([right.darkened(ao), right.darkened(ao), right.lightened(0.03), right.lightened(0.03)]))
			# brilho nas quinas de cima
			var hl := Color(1, 1, 1, 0.35)
			ci.draw_line(p(x0, y0 + d, z1) - o, p(x0 + w, y0 + d, z1) - o, hl, 1.0)
			ci.draw_line(p(x0 + w, y0 + d, z1) - o, p(x0 + w, y0, z1) - o, hl, 1.0)
			ci.draw_line(p(x0 + w, y0 + d, z0) - o, p(x0 + w, y0 + d, z1) - o, Color(1, 1, 1, 0.12), 1.0)
		else:
			ci.draw_colored_polygon(PackedVector2Array([
				p(x0, y0 + d, z0) - o, p(x0 + w, y0 + d, z0) - o, p(x0 + w, y0 + d, z1) - o, p(x0, y0 + d, z1) - o]), left)
			ci.draw_colored_polygon(PackedVector2Array([
				p(x0 + w, y0, z0) - o, p(x0 + w, y0 + d, z0) - o, p(x0 + w, y0 + d, z1) - o, p(x0 + w, y0, z1) - o]), right)
	quad(ci, o, x0, y0, w, d, z1, top if top.a > 0.0 else color.lightened(0.2))


## Sombra projetada no chão (para baixo-direita).
static func shadow(ci, o: Vector2, x0: float, y0: float, w: float, d: float, h: float) -> void:
	var s := minf(h / 40.0, 3.0)
	quad(ci, o, x0 + 0.05, y0 + 0.05, w + s * 0.6, d + s * 0.2, 0.0, Color(0, 0, 0, 0.1))
	quad(ci, o, x0 + 0.1, y0 + 0.1, w + s * 0.4, d + s * 0.1, 0.0, Color(0, 0, 0, 0.14))


## Janelas numa face. Face "y" = frente-esquerda (y = y0+d), face "x" = frente-direita (x = x0+w).
static func windows(ci, o: Vector2, x0: float, y0: float, w: float, d: float, z0: float, floors: int, floor_h: float, face: String, rng: RandomNumberGenerator, lit_chance: float, glass: Color) -> void:
	var length := w if face == "y" else d
	var cols := maxi(1, int(length * 2.2))
	var lit := Color("ffd970")
	var dark_mult := 0.0 if face == "y" else 0.25
	for f in floors:
		var za := z0 + f * floor_h + floor_h * 0.3
		var zb := z0 + f * floor_h + floor_h * 0.8
		for c in cols:
			var t0 := (c + 0.22) / cols
			var t1 := (c + 0.78) / cols
			var col := lit if rng.randf() < lit_chance else glass
			col = col.darkened(dark_mult)
			var a: Vector2
			var b: Vector2
			if face == "y":
				a = Vector2(x0 + w * t0, y0 + d)
				b = Vector2(x0 + w * t1, y0 + d)
			else:
				a = Vector2(x0 + w, y0 + d * t0)
				b = Vector2(x0 + w, y0 + d * t1)
			ci.draw_colored_polygon(PackedVector2Array([
				p(a.x, a.y, za) - o, p(b.x, b.y, za) - o, p(b.x, b.y, zb) - o, p(a.x, a.y, zb) - o]), col)
