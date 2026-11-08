extends Node
## Estado global do jogo (autoload "Game"): economia, progressão, missões e save.

signal changed
signal leveled_up(new_level: int)
signal notify(text: String)

const SAVE_PATH := "user://save.json"
const SAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const OFFLINE_EFFICIENCY := 0.5
## Trabalhadores ficam muito tempo e pagam várias horas; compradores ficam pouco.
const STAY_WORK_SECONDS := 24.0
const STAY_SHOP_SECONDS := 10.0
const HOURS_WORK := 6.0
const HOURS_SHOP := 1.5
## Duração de um dia do jogo, em segundos reais.
const DAY_SECONDS := 360.0
## Fração dos moradores em idade de trabalhar.
const WORKING_AGE := 0.6
## Movimento por hora do dia (0h..23h). Normalizado para média 1.
const COMMUTE_CURVE := [0.05, 0.05, 0.05, 0.05, 0.1, 0.4, 1.4, 3.2, 3.4, 1.8, 0.9, 0.7, 0.9, 0.8, 0.6, 0.6, 0.7, 0.9, 0.6, 0.3, 0.2, 0.15, 0.1, 0.05]
const SHOP_CURVE := [0.1, 0.05, 0.05, 0.05, 0.05, 0.1, 0.2, 0.4, 0.6, 0.9, 1.3, 1.6, 2.0, 1.8, 1.5, 1.5, 1.6, 1.9, 2.2, 2.0, 1.5, 0.9, 0.4, 0.2]
const BOOST_GEMS := 30
const BOOST_SECONDS := 600.0

## Pesquisas: custam dinheiro, levam tempo (uma por vez) e dão bônus permanentes.
const RESEARCH := {
	"digital": {"name": "Cobrança Digital", "desc": "+10% de receita por nível.", "base": 2000.0, "time": 40.0, "max": 10},
	"marketing": {"name": "Marketing", "desc": "+8% de chance de um motorista entrar, por nível.", "base": 1500.0, "time": 35.0, "max": 10},
	"valet": {"name": "Manobristas", "desc": "Carros giram 12% mais rápido: mais clientes por vaga.", "base": 4000.0, "time": 60.0, "max": 8},
	"loyalty": {"name": "Fidelização", "desc": "Clientes rejeitam menos preços altos.", "base": 3000.0, "time": 50.0, "max": 8},
	"contracts": {"name": "Convênios com Empresas", "desc": "Trabalhadores aceitam +R$ 1,50 no preço justo, por nível.", "base": 5000.0, "time": 70.0, "max": 10},
	"urban": {"name": "Planejamento Urbano", "desc": "+10% de moradia na cidade, por nível.", "base": 6000.0, "time": 80.0, "max": 10},
	"business": {"name": "Incentivo a Empresas", "desc": "+10% de empregos na cidade, por nível.", "base": 6000.0, "time": 80.0, "max": 10},
	"remote": {"name": "Gestão Remota", "desc": "+10% de renda enquanto o jogo está fechado, por nível.", "base": 2500.0, "time": 45.0, "max": 5},
}
const RESEARCH_GROWTH := 2.1
const MIN_PRICE := 1.0
const MAX_PRICE := 250.0

const UPGRADES := {
	"spots": {"name": "Mais Vagas", "desc": "Aumenta a capacidade do estacionamento.", "base": 150.0, "growth": 1.55, "max": 30},
	"attract": {"name": "Atratividade", "desc": "Lojas, segurança e cobertura atraem mais motoristas e permitem cobrar mais.", "base": 250.0, "growth": 1.7, "max": 25},
	"comfort": {"name": "Segurança e Conforto", "desc": "Câmeras, seguranças e banheiros: clientes aceitam pagar mais e rejeitam menos o preço.", "base": 300.0, "growth": 1.72, "max": 25},
	"fleet": {"name": "Frota de Veículos", "desc": "Concessionárias na cidade: mais moradores compram carros.", "base": 400.0, "growth": 1.75, "max": 20},
	"city": {"name": "Moradias", "desc": "Novas casas e prédios residenciais: mais gente pode morar na cidade.", "base": 1000.0, "growth": 1.85, "max": 30},
	"jobs": {"name": "Atrair Empresas", "desc": "Lojas, escritórios e fábricas: empregos trazem moradores e trabalhadores.", "base": 700.0, "growth": 1.8, "max": 30},
}

const DISTRICTS := [
	{"name": "Centro", "cost": 0.0, "pop": 1.0, "jobs": 1.0, "income": 0.0, "desc": "Onde tudo começou."},
	{"name": "Vila Nova", "cost": 15000.0, "pop": 0.8, "jobs": 0.2, "income": 0.25, "desc": "Bairro residencial + novo estacionamento."},
	{"name": "Jardim das Flores", "cost": 90000.0, "pop": 0.6, "jobs": 0.6, "income": 0.5, "desc": "Comércio local e praças."},
	{"name": "Distrito Industrial", "cost": 500000.0, "pop": 0.3, "jobs": 2.0, "income": 1.0, "desc": "Fábricas: muitos empregos e trabalhadores motorizados."},
	{"name": "Beira-Rio", "cost": 3000000.0, "pop": 1.5, "jobs": 0.8, "income": 2.0, "desc": "Orla turística com shopping."},
	{"name": "Centro Financeiro", "cost": 20000000.0, "pop": 1.5, "jobs": 3.5, "income": 4.0, "desc": "Arranha-céus e escritórios lotados."},
	{"name": "Aeroporto", "cost": 150000000.0, "pop": 1.0, "jobs": 5.0, "income": 8.0, "desc": "Milhares de empregos e o maior estacionamento da região."},
]

const PHASES := [
	{"name": "Cidade Inicial", "min_pop": 0.0},
	{"name": "Cidade em Crescimento", "min_pop": 6000.0},
	{"name": "Metrópole", "min_pop": 60000.0},
]

const MISSIONS := [
	{"text": "Estacione 10 carros", "type": "cars", "goal": 10.0, "money": 300.0, "gems": 5},
	{"text": "Compre 2 melhorias de vagas", "type": "lvl_spots", "goal": 2.0, "money": 500.0, "gems": 5},
	{"text": "Atratividade no nível 3", "type": "lvl_attract", "goal": 2.0, "money": 800.0, "gems": 5},
	{"text": "Construa moradias 2 vezes", "type": "lvl_city", "goal": 2.0, "money": 2000.0, "gems": 10},
	{"text": "Atraia empresas 2 vezes", "type": "lvl_jobs", "goal": 2.0, "money": 2500.0, "gems": 10},
	{"text": "Conclua 3 pesquisas", "type": "research", "goal": 3.0, "money": 6000.0, "gems": 15},
	{"text": "Tenha 2.000 trabalhadores empregados", "type": "employed", "goal": 2000.0, "money": 8000.0, "gems": 15},
	{"text": "Estacione 100 carros", "type": "cars", "goal": 100.0, "money": 3000.0, "gems": 10},
	{"text": "Desbloqueie a Vila Nova", "type": "districts", "goal": 2.0, "money": 5000.0, "gems": 15},
	{"text": "Alcance 6.000 habitantes", "type": "pop", "goal": 6000.0, "money": 20000.0, "gems": 20},
	{"text": "Tenha 50 vagas", "type": "spots", "goal": 50.0, "money": 50000.0, "gems": 20},
	{"text": "Estacione 1.000 carros", "type": "cars", "goal": 1000.0, "money": 100000.0, "gems": 25},
	{"text": "Fature R$ 1 milhão no total", "type": "earned", "goal": 1000000.0, "money": 250000.0, "gems": 30},
	{"text": "Desbloqueie 4 bairros", "type": "districts", "goal": 4.0, "money": 1000000.0, "gems": 40},
	{"text": "Torne-se uma Metrópole", "type": "pop", "goal": 60000.0, "money": 5000000.0, "gems": 60},
	{"text": "Fature R$ 1 bilhão no total", "type": "earned", "goal": 1000000000.0, "money": 50000000.0, "gems": 100},
]

var money: float = 500.0
var gems: int = 20
var level: int = 1
var xp: float = 0.0
var lvl := {"spots": 0, "attract": 0, "comfort": 0, "fleet": 0, "city": 0, "jobs": 0}
## Moradores atuais (crescem aos poucos até a meta definida por moradia e empregos).
var pop: float = 1000.0
var day: int = 1
var hour: float = 8.0
var districts_unlocked: int = 1
var total_cars: int = 0
var lost_customers: int = 0
var total_earned: float = 0.0
var boost_until: float = 0.0
var missions_claimed: Array = []
## Preço por hora escolhido pelo jogador.
var price_value: float = 8.0
var research_lvl := {}
var research_key := ""
var research_end := 0.0

## Vagas ocupadas agora (atualizado pela cena do estacionamento).
var occupied: int = 0
## Dinheiro acumulado enquanto o jogador estava fora (aguardando coleta).
var offline_pending: float = 0.0
var offline_seconds: float = 0.0

var _save_timer := 0.0


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	_simulate(delta)
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# ---------------------------------------------------------------- Economia

func spots() -> int:
	return 10 + 5 * int(lvl.spots)


func price() -> float:
	return price_value


func set_price(v: float) -> void:
	price_value = clampf(snappedf(v, 0.5), MIN_PRICE, MAX_PRICE)
	changed.emit()


func rlvl(key: String) -> int:
	return int(research_lvl.get(key, 0))


func attract_level() -> int:
	return int(lvl.attract) + 1


func vehicles_per_resident() -> float:
	return 0.25 + 0.05 * float(lvl.fleet)


func population() -> float:
	return pop


## Quantas pessoas cabem nas moradias da cidade.
func housing() -> float:
	return 1200.0 * pow(1.3, float(lvl.city)) * district_pop_mult() * (1.0 + 0.1 * rlvl("urban"))


func jobs() -> float:
	return 600.0 * pow(1.3, float(lvl.get("jobs", 0))) * district_jobs_mult() * (1.0 + 0.1 * rlvl("business"))


func district_jobs_mult() -> float:
	var m := 0.0
	for i in districts_unlocked:
		m += float(DISTRICTS[i].jobs)
	return m


func working_age() -> float:
	return pop * WORKING_AGE


func employed() -> float:
	return minf(working_age(), jobs())


func unemployment() -> float:
	var w := working_age()
	return 0.0 if w <= 0.0 else 1.0 - employed() / w


## Vagas de emprego preenchidas (empresas cheias = mais trabalhadores no centro).
func jobs_filled() -> float:
	var j := jobs()
	return 0.0 if j <= 0.0 else employed() / j


## Meta de população: precisa de moradia, e só vem gente se houver emprego.
func target_population() -> float:
	var h := housing()
	return minf(h, h * 0.45 + jobs() / WORKING_AGE * 0.8)


func settle_population() -> void:
	pop = target_population()


func _simulate(delta: float) -> void:
	check_research(Time.get_unix_time_from_system())
	var target := target_population()
	pop += (target - pop) * (1.0 - exp(-delta / 40.0))
	hour += delta * 24.0 / DAY_SECONDS
	if hour >= 24.0:
		hour -= 24.0
		day += 1


static func _curve(curve: Array, h: float) -> float:
	var total := 0.0
	for v in curve:
		total += float(v)
	var mean := total / curve.size()
	var i := int(floor(h)) % 24
	var j := (i + 1) % 24
	var t := h - floorf(h)
	return lerpf(float(curve[i]), float(curve[j]), t) / mean


func commute_mult() -> float:
	return _curve(COMMUTE_CURVE, hour)


func shop_mult() -> float:
	return _curve(SHOP_CURVE, hour)


func clock_str() -> String:
	var m := int((hour - floor(hour)) * 60.0)
	return "Dia %d  %02d:%02d" % [day, int(hour), m]


func moment_str() -> String:
	if hour < 5.5 or hour >= 22.0:
		return "Madrugada tranquila"
	if commute_mult() > 1.6:
		return "Hora do rush!"
	if shop_mult() > 1.5:
		return "Comércio cheio"
	return "Movimento normal"


func district_pop_mult() -> float:
	var m := 0.0
	for i in districts_unlocked:
		m += float(DISTRICTS[i].pop)
	return m


## Renda extra dos estacionamentos construídos nos bairros novos.
func district_income_mult() -> float:
	var m := 1.0
	for i in districts_unlocked:
		m += float(DISTRICTS[i].income)
	return m


func phase_index() -> int:
	var p := population()
	var idx := 0
	for i in PHASES.size():
		if p >= float(PHASES[i].min_pop):
			idx = i
	return idx


func phase_name() -> String:
	return PHASES[phase_index()].name


## Preço que os motoristas acham "justo": sobe com atratividade e riqueza da cidade.
func fair_price() -> float:
	return 8.0 + 1.2 * float(lvl.attract) + 0.25 * float(lvl.city) + 0.9 * float(lvl.get("comfort", 0)) + 1.5 * rlvl("contracts")


## Quanto o cliente "sente" o preço acima do justo (maior = rejeita mais).
func price_sensitivity() -> float:
	return clampf(2.2 - 0.05 * float(lvl.get("comfort", 0)) - 0.1 * rlvl("loyalty"), 0.8, 3.0)


## Fração de motoristas que aceitam o preço (1 = preço justo).
func price_acceptance(p: float = -1.0) -> float:
	if p <= 0.0:
		p = price()
	return pow(fair_price() / p, price_sensitivity())


## Carros de trabalhadores indo para o centro (média do dia).
func work_traffic_avg() -> float:
	return employed() * vehicles_per_resident() * 0.0024


## Carros de moradores indo às compras/lazer (média do dia).
func shop_traffic_avg() -> float:
	return pop * vehicles_per_resident() * 0.0008


func work_traffic() -> float:
	return work_traffic_avg() * commute_mult()


func shop_traffic() -> float:
	return shop_traffic_avg() * shop_mult()


## Carros por segundo passando na frente do estacionamento agora.
func passing_per_sec() -> float:
	return work_traffic() + shop_traffic()


## Chance de um carro que passa decidir entrar.
func enter_chance() -> float:
	return enter_chance_at(price())


func enter_chance_at(p: float) -> float:
	var base := (0.35 + 0.05 * float(lvl.attract)) * (1.0 + 0.08 * rlvl("marketing"))
	return clampf(base * price_acceptance(p), 0.005, 0.95)


func arrivals_per_sec() -> float:
	return passing_per_sec() * enter_chance()


func work_arrivals_per_sec() -> float:
	return work_traffic() * enter_chance()


func shop_arrivals_per_sec() -> float:
	return shop_traffic() * enter_chance()


func income_mult() -> float:
	var m := district_income_mult()
	m *= 1.0 + 0.1 * rlvl("digital")
	if is_boosted():
		m *= 2.0
	return m


## Multiplicador do tempo de permanência (manobristas fazem girar mais rápido).
func stay_factor() -> float:
	return 1.0 / (1.0 + 0.12 * rlvl("valet"))


## Receita esperada por segundo (usada para renda offline e para o HUD).
func expected_income_per_sec() -> float:
	return expected_income_at(price())


func expected_income_at(p: float) -> float:
	var chance := enter_chance_at(p)
	var w := work_traffic_avg() * chance
	var sh := shop_traffic_avg() * chance
	var total := w + sh
	if total <= 0.0:
		return 0.0
	var avg_stay := (w * STAY_WORK_SECONDS + sh * STAY_SHOP_SECONDS) / total * stay_factor()
	var avg_hours := (w * HOURS_WORK + sh * HOURS_SHOP) / total
	var served := minf(total, float(spots()) / avg_stay)
	return served * p * avg_hours * income_mult()


## Preço que dá a maior receita esperada (busca simples).
func best_price() -> float:
	var best := price()
	var best_inc := -1.0
	var p := MIN_PRICE
	while p <= MAX_PRICE:
		var inc := expected_income_at(p)
		if inc > best_inc:
			best_inc = inc
			best = p
		p += 0.5 if p < 40.0 else 2.0
	return best


# ---------------------------------------------------------------- Pesquisa

func research_cost(key: String) -> float:
	return floor(float(RESEARCH[key].base) * pow(RESEARCH_GROWTH, float(rlvl(key))))


func research_time(key: String) -> float:
	return float(RESEARCH[key].time) * (1.0 + 0.6 * rlvl(key))


func research_maxed(key: String) -> bool:
	return rlvl(key) >= int(RESEARCH[key].max)


func research_active() -> bool:
	return research_key != ""


func can_start_research(key: String) -> bool:
	return not research_active() and not research_maxed(key) and money >= research_cost(key)


func start_research(key: String) -> bool:
	if not can_start_research(key):
		return false
	money -= research_cost(key)
	research_key = key
	research_end = Time.get_unix_time_from_system() + research_time(key)
	changed.emit()
	save_game()
	return true


func research_left(now: float = -1.0) -> float:
	if not research_active():
		return 0.0
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return maxf(0.0, research_end - now)


func research_progress() -> float:
	if not research_active():
		return 0.0
	var total := research_time(research_key)
	return clampf(1.0 - research_left() / total, 0.0, 1.0)


func rush_cost() -> int:
	return maxi(1, ceili(research_left() / 20.0))


func rush_research() -> bool:
	if not research_active() or gems < rush_cost():
		return false
	gems -= rush_cost()
	research_end = 0.0
	check_research(Time.get_unix_time_from_system())
	return true


## Conclui a pesquisa ativa se o tempo já passou.
func check_research(now: float) -> void:
	if research_active() and now >= research_end:
		var key := research_key
		research_lvl[key] = rlvl(key) + 1
		research_key = ""
		add_xp(15.0 * rlvl(key))
		notify.emit("Pesquisa concluída: %s nível %d!" % [RESEARCH[key].name, rlvl(key)])
		changed.emit()
		save_game()


func research_total() -> int:
	var n := 0
	for k in research_lvl.keys():
		n += int(research_lvl[k])
	return n


func income_per_hour() -> float:
	return expected_income_per_sec() * 3600.0


func is_boosted() -> bool:
	return Time.get_unix_time_from_system() < boost_until


func boost_seconds_left() -> float:
	return maxf(0.0, boost_until - Time.get_unix_time_from_system())


# ---------------------------------------------------------------- Ações

func upgrade_cost(key: String) -> float:
	var u: Dictionary = UPGRADES[key]
	return floor(float(u.base) * pow(float(u.growth), float(lvl[key])))


func upgrade_maxed(key: String) -> bool:
	return int(lvl[key]) >= int(UPGRADES[key].max)


func can_buy_upgrade(key: String) -> bool:
	return not upgrade_maxed(key) and money >= upgrade_cost(key)


func buy_upgrade(key: String) -> bool:
	if not can_buy_upgrade(key):
		return false
	money -= upgrade_cost(key)
	lvl[key] = int(lvl[key]) + 1
	add_xp(5.0 + float(lvl[key]))
	changed.emit()
	save_game()
	return true


func next_district_cost() -> float:
	if districts_unlocked >= DISTRICTS.size():
		return -1.0
	return float(DISTRICTS[districts_unlocked].cost)


func buy_next_district() -> bool:
	var cost := next_district_cost()
	if cost < 0.0 or money < cost:
		return false
	money -= cost
	var d: Dictionary = DISTRICTS[districts_unlocked]
	districts_unlocked += 1
	gems += 10
	add_xp(50.0 * districts_unlocked)
	notify.emit("Bairro %s desbloqueado! +10 gemas" % d.name)
	changed.emit()
	save_game()
	return true


func buy_boost() -> bool:
	if gems < BOOST_GEMS:
		return false
	gems -= BOOST_GEMS
	boost_until = maxf(boost_until, Time.get_unix_time_from_system()) + BOOST_SECONDS
	notify.emit("Receita em dobro por 10 minutos!")
	changed.emit()
	save_game()
	return true


## Chamado pela cena quando um carro sai e paga. Retorna o valor final recebido.
func car_paid(base_amount: float) -> float:
	var amount := base_amount * income_mult()
	money += amount
	total_earned += amount
	changed.emit()
	return amount


func car_parked() -> void:
	total_cars += 1
	add_xp(1.0)


func xp_needed() -> float:
	return floor(10.0 * pow(float(level), 1.5))


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gems += 5
		leveled_up.emit(level)
		notify.emit("Nível %d! +5 gemas" % level)
	changed.emit()


func collect_offline(double: bool) -> void:
	if offline_pending <= 0.0:
		return
	if double:
		if gems < 10:
			return
		gems -= 10
	var amount := offline_pending * (2.0 if double else 1.0)
	money += amount
	total_earned += amount
	offline_pending = 0.0
	changed.emit()
	save_game()


# ---------------------------------------------------------------- Missões

func mission_progress(i: int) -> float:
	var m: Dictionary = MISSIONS[i]
	match String(m.type):
		"cars":
			return float(total_cars)
		"lvl_spots":
			return float(lvl.spots)
		"lvl_attract":
			return float(lvl.attract)
		"lvl_city":
			return float(lvl.city)
		"lvl_jobs":
			return float(lvl.get("jobs", 0))
		"employed":
			return employed()
		"research":
			return float(research_total())
		"districts":
			return float(districts_unlocked)
		"pop":
			return population()
		"spots":
			return float(spots())
		"earned":
			return total_earned
	return 0.0


func mission_done(i: int) -> bool:
	return mission_progress(i) >= float(MISSIONS[i].goal)


func mission_claimed(i: int) -> bool:
	return missions_claimed.has(i)


func claimable_missions() -> int:
	var n := 0
	for i in MISSIONS.size():
		if mission_done(i) and not mission_claimed(i):
			n += 1
	return n


func claim_mission(i: int) -> bool:
	if not mission_done(i) or mission_claimed(i):
		return false
	var m: Dictionary = MISSIONS[i]
	missions_claimed.append(i)
	money += float(m.money)
	gems += int(m.gems)
	add_xp(20.0)
	notify.emit("Missão concluída! +%s  +%d gemas" % [money_str(float(m.money)), int(m.gems)])
	changed.emit()
	save_game()
	return true


# ---------------------------------------------------------------- Save

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"money": money,
		"gems": gems,
		"level": level,
		"xp": xp,
		"lvl": lvl,
		"districts_unlocked": districts_unlocked,
		"total_cars": total_cars,
		"lost_customers": lost_customers,
		"total_earned": total_earned,
		"boost_until": boost_until,
		"missions_claimed": missions_claimed,
		"price_value": price_value,
		"research_lvl": research_lvl,
		"research_key": research_key,
		"research_end": research_end,
		"pop": pop,
		"day": day,
		"hour": hour,
		"saved_at": Time.get_unix_time_from_system(),
	}


func from_dict(d: Dictionary) -> void:
	money = float(d.get("money", money))
	gems = int(d.get("gems", gems))
	level = int(d.get("level", level))
	xp = float(d.get("xp", xp))
	var saved_lvl: Dictionary = d.get("lvl", {})
	for k in lvl.keys():
		lvl[k] = int(saved_lvl.get(k, 0))
	districts_unlocked = clampi(int(d.get("districts_unlocked", 1)), 1, DISTRICTS.size())
	total_cars = int(d.get("total_cars", 0))
	lost_customers = int(d.get("lost_customers", 0))
	total_earned = float(d.get("total_earned", 0.0))
	boost_until = float(d.get("boost_until", 0.0))
	day = int(d.get("day", 1))
	hour = float(d.get("hour", 8.0))
	if d.has("pop"):
		pop = float(d.pop)
	else:
		pop = minf(1000.0, target_population())
	price_value = float(d.get("price_value", 8.0 + float(saved_lvl.get("price", 0))))
	research_lvl = {}
	var rl: Dictionary = d.get("research_lvl", {})
	for k in rl.keys():
		research_lvl[String(k)] = int(rl[k])
	research_key = String(d.get("research_key", ""))
	if not RESEARCH.has(research_key):
		research_key = ""
	research_end = float(d.get("research_end", 0.0))
	missions_claimed = []
	for v in d.get("missions_claimed", []):
		missions_claimed.append(int(v))


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	from_dict(data)
	var saved_at := float(data.get("saved_at", 0.0))
	var elapsed := Time.get_unix_time_from_system() - saved_at
	if saved_at > 0.0 and elapsed > 60.0:
		offline_seconds = minf(elapsed, MAX_OFFLINE_SECONDS)
		# a cidade continuou crescendo e o relógio andou
		pop += (target_population() - pop) * (1.0 - exp(-offline_seconds / 40.0))
		hour = fposmod(hour + offline_seconds * 24.0 / DAY_SECONDS, 24.0)
		day += int(offline_seconds / DAY_SECONDS)
		# O boost não vale para o período offline.
		var boosted := boost_until
		boost_until = 0.0
		offline_pending = expected_income_per_sec() * offline_seconds * (OFFLINE_EFFICIENCY + 0.1 * rlvl("remote"))
		boost_until = boosted


func reset_game() -> void:
	from_dict({})
	money = 500.0
	gems = 20
	level = 1
	xp = 0.0
	offline_pending = 0.0
	save_game()
	changed.emit()


# ---------------------------------------------------------------- Formatação

static func int_str(v: float) -> String:
	var s := str(int(floor(absf(v))))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if v < 0.0 else "") + out


static func money_str(v: float) -> String:
	if absf(v) >= 1e9:
		return "R$ " + ("%.2f" % (v / 1e9)).replace(".", ",") + " bi"
	if absf(v) >= 1e6:
		return "R$ " + ("%.2f" % (v / 1e6)).replace(".", ",") + " mi"
	return "R$ " + int_str(v)


static func price_str(v: float) -> String:
	return "R$ " + ("%.2f" % v).replace(".", ",")


static func time_str(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %02dmin" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]
