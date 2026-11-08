extends Node
## Estado global do jogo (autoload "Game"): economia, progressão, missões e save.

signal changed
signal leveled_up(new_level: int)
signal notify(text: String)

const SAVE_PATH := "user://save.json"
const SAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const OFFLINE_EFFICIENCY := 0.5
## Tempo médio (em segundos reais) que um carro passa estacionado.
const AVG_STAY_SECONDS := 12.0
## Horas cobradas, em média, por carro (1 a 3 horas de "tempo do jogo").
const AVG_STAY_HOURS := 2.0
const BOOST_GEMS := 30
const BOOST_SECONDS := 600.0

const UPGRADES := {
	"spots": {"name": "Mais Vagas", "desc": "Aumenta a capacidade do estacionamento.", "base": 150.0, "growth": 1.55, "max": 30},
	"attract": {"name": "Atratividade", "desc": "Lojas, segurança e cobertura atraem mais motoristas e permitem cobrar mais.", "base": 250.0, "growth": 1.7, "max": 25},
	"price": {"name": "Preço por Hora", "desc": "Aumenta o valor cobrado por vaga. Caro demais espanta clientes!", "base": 200.0, "growth": 1.6, "max": 40},
	"fleet": {"name": "Frota de Veículos", "desc": "Concessionárias na cidade: mais habitantes compram carros.", "base": 400.0, "growth": 1.75, "max": 20},
	"city": {"name": "Desenvolver a Cidade", "desc": "Novas casas, prédios e empregos atraem habitantes.", "base": 1000.0, "growth": 1.85, "max": 30},
}

const DISTRICTS := [
	{"name": "Centro", "cost": 0.0, "pop": 1.0, "income": 0.0, "desc": "Onde tudo começou."},
	{"name": "Vila Nova", "cost": 15000.0, "pop": 0.5, "income": 0.25, "desc": "Bairro residencial + novo estacionamento."},
	{"name": "Jardim das Flores", "cost": 90000.0, "pop": 0.75, "income": 0.5, "desc": "Comércio local e praças."},
	{"name": "Distrito Industrial", "cost": 500000.0, "pop": 1.0, "income": 1.0, "desc": "Fábricas com muitos trabalhadores motorizados."},
	{"name": "Beira-Rio", "cost": 3000000.0, "pop": 1.5, "income": 2.0, "desc": "Orla turística com shopping."},
	{"name": "Centro Financeiro", "cost": 20000000.0, "pop": 2.5, "income": 4.0, "desc": "Arranha-céus e escritórios."},
	{"name": "Aeroporto", "cost": 150000000.0, "pop": 4.0, "income": 8.0, "desc": "O maior estacionamento da região."},
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
	{"text": "Desenvolva a cidade 2 vezes", "type": "lvl_city", "goal": 2.0, "money": 2000.0, "gems": 10},
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
var lvl := {"spots": 0, "attract": 0, "price": 0, "fleet": 0, "city": 0}
var districts_unlocked: int = 1
var total_cars: int = 0
var lost_customers: int = 0
var total_earned: float = 0.0
var boost_until: float = 0.0
var missions_claimed: Array = []

## Vagas ocupadas agora (atualizado pela cena do estacionamento).
var occupied: int = 0
## Dinheiro acumulado enquanto o jogador estava fora (aguardando coleta).
var offline_pending: float = 0.0
var offline_seconds: float = 0.0

var _save_timer := 0.0


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
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
	return 8.0 + float(lvl.price)


func attract_level() -> int:
	return int(lvl.attract) + 1


func vehicles_per_resident() -> float:
	return 0.25 + 0.05 * float(lvl.fleet)


func population() -> float:
	return 1000.0 * pow(1.3, float(lvl.city)) * district_pop_mult()


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
	return 8.0 + 1.2 * float(lvl.attract) + 0.25 * float(lvl.city)


## Carros por segundo passando na frente do estacionamento.
func passing_per_sec() -> float:
	return population() * vehicles_per_resident() * 2.0 / 1000.0


## Chance de um carro que passa decidir entrar.
func enter_chance() -> float:
	var base := 0.35 + 0.05 * float(lvl.attract)
	var price_factor := pow(fair_price() / price(), 2.0)
	return clampf(base * price_factor, 0.01, 0.95)


func arrivals_per_sec() -> float:
	return passing_per_sec() * enter_chance()


func income_mult() -> float:
	var m := district_income_mult()
	if is_boosted():
		m *= 2.0
	return m


## Receita esperada por segundo (usada para renda offline e para o HUD).
func expected_income_per_sec() -> float:
	var capacity := float(spots()) / AVG_STAY_SECONDS
	var served := minf(arrivals_per_sec(), capacity)
	return served * price() * AVG_STAY_HOURS * income_mult()


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
		# O boost não vale para o período offline.
		var boosted := boost_until
		boost_until = 0.0
		offline_pending = expected_income_per_sec() * offline_seconds * OFFLINE_EFFICIENCY
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
