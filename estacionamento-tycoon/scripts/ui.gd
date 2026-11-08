extends CanvasLayer
## Interface: barra superior, painel de status, menu inferior e janelas.

const C_PANEL := Color(0.07, 0.11, 0.2, 0.94)
const C_CARD := Color(0.12, 0.17, 0.29, 1.0)
const C_GREEN := Color("2fbf4a")
const C_GREEN_TEXT := Color("7dff7a")
const C_GOLD := Color("ffd23f")
const C_GEM := Color("d77cff")
const C_MUTED := Color(0.75, 0.8, 0.9)

var root: Control
var world = null
var top_bar: Control
var status_card: Control
var bottom_bar: Control
var side_buttons: Control
var level_label: Label
var xp_bar: ProgressBar
var money_label: Label
var rate_label: Label
var gems_label: Label
var boost_label: Label
var status_label: Label
var city_label: Label
var clock_label: Label
var moment_label: Label
var missions_btn: Button
var window: PanelContainer
var window_title: Label
var window_body: VBoxContainer
var toast_label: Label
var current_tab := ""
var refreshers: Array[Callable] = []
var _refresh_acc := 0.0
var top_inset := 0.0
var fps_label: Label


func _ready() -> void:
	top_inset = _compute_top_inset()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top_bar()
	_build_status_card()
	_build_bottom_bar()
	_build_side_buttons()
	_build_window()
	_build_toast()
	Game.notify.connect(show_toast)
	_update_hud()
	if Game.offline_pending > 0.0:
		_open_offline()


func _process(delta: float) -> void:
	_refresh_acc += delta
	if _refresh_acc >= 0.2:
		_refresh_acc = 0.0
		_update_hud()
		for r in refreshers:
			r.call()


# ---------------------------------------------------------------- Tema

## Espaço livre no topo para não ficar embaixo da câmera/entalhe do celular.
func _compute_top_inset() -> float:
	var extra := 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		var vis := get_viewport().get_visible_rect().size
		if win.y > 0:
			extra = safe.position.y * vis.y / float(win.y)
		extra = maxf(extra, 48.0)
	return extra


func _box(color: Color, radius: int = 18, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, 20, 14))
	t.set_stylebox("normal", "Button", _box(C_GREEN, 14, 14))
	t.set_stylebox("hover", "Button", _box(C_GREEN.lightened(0.1), 14, 14))
	t.set_stylebox("pressed", "Button", _box(C_GREEN.darkened(0.2), 14, 14))
	t.set_stylebox("disabled", "Button", _box(Color(0.3, 0.33, 0.4), 14, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.75, 0.8))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	var bg := _box(Color(0.05, 0.07, 0.12), 8, 0)
	var fill := _box(Color("2f8fff"), 8, 0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	return t


func _label(text: String, size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(C_CARD, 16, 14))
	return p


# ---------------------------------------------------------------- HUD

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 10 + top_inset
	root.add_child(bar)
	top_bar = bar
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	level_label = _label("Nv 1", 22, C_GOLD)
	lv.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(90, 12)
	lv.add_child(xp_bar)
	row.add_child(lv)

	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.add_theme_constant_override("separation", 0)
	money_label = _label("R$ 0", 30)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_label = _label("+R$ 0/h", 18, C_GREEN_TEXT)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(money_label)
	mv.add_child(rate_label)
	row.add_child(mv)

	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 0)
	gems_label = _label("0 gemas", 22, C_GEM)
	gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boost_label = _label("", 16, C_GOLD)
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gv.add_child(gems_label)
	gv.add_child(boost_label)
	row.add_child(gv)


func _build_status_card() -> void:
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 10
	card.offset_right = -10
	card.offset_top = 110 + top_inset
	root.add_child(card)
	status_card = card
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var top := HBoxContainer.new()
	clock_label = _label("", 20, C_GOLD)
	moment_label = _label("", 20, C_GREEN_TEXT)
	moment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(clock_label)
	fps_label = _label("", 14, C_MUTED)
	fps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(fps_label)
	top.add_child(moment_label)
	v.add_child(top)
	status_label = _label("", 19)
	city_label = _label("", 17, C_MUTED)
	v.add_child(status_label)
	v.add_child(city_label)


func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_bottom = -12
	bar.offset_top = -102
	root.add_child(bar)
	bottom_bar = bar
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	for tab in [["Melhorias", "upgrades"], ["Cidade", "city"], ["Expansão", "expansion"], ["Missões", "missions"]]:
		var b := _button(tab[0], _open_tab.bind(tab[1]), 21)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", _box(Color("2a4a8a"), 14, 6))
		b.add_theme_stylebox_override("hover", _box(Color("3560a8"), 14, 6))
		b.add_theme_stylebox_override("pressed", _box(Color("1d3566"), 14, 6))
		row.add_child(b)
		if tab[1] == "missions":
			missions_btn = b


func _update_hud() -> void:
	level_label.text = "Nv %d" % Game.level
	xp_bar.max_value = Game.xp_needed()
	xp_bar.value = Game.xp
	money_label.text = Game.money_str(Game.money)
	rate_label.text = "+%s/h" % Game.money_str(Game.income_per_hour())
	gems_label.text = "%d gemas" % Game.gems
	boost_label.text = ("2x  " + Game.time_str(Game.boost_seconds_left())) if Game.is_boosted() else ""
	status_label.text = "Vagas: %d/%d   Preço: %s/h   Entrada: %d%%" % [
		Game.occupied, Game.spots(), Game.price_str(Game.price()), int(round(Game.enter_chance() * 100.0))]
	clock_label.text = Game.clock_str()
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	moment_label.text = Game.moment_str()
	city_label.text = "%s  |  %s moradores  |  %s trabalhando" % [
		Game.phase_name(), Game.int_str(Game.population()), Game.int_str(Game.employed())]
	var claim := Game.claimable_missions()
	missions_btn.text = "Missões (%d)" % claim if claim > 0 else "Missões"


# ---------------------------------------------------------------- Janela

func _build_window() -> void:
	window = PanelContainer.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	window.offset_left = 10
	window.offset_right = -10
	window.offset_bottom = -112
	window.offset_top = -660
	window.visible = false
	root.add_child(window)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	window.add_child(v)
	var head := HBoxContainer.new()
	window_title = _label("", 30)
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(window_title)
	var close := _button("X", close_window, 24)
	close.custom_minimum_size = Vector2(56, 48)
	close.add_theme_stylebox_override("normal", _box(Color("8a2a3a"), 12, 8))
	head.add_child(close)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	window_body = VBoxContainer.new()
	window_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_body.add_theme_constant_override("separation", 10)
	scroll.add_child(window_body)


## True se a posição (tela) está sobre algum elemento da interface.
func blocks_point(pos: Vector2) -> bool:
	for c in [top_bar, status_card, bottom_bar, side_buttons]:
		if c != null and c.visible and c.get_global_rect().has_point(pos):
			return true
	return window.visible and window.get_global_rect().has_point(pos)


func open_tab(tab: String) -> void:
	current_tab = tab
	_rebuild_window()
	window.visible = true


func _build_side_buttons() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -96
	box.offset_right = -12
	box.offset_top = 236 + top_inset
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	side_buttons = box
	var p := _button("P", _on_focus_lot, 34)
	p.custom_minimum_size = Vector2(84, 76)
	p.add_theme_stylebox_override("normal", _box(Color("1d4fb8"), 38, 8))
	p.add_theme_stylebox_override("hover", _box(Color("2a62d6"), 38, 8))
	p.add_theme_stylebox_override("pressed", _box(Color("163c8c"), 38, 8))
	box.add_child(p)
	var m := _button("Mapa", _on_show_map, 20)
	m.custom_minimum_size = Vector2(84, 60)
	m.add_theme_stylebox_override("normal", _box(Color("2a4a8a"), 18, 6))
	m.add_theme_stylebox_override("hover", _box(Color("3560a8"), 18, 6))
	box.add_child(m)


func _on_focus_lot() -> void:
	close_window()
	if world:
		world.focus_lot()


func _on_show_map() -> void:
	close_window()
	if world:
		world.show_map()


func close_window() -> void:
	window.visible = false
	current_tab = ""
	refreshers.clear()


func _open_tab(tab: String) -> void:
	if current_tab == tab and window.visible:
		close_window()
		return
	current_tab = tab
	_rebuild_window()
	window.visible = true


func _rebuild_window() -> void:
	refreshers.clear()
	for c in window_body.get_children():
		c.queue_free()
	match current_tab:
		"upgrades":
			window_title.text = "Melhorias do Estacionamento"
			_build_upgrades()
		"city":
			window_title.text = "Evolução da Cidade"
			_build_city()
		"expansion":
			window_title.text = "Expansão da Cidade"
			if world:
				world.focus_district(Game.districts_unlocked)
			_build_expansion()
		"missions":
			window_title.text = "Missões"
			_build_missions()
		"offline":
			window_title.text = "Bem-vindo de volta!"
			_build_offline()


func _after_action(ok: bool) -> void:
	if ok:
		_rebuild_window()


func _upgrade_row(key: String, current: String, nxt: String) -> void:
	var info: Dictionary = Game.UPGRADES[key]
	var card := _card()
	window_body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label("%s  (nível %d)" % [info.name, int(Game.lvl[key]) + 1], 24))
	var desc := _label(info.desc, 17, C_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	var change := _label(current + "  ->  " + nxt, 20, C_GREEN_TEXT)
	text.add_child(change)
	row.add_child(text)
	var btn := _button("", func(): _after_action(Game.buy_upgrade(key)), 20)
	btn.custom_minimum_size = Vector2(170, 64)
	row.add_child(btn)
	var refresh := func():
		if Game.upgrade_maxed(key):
			btn.text = "MÁXIMO"
			btn.disabled = true
		else:
			btn.text = Game.money_str(Game.upgrade_cost(key))
			btn.disabled = not Game.can_buy_upgrade(key)
	refresh.call()
	refreshers.append(refresh)
	if Game.upgrade_maxed(key):
		change.text = current


func _hint(text: String) -> void:
	var l := _label(text, 18, C_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_body.add_child(l)


func _build_upgrades() -> void:
	var s := Game.spots()
	_upgrade_row("spots", "%d vagas" % s, "%d vagas" % (s + 5))
	var a := Game.attract_level()
	_upgrade_row("attract", "Nível %d" % a, "Nível %d" % (a + 1))
	var p := Game.price()
	_upgrade_row("price", Game.price_str(p), Game.price_str(p + 1.0))
	var info := _label("", 18, C_MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_body.add_child(info)
	var refresh := func():
		info.text = "Preço justo para os motoristas: %s/h. Acima disso menos carros entram.\nCarros entrando: %.1f por minuto. Clientes perdidos (lotado): %s." % [
			Game.price_str(Game.fair_price()), Game.arrivals_per_sec() * 60.0, Game.int_str(Game.lost_customers)]
	refresh.call()
	refreshers.append(refresh)


func _build_city() -> void:
	var phases := HBoxContainer.new()
	phases.add_theme_constant_override("separation", 6)
	for i in Game.PHASES.size():
		var reached := Game.phase_index() >= i
		var c := _card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if reached:
			c.add_theme_stylebox_override("panel", _box(Color("1f6a3a"), 14, 8))
		var l := _label(Game.PHASES[i].name, 16, Color.WHITE if reached else C_MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)
		phases.add_child(c)
	window_body.add_child(phases)
	_build_city_stats()
	var hs := Game.housing()
	_upgrade_row("city", "Moradia p/ " + Game.int_str(hs), Game.int_str(hs * 1.3))
	var jb := Game.jobs()
	_upgrade_row("jobs", Game.int_str(jb) + " empregos", Game.int_str(jb * 1.3))
	var vpr := Game.vehicles_per_resident()
	_upgrade_row("fleet", "%d carros/100 hab." % int(round(vpr * 100.0)), "%d carros/100 hab." % int(round((vpr + 0.05) * 100.0)))

	var boost := _card()
	window_body.add_child(boost)
	var row := HBoxContainer.new()
	boost.add_child(row)
	var bl := _label("Turbo: receita em dobro por 10 minutos", 20, C_GOLD)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bl)
	var bb := _button("%d gemas" % Game.BOOST_GEMS, func(): _after_action(Game.buy_boost()), 20)
	bb.custom_minimum_size = Vector2(170, 64)
	bb.add_theme_stylebox_override("normal", _box(Color("8a3fc0"), 14, 14))
	row.add_child(bb)
	refreshers.append(func(): bb.disabled = Game.gems < Game.BOOST_GEMS)


func _stat_row(parent: VBoxContainer, title: String) -> Array:
	var row := HBoxContainer.new()
	var t := _label(title, 18, C_MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _label("", 18)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(t)
	row.add_child(v)
	parent.add_child(row)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	parent.add_child(bar)
	return [v, bar]


func _build_city_stats() -> void:
	var card := _card()
	window_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var pop_row := _stat_row(v, "Moradores / moradia")
	var job_row := _stat_row(v, "Empregos preenchidos")
	var work_row := _stat_row(v, "Trabalhadores empregados")
	var hint := _label("", 16, C_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var flow := _label("", 17, C_GREEN_TEXT)
	flow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(flow)
	var refresh := func():
		var pop := Game.population()
		var hs := Game.housing()
		pop_row[0].text = "%s / %s" % [Game.int_str(pop), Game.int_str(hs)]
		pop_row[1].max_value = hs
		pop_row[1].value = pop
		var jb := Game.jobs()
		job_row[0].text = "%s / %s" % [Game.int_str(Game.employed()), Game.int_str(jb)]
		job_row[1].max_value = jb
		job_row[1].value = Game.employed()
		var wa := Game.working_age()
		work_row[0].text = "%d%%  (desemprego %d%%)" % [int(round((1.0 - Game.unemployment()) * 100.0)), int(round(Game.unemployment() * 100.0))]
		work_row[1].max_value = maxf(1.0, wa)
		work_row[1].value = Game.employed()
		var target := Game.target_population()
		if target < hs * 0.98:
			hint.text = "Faltam empregos: a cidade só cresce até %s moradores. Atraia empresas!" % Game.int_str(target)
		elif pop < target * 0.98:
			hint.text = "Novos moradores chegando..."
		else:
			hint.text = "Moradias lotadas: construa mais para a cidade crescer."
		flow.text = "Agora (%s): %.0f trabalhadores/min e %.0f compradores/min passando de carro." % [
			Game.moment_str(), Game.work_traffic() * 60.0, Game.shop_traffic() * 60.0]
	refresh.call()
	refreshers.append(refresh)


func _build_expansion() -> void:
	_hint("Desbloqueie novos bairros: mais habitantes e um novo estacionamento em cada um (renda extra).")
	for i in Game.DISTRICTS.size():
		var d: Dictionary = Game.DISTRICTS[i]
		var card := _card()
		window_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(d.name, 24))
		var desc := _label("%s\n+%d%% moradia, +%d%% empregos, +%d%% receita" % [d.desc, int(d.pop * 100.0), int(d.jobs * 100.0), int(d.income * 100.0)], 17, C_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
		row.add_child(text)
		if i < Game.districts_unlocked:
			row.add_child(_label("Desbloqueado", 20, C_GREEN_TEXT))
		elif i == Game.districts_unlocked:
			var btn := _button(Game.money_str(float(d.cost)), func(): _after_action(Game.buy_next_district()), 20)
			btn.custom_minimum_size = Vector2(170, 64)
			row.add_child(btn)
			refreshers.append(func(): btn.disabled = Game.money < float(d.cost))
		else:
			row.add_child(_label("Bloqueado", 20, C_MUTED))


func _build_missions() -> void:
	var shown := 0
	for i in Game.MISSIONS.size():
		if Game.mission_claimed(i):
			continue
		var m: Dictionary = Game.MISSIONS[i]
		var card := _card()
		window_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(m.text, 22))
		var prog := ProgressBar.new()
		prog.show_percentage = false
		prog.custom_minimum_size = Vector2(0, 14)
		prog.max_value = float(m.goal)
		text.add_child(prog)
		text.add_child(_label("Recompensa: %s + %d gemas" % [Game.money_str(float(m.money)), int(m.gems)], 17, C_MUTED))
		row.add_child(text)
		var btn := _button("Coletar", func(): _after_action(Game.claim_mission(i)), 20)
		btn.custom_minimum_size = Vector2(140, 64)
		row.add_child(btn)
		var refresh := func():
			prog.value = minf(Game.mission_progress(i), float(m.goal))
			btn.disabled = not Game.mission_done(i)
		refresh.call()
		refreshers.append(refresh)
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		_hint("Todas as missões concluídas! Você é um magnata dos estacionamentos.")
	var stats := _label("Carros atendidos: %s   Faturamento total: %s" % [Game.int_str(Game.total_cars), Game.money_str(Game.total_earned)], 17, C_MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_body.add_child(stats)
	var reset := _button("Recomeçar do zero", _confirm_reset, 18)
	reset.add_theme_stylebox_override("normal", _box(Color("5a2a35"), 12, 10))
	window_body.add_child(reset)


func _confirm_reset() -> void:
	window_title.text = "Recomeçar?"
	refreshers.clear()
	for c in window_body.get_children():
		c.queue_free()
	_hint("Todo o progresso será apagado. Tem certeza?")
	var yes := _button("Sim, apagar tudo", _do_reset, 22)
	yes.add_theme_stylebox_override("normal", _box(Color("a02a3a"), 12, 12))
	window_body.add_child(yes)
	window_body.add_child(_button("Cancelar", func(): _rebuild_window(), 22))


func _do_reset() -> void:
	Game.reset_game()
	close_window()


func _open_offline() -> void:
	current_tab = "offline"
	_rebuild_window()
	window.visible = true


func _build_offline() -> void:
	_hint("Enquanto você esteve fora (%s), seu estacionamento faturou:" % Game.time_str(Game.offline_seconds))
	var amount := _label(Game.money_str(Game.offline_pending), 44, C_GREEN_TEXT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window_body.add_child(amount)
	window_body.add_child(_button("Coletar", _collect_offline.bind(false), 26))
	var dbl := _button("Coletar 2x (10 gemas)", _collect_offline.bind(true), 22)
	dbl.add_theme_stylebox_override("normal", _box(Color("8a3fc0"), 14, 14))
	dbl.disabled = Game.gems < 10
	window_body.add_child(dbl)


func _collect_offline(twice: bool) -> void:
	Game.collect_offline(twice)
	close_window()


# ---------------------------------------------------------------- Avisos

func _build_toast() -> void:
	toast_label = _label("", 26, C_GOLD)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 250 + top_inset
	toast_label.offset_left = -330
	toast_label.offset_right = 330
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 0.0
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)


func show_toast(text: String) -> void:
	toast_label.text = text
	var tw := toast_label.create_tween()
	toast_label.modulate.a = 1.0
	tw.tween_interval(2.0)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
