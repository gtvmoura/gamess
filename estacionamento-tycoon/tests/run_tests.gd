extends SceneTree
## Testes da economia. Rodar com:
##   godot --headless --path . --script res://tests/run_tests.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok    ", msg)
	else:
		failures += 1
		printerr("  FALHA ", msg)


func _initialize() -> void:
	print("== Testes Estacionamento Tycoon ==")
	for path in ["res://scripts/game_state.gd", "res://scripts/car.gd"]:
		var s = load(path)
		check(s != null and s.can_instantiate(), "script compila: " + path)

	var GameScript = load("res://scripts/game_state.gd")
	var g = GameScript.new()

	# Formatação
	check(g.int_str(54320) == "54.320", "int_str 54.320 -> " + g.int_str(54320))
	check(g.int_str(999) == "999", "int_str 999")
	check(g.money_str(1500000.0) == "R$ 1,50 mi", "money_str milhão -> " + g.money_str(1500000.0))
	check(g.price_str(8.0) == "R$ 8,00", "price_str")

	# Estado inicial
	check(g.spots() == 10, "começa com 10 vagas")
	check(is_equal_approx(g.price(), 8.0), "começa cobrando R$ 8/h")
	check(g.phase_name() == "Cidade Inicial", "começa como Cidade Inicial")
	check(g.income_per_hour() > 0.0, "renda inicial positiva: %s/h" % g.money_str(g.income_per_hour()))

	# Preço alto sem atratividade espanta clientes
	var base_chance: float = g.enter_chance()
	g.lvl.price = 5
	check(g.enter_chance() < base_chance, "preço alto reduz a chance de entrada")
	g.lvl.price = 0
	g.lvl.attract = 3
	check(g.enter_chance() > base_chance, "atratividade aumenta a chance de entrada")
	g.lvl.attract = 0

	# Compra de melhorias
	g.money = 100.0
	check(not g.buy_upgrade("spots"), "não compra sem dinheiro")
	g.money = 1000.0
	var cost: float = g.upgrade_cost("spots")
	check(g.buy_upgrade("spots"), "compra melhoria de vagas")
	check(g.spots() == 15, "vagas 10 -> 15")
	check(is_equal_approx(g.money, 1000.0 - cost), "desconta o custo")
	check(g.upgrade_cost("spots") > cost, "custo sobe a cada nível")

	# Bairros
	var pop_before: float = g.population()
	g.money = 20000.0
	check(g.buy_next_district(), "desbloqueia Vila Nova")
	check(g.population() > pop_before, "bairro aumenta a população")
	check(g.district_income_mult() > 1.0, "bairro aumenta a receita")

	# Progressão até a Metrópole é possível
	g.lvl.city = int(g.UPGRADES.city.max)
	g.districts_unlocked = g.DISTRICTS.size()
	check(g.phase_name() == "Metrópole", "dá para virar Metrópole (pop %s)" % g.int_str(g.population()))

	# Vagas limitam a receita
	g.lvl.fleet = int(g.UPGRADES.fleet.max)
	var capacity: float = float(g.spots()) / g.AVG_STAY_SECONDS
	check(g.arrivals_per_sec() > capacity, "cidade grande lota o estacionamento")
	var inc1: float = g.expected_income_per_sec()
	g.lvl.spots = int(g.lvl.spots) + 1
	check(g.expected_income_per_sec() > inc1, "mais vagas = mais receita quando lotado")

	# Missões e XP
	g.total_cars = 10
	check(g.mission_done(0), "missão 'estacione 10 carros' concluída")
	var gems_before: int = g.gems
	check(g.claim_mission(0), "coleta missão")
	check(g.gems > gems_before, "missão dá gemas")
	check(not g.claim_mission(0), "não coleta duas vezes")
	var lv: int = g.level
	g.add_xp(10000.0)
	check(g.level > lv, "XP sobe de nível")

	# Save / load
	var d: Dictionary = g.to_dict()
	var parsed = JSON.parse_string(JSON.stringify(d))
	var g2 = GameScript.new()
	g2.from_dict(parsed)
	check(g2.spots() == g.spots(), "save mantém vagas")
	check(g2.districts_unlocked == g.districts_unlocked, "save mantém bairros")
	check(g2.missions_claimed.has(0), "save mantém missões")
	check(is_equal_approx(g2.money, g.money), "save mantém dinheiro")

	g.free()
	g2.free()
	print("== %d falha(s) ==" % failures)
	quit(1 if failures > 0 else 0)
