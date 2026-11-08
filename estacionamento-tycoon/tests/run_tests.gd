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
	for path in ["res://scripts/game_state.gd", "res://scripts/car.gd", "res://scripts/iso.gd", "res://scripts/batch.gd", "res://scripts/prop.gd", "res://scripts/walker.gd", "res://scripts/camera.gd"]:
		var s = load(path)
		check(s != null and s.can_instantiate(), "script compila: " + path)

	if failures > 0:
		printerr("Scripts com erro de compilação; abortando.")
		quit(1)
		return
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
	g.set_price(13.0)
	check(g.enter_chance() < base_chance, "preço alto reduz a chance de entrada")
	var high_chance: float = g.enter_chance()
	g.lvl.comfort = 10
	check(g.enter_chance() > high_chance, "segurança e conforto reduzem a rejeição ao preço")
	g.lvl.comfort = 0
	g.set_price(8.0)
	g.set_price(0.1)
	check(is_equal_approx(g.price(), g.MIN_PRICE), "preço tem mínimo")
	g.set_price(8.0)
	var bp: float = g.best_price()
	check(g.expected_income_at(bp) >= g.expected_income_at(8.0), "preço ideal rende pelo menos o atual (%s)" % g.price_str(bp))
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
	var pop_before: float = g.housing()
	g.money = 20000.0
	check(g.buy_next_district(), "desbloqueia Vila Nova")
	check(g.housing() > pop_before, "bairro aumenta a moradia")
	check(g.district_income_mult() > 1.0, "bairro aumenta a receita")

	# Pesquisa
	g.money = 100000.0
	var inc_before: float = g.income_mult()
	check(g.start_research("digital"), "inicia pesquisa")
	check(not g.start_research("marketing"), "só uma pesquisa por vez")
	check(g.research_active(), "pesquisa ativa")
	g.check_research(g.research_end - 1.0)
	check(g.research_active(), "não termina antes do tempo")
	g.check_research(g.research_end + 1.0)
	check(not g.research_active() and g.rlvl("digital") == 1, "pesquisa conclui depois do tempo")
	check(g.income_mult() > inc_before, "cobrança digital aumenta a receita")
	check(g.research_cost("digital") > 2000.0, "pesquisa fica mais cara")
	g.gems = 100
	check(g.start_research("valet"), "inicia manobristas")
	check(g.rush_research() and g.rlvl("valet") == 1, "acelera com gemas")
	check(g.stay_factor() < 1.0, "manobristas diminuem o tempo de permanência")

	# Serviços e funcionários
	g.money = 1000000.0
	var v0: float = g.expected_income_per_sec()
	check(g.buy_service("wash"), "constrói lava-rápido")
	check(g.service_chance("wash") > 0.0, "lava-rápido tem clientes")
	check(g.service_efficiency("wash") < 1.0, "sem lavador funciona parcialmente")
	check(g.hire("washer"), "contrata lavador")
	check(is_equal_approx(g.service_efficiency("wash"), 1.0), "com lavador funciona 100%")
	check(g.expected_income_per_sec() > v0, "serviços aumentam a receita esperada")
	var rr := RandomNumberGenerator.new()
	rr.seed = 1
	var got := 0.0
	for i in 200:
		for e in g.roll_services(rr):
			got += float(e[1])
	check(got > 0.0, "clientes usam serviços (%s em 200 saídas)" % g.money_str(got))
	check(g.salary_per_hour() > 0.0, "funcionário tem salário")
	var m0: float = g.money
	g._simulate(60.0)
	check(g.money < m0 + 0.001, "salário é descontado com o tempo")
	var sf: float = g.stay_factor()
	g.hire("valet")
	check(g.stay_factor() < sf, "manobrista acelera o giro")
	check(g.fire("valet") and g.staff_count("valet") == 0, "demite funcionário")

	# Avaliação e conquistas
	var tr0: float = g.target_rating()
	for i in 30:
		g.note_lost_customer()
	check(g.target_rating() < tr0, "clientes perdidos (lotado) derrubam a avaliação")
	g.rating = 5.0
	var ch5: float = g.enter_chance()
	g.rating = 1.0
	check(g.enter_chance() < ch5, "avaliação baixa reduz a entrada")
	g.rating = 3.5
	g.total_cars = maxi(g.total_cars, 1)
	g.check_achievements()
	check(g.achievements.has("first"), "conquista do primeiro cliente")
	var gems_a: int = g.gems
	g.check_achievements()
	check(g.gems == gems_a, "conquista não paga duas vezes")

	# Moradores x empregos
	g.lvl.city = 10
	g.lvl.jobs = 0
	check(g.target_population() < g.housing() * 0.9, "sem empregos a cidade não enche as moradias")
	g.lvl.jobs = 12
	check(is_equal_approx(g.target_population(), g.housing()), "com empregos a cidade enche as moradias")
	var p0: float = g.population()
	g._simulate(30.0)
	check(g.population() > p0 and g.population() < g.target_population(), "moradores chegam aos poucos (%s)" % g.int_str(g.population()))
	g.settle_population()
	check(g.employed() <= g.jobs() and g.employed() <= g.working_age(), "empregados limitados por vagas e moradores")
	var jobs_before: float = g.employed()
	g.lvl.jobs = 4
	check(g.employed() < jobs_before, "menos empresas = menos trabalhadores")

	# Ciclo do dia
	var mean := 0.0
	for h in 24:
		g.hour = float(h)
		mean += g.commute_mult() / 24.0
	check(absf(mean - 1.0) < 0.05, "curva de trânsito tem média ~1 (%.2f)" % mean)
	g.hour = 8.0
	var rush: float = g.work_traffic()
	g.hour = 3.0
	check(g.work_traffic() < rush * 0.1, "madrugada tem bem menos trabalhadores que a hora do rush")
	check(g.moment_str() == "Madrugada tranquila", "texto da madrugada")
	g.hour = 8.0
	check(g.moment_str() == "Hora do rush!", "texto da hora do rush")
	g._simulate(g.DAY_SECONDS)
	check(g.day == 2, "o dia vira depois de DAY_SECONDS")

	# Progressão até a Metrópole é possível
	g.lvl.city = int(g.UPGRADES.city.max)
	g.lvl.jobs = int(g.UPGRADES.jobs.max)
	g.districts_unlocked = g.DISTRICTS.size()
	g.settle_population()
	check(g.phase_name() == "Metrópole", "dá para virar Metrópole (pop %s)" % g.int_str(g.population()))

	# Vagas limitam a receita
	g.lvl.fleet = int(g.UPGRADES.fleet.max)
	g.hour = 8.0
	var capacity: float = float(g.spots()) / g.STAY_SHOP_SECONDS
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
	check(is_equal_approx(g2.population(), g.population()), "save mantém moradores")
	check(g2.day == g.day, "save mantém o dia")
	check(g2.rlvl("digital") == 1, "save mantém pesquisas")
	check(g2.achievements.has("first"), "save mantém conquistas")
	check(g2.service_lvl("wash") == 1 and g2.staff_count("washer") == 1, "save mantém serviços e funcionários")
	check(is_equal_approx(g2.price(), g.price()), "save mantém o preço")
	check(g2.districts_unlocked == g.districts_unlocked, "save mantém bairros")
	check(g2.missions_claimed.has(0), "save mantém missões")
	check(is_equal_approx(g2.money, g.money), "save mantém dinheiro")

	g.free()
	g2.free()
	print("== %d falha(s) ==" % failures)
	quit(1 if failures > 0 else 0)
