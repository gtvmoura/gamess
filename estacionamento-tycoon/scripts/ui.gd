extends CanvasLayer
## Interface: barra superior, painel de status, menu inferior e janelas.

const C_PANEL := Color(0.07, 0.11, 0.2, 0.94)
const C_CARD := Color(0.12, 0.17, 0.29, 1.0)
const C_GREEN := Color("2fbf4a")
const C_GREEN_TEXT := Color("7dff7a")
const C_GOLD := Color("ffd23f")
const C_GEM := Color("d77cff")
const C_MUTED := Color(0.75, 0.8, 0.9)

var perf_us := 0.0   # tempo médio de _process (microssegundos), para medição
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
var stars: Control
var rating_label: Label
var customer = null
var sound_btn: Button
var price_slider: HSlider
var window_scroll: ScrollContainer


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
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_us = perf_us * 0.95 + float(Time.get_ticks_usec() - _t0) * 0.05


func _process_inner(delta: float) -> void:
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


## Botão com "relevo": borda inferior mais escura que some ao apertar.
func _bbox(color: Color, radius: int = 14, pad: int = 14, pressed: bool = false) -> StyleBoxFlat:
	var sb := _box(color, radius, pad)
	sb.border_color = color.darkened(0.4)
	sb.border_width_bottom = 1 if pressed else 5
	if pressed:
		sb.content_margin_top += 4
	sb.anti_aliasing = true
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	var font_file = load("res://assets/fonts/Fredoka.ttf")
	if font_file != null:
		var fv := FontVariation.new()
		fv.base_font = font_file
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 560}
		t.default_font = fv
	t.default_font_size = 24
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 4)
	var panel := _box(C_PANEL, 22, 14)
	panel.border_color = Color(1, 1, 1, 0.08)
	panel.set_border_width_all(2)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 4)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _bbox(C_GREEN))
	t.set_stylebox("hover", "Button", _bbox(C_GREEN.lightened(0.1)))
	t.set_stylebox("pressed", "Button", _bbox(C_GREEN.darkened(0.1), 14, 14, true))
	t.set_stylebox("disabled", "Button", _bbox(Color(0.3, 0.33, 0.4)))
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
	b.pressed.connect(_click_sound)
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
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mid := HBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	stars = Control.new()
	stars.custom_minimum_size = Vector2(96, 20)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.draw.connect(_draw_stars)
	mid.add_child(stars)
	rating_label = _label("", 17, C_GOLD)
	mid.add_child(rating_label)
	mid.add_child(fps_label)
	top.add_child(mid)
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
	row.add_theme_constant_override("separation", 5)
	bar.add_child(row)
	for tab in [["Melhorias", "upgrades"], ["Negócios", "business"], ["Cidade", "city"], ["Pesquisa", "research"], ["Expansão", "expansion"], ["Missões", "missions"]]:
		var b := _button(tab[0], _open_tab.bind(tab[1]), 15)
		b.clip_text = true
		b.custom_minimum_size = Vector2(60, 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", _bbox(Color("2a4a8a"), 14, 6))
		b.add_theme_stylebox_override("hover", _bbox(Color("3560a8"), 14, 6))
		b.add_theme_stylebox_override("pressed", _bbox(Color("1d3566"), 14, 6, true))
		row.add_child(b)
		if tab[1] == "missions":
			missions_btn = b


func _update_hud() -> void:
	level_label.text = "Nv %d" % Game.level
	xp_bar.max_value = Game.xp_needed()
	xp_bar.value = Game.xp
	money_label.text = Game.money_str(Game.money)
	var inc := Game.income_per_hour()
	rate_label.text = ("+" if inc >= 0.0 else "") + Game.money_str(inc) + "/h"
	rate_label.add_theme_color_override("font_color", C_GREEN_TEXT if inc >= 0.0 else Color("ff6b6b"))
	gems_label.text = "%d gemas" % Game.gems
	boost_label.text = ("2x  " + Game.time_str(Game.boost_seconds_left())) if Game.is_boosted() else ""
	status_label.text = "Vagas: %d/%d   Preço: %s/h   Entrada: %d%%" % [
		Game.occupied, Game.spots(), Game.price_str(Game.price()), int(round(Game.enter_chance() * 100.0))]
	clock_label.text = Game.clock_str()
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	rating_label.text = Game.rating_str()
	stars.queue_redraw()
	moment_label.text = Game.moment_str()
	city_label.text = "%s  |  %s moradores  |  %s trabalhando" % [
		Game.phase_name(), Game.int_str(Game.population()), Game.int_str(Game.employed())]
	var claim := Game.claimable_missions()
	missions_btn.text = "Missões %d" % claim if claim > 0 else "Missões"


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
	close.add_theme_stylebox_override("normal", _bbox(Color("8a2a3a"), 12, 8))
	head.add_child(close)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	window_scroll = scroll
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
	p.add_theme_stylebox_override("normal", _bbox(Color("1d4fb8"), 38, 8))
	p.add_theme_stylebox_override("hover", _bbox(Color("2a62d6"), 38, 8))
	p.add_theme_stylebox_override("pressed", _bbox(Color("163c8c"), 38, 8, true))
	box.add_child(p)
	var m := _button("Mapa", _on_show_map, 20)
	m.custom_minimum_size = Vector2(84, 60)
	m.add_theme_stylebox_override("normal", _bbox(Color("2a4a8a"), 18, 6))
	m.add_theme_stylebox_override("hover", _bbox(Color("3560a8"), 18, 6))
	box.add_child(m)
	var emp := _button("Império", _open_tab.bind("prestige"), 16)
	emp.custom_minimum_size = Vector2(84, 48)
	emp.add_theme_stylebox_override("normal", _bbox(Color("c08a1a"), 18, 6))
	emp.add_theme_stylebox_override("hover", _bbox(Color("d69c22"), 18, 6))
	box.add_child(emp)
	sound_btn = _button("", _toggle_sound, 16)
	sound_btn.custom_minimum_size = Vector2(84, 48)
	sound_btn.add_theme_stylebox_override("normal", _bbox(Color("2a4a8a"), 18, 6))
	box.add_child(sound_btn)
	_update_sound_btn()


func _toggle_sound() -> void:
	Sfx.toggle()
	_update_sound_btn()


func _update_sound_btn() -> void:
	sound_btn.text = "Som: sim" if Sfx.enabled else "Som: não"


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
		"research":
			window_title.text = "Centro de Pesquisa"
			_build_research()
		"business":
			window_title.text = "Serviços e Funcionários"
			_build_business()
		"offline":
			window_title.text = "Bem-vindo de volta!"
			_build_offline()
		"customer":
			_build_customer()
		"prestige":
			window_title.text = "Império e Prestígio"
			_build_prestige()
	_let_scroll(window_body)


## Faz cartões, rótulos e botões deixarem o arrasto chegar no ScrollContainer
## (o toque curto continua apertando o botão). Sliders continuam capturando.
func _let_scroll(node: Node) -> void:
	for c in node.get_children():
		if c is Slider:
			continue
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_let_scroll(c)


func _click_sound() -> void:
	Sfx.play("click", -12.0, 0.05, 0.03)


func _after_action(ok: bool) -> void:
	if ok:
		Sfx.play("buy", -4.0, 0.05)
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
	_build_price_card()
	var s := Game.spots()
	_upgrade_row("spots", "%d vagas" % s, "%d vagas" % (s + 5))
	var a := Game.attract_level()
	_upgrade_row("attract", "Nível %d" % a, "Nível %d" % (a + 1))
	_upgrade_row("comfort", "Rejeição %.2f" % Game.price_sensitivity(), "mais tolerância")
	var gl := int(Game.lvl.get("garage", 0))
	_upgrade_row("garage", "%d andares (%d vagas)" % [gl, Game.garage_spots()], "%d andares" % (gl + 1))
	var info := _label("", 17, C_MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_body.add_child(info)
	var refresh := func():
		info.text = "Carros entrando: %.1f por minuto. Clientes perdidos (lotado): %s." % [
			Game.arrivals_per_sec() * 60.0, Game.int_str(Game.lost_customers)]
	refresh.call()
	refreshers.append(refresh)


func _build_price_card() -> void:
	var card := _card()
	window_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var head := HBoxContainer.new()
	var t := _label("Preço por hora", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var value := _label("", 30, C_GOLD)
	head.add_child(value)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var minus := _button("-", _nudge_price.bind(-1), 28)
	minus.custom_minimum_size = Vector2(64, 56)
	var slider := HSlider.new()
	slider.min_value = Game.MIN_PRICE
	slider.max_value = Game.MAX_PRICE
	slider.step = 0.5
	slider.exp_edit = true
	slider.value = Game.price()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 48)
	slider.value_changed.connect(func(x): Game.set_price(x))
	price_slider = slider
	var plus := _button("+", _nudge_price.bind(1), 28)
	plus.custom_minimum_size = Vector2(64, 56)
	row.add_child(minus)
	row.add_child(slider)
	row.add_child(plus)
	v.add_child(row)
	var acc := _label("", 18)
	v.add_child(acc)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = 1.0
	v.add_child(bar)
	var hint := _label("", 16, C_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var ideal_row := HBoxContainer.new()
	var ideal := _label("", 18, C_GREEN_TEXT)
	ideal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ideal_row.add_child(ideal)
	var use := _button("Usar ideal", _use_best_price, 18)
	use.custom_minimum_size = Vector2(150, 50)
	ideal_row.add_child(use)
	v.add_child(ideal_row)
	var best := [Game.best_price(), 0.0]
	var refresh := func():
		value.text = Game.price_str(Game.price())
		var a := Game.price_acceptance()
		acc.text = "Aceitação dos motoristas: %d%%" % int(round(minf(a, 1.0) * 100.0))
		bar.value = minf(a, 1.0)
		hint.text = "Preço justo: %s/h. Acima dele, menos carros entram (Segurança e Conforto e pesquisas reduzem a rejeição)." % Game.price_str(Game.fair_price())
		best[1] += 0.2
		if best[1] >= 2.0:
			best[1] = 0.0
			best[0] = Game.best_price()
		ideal.text = "Preço ideal agora: %s/h" % Game.price_str(best[0])
	refresh.call()
	refreshers.append(refresh)


func _section(text: String) -> void:
	var l := _label(text, 24, C_GOLD)
	window_body.add_child(l)


func _build_business() -> void:
	var summary := _label("", 18, C_GREEN_TEXT)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_body.add_child(summary)
	var sref := func():
		var per_car := Game.service_value_per_car() * Game.income_mult()
		summary.text = "Cada cliente gasta em média %s em serviços.\nSalários: %s/h." % [
			Game.money_str(per_car), Game.money_str(Game.salary_per_hour())]
	sref.call()
	refreshers.append(sref)

	_section("Serviços")
	for key in Game.SERVICES.keys():
		var sv: Dictionary = Game.SERVICES[key]
		var card := _card()
		window_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lv := Game.service_lvl(key)
		text.add_child(_label(sv.name + ("  (nível %d)" % lv if lv > 0 else "  (não construído)"), 21))
		var desc := _label(sv.desc, 16, C_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
		var stat := _label("", 16, C_GREEN_TEXT)
		stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(stat)
		row.add_child(text)
		var btn := _button("", func(): _after_action(Game.buy_service(key)), 18)
		btn.custom_minimum_size = Vector2(160, 64)
		row.add_child(btn)
		var refresh := func():
			var l := Game.service_lvl(key)
			if l > 0:
				var t := "%d%% dos clientes usam, %s cada" % [int(round(Game.service_chance(key) * 100.0)), Game.money_str(Game.service_price(key))]
				var role: String = sv.staff
				if role != "" and Game.service_efficiency(key) < 1.0:
					t += "\nPrecisa de mais %s! Funcionando a %d%%." % [Game.STAFF[role].name, int(Game.service_efficiency(key) * 100.0)]
					stat.add_theme_color_override("font_color", Color("ffb347"))
				else:
					stat.add_theme_color_override("font_color", C_GREEN_TEXT)
				stat.text = t
			else:
				stat.text = "Preço base %s por uso" % Game.money_str(float(sv.price))
			if Game.service_maxed(key):
				btn.text = "MÁXIMO"
				btn.disabled = true
			else:
				btn.text = ("Construir\n" if l == 0 else "") + Game.money_str(Game.service_cost(key))
				btn.disabled = not Game.can_buy_service(key)
		refresh.call()
		refreshers.append(refresh)

	_section("Funcionários")
	for key in Game.STAFF.keys():
		var st: Dictionary = Game.STAFF[key]
		var card := _card()
		window_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label("%s  (%d/%d)" % [st.name, Game.staff_count(key), int(st.max)], 21))
		var desc := _label(st.desc, 16, C_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
		var sal := _label("", 16, C_MUTED)
		text.add_child(sal)
		row.add_child(text)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var hire := _button("", func(): _after_action(Game.hire(key)), 17)
		hire.custom_minimum_size = Vector2(150, 50)
		col.add_child(hire)
		var fire := _button("Demitir", func(): _after_action(Game.fire(key)), 15)
		fire.custom_minimum_size = Vector2(150, 36)
		fire.add_theme_stylebox_override("normal", _bbox(Color("5a2a35"), 10, 6))
		fire.visible = Game.staff_count(key) > 0
		col.add_child(fire)
		row.add_child(col)
		var refresh := func():
			sal.text = "Salário: %s/h cada" % Game.money_str(Game.staff_salary(key))
			if Game.staff_count(key) >= int(st.max):
				hire.text = "MÁXIMO"
				hire.disabled = true
			else:
				hire.text = "Contratar " + Game.money_str(Game.staff_hire_cost(key))
				hire.disabled = not Game.can_hire(key)
		refresh.call()
		refreshers.append(refresh)


func _nudge_price(dir: int) -> void:
	var p := Game.price()
	var step := 0.5 if p < 20.0 else (1.0 if p < 60.0 else 5.0)
	Game.set_price(p + step * dir)
	if is_instance_valid(price_slider):
		price_slider.set_value_no_signal(Game.price())


func _use_best_price() -> void:
	Game.set_price(Game.best_price())
	if is_instance_valid(price_slider):
		price_slider.set_value_no_signal(Game.price())


func _build_research() -> void:
	var active := _card()
	window_body.add_child(active)
	var av := VBoxContainer.new()
	active.add_child(av)
	var a_title := _label("", 22, C_GOLD)
	av.add_child(a_title)
	var a_bar := ProgressBar.new()
	a_bar.show_percentage = false
	a_bar.custom_minimum_size = Vector2(0, 14)
	a_bar.max_value = 1.0
	av.add_child(a_bar)
	var a_row := HBoxContainer.new()
	var a_time := _label("", 18, C_MUTED)
	a_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_row.add_child(a_time)
	var rush := _button("", func(): _after_action(Game.rush_research()), 18)
	rush.custom_minimum_size = Vector2(190, 50)
	rush.add_theme_stylebox_override("normal", _bbox(Color("8a3fc0"), 14, 10))
	a_row.add_child(rush)
	av.add_child(a_row)
	var was_active := [Game.research_active()]
	var refresh_active := func():
		if Game.research_active():
			a_title.text = "Pesquisando: %s" % Game.RESEARCH[Game.research_key].name
			a_bar.value = Game.research_progress()
			a_time.text = "Falta " + Game.time_str(Game.research_left())
			rush.visible = true
			rush.text = "Concluir (%d gemas)" % Game.rush_cost()
			rush.disabled = Game.gems < Game.rush_cost()
		else:
			a_title.text = "Nenhuma pesquisa em andamento"
			a_bar.value = 0.0
			a_time.text = "Escolha uma pesquisa abaixo."
			rush.visible = false
		if was_active[0] != Game.research_active():
			was_active[0] = Game.research_active()
			_rebuild_window.call_deferred()
	refresh_active.call()
	refreshers.append(refresh_active)
	for key in Game.RESEARCH.keys():
		var r: Dictionary = Game.RESEARCH[key]
		var card := _card()
		window_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label("%s  (nível %d/%d)" % [r.name, Game.rlvl(key), int(r.max)], 21))
		var desc := _label("%s\nDuração: %s" % [r.desc, Game.time_str(Game.research_time(key))], 16, C_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
		row.add_child(text)
		var btn := _button("", func(): _after_action(Game.start_research(key)), 18)
		btn.custom_minimum_size = Vector2(160, 64)
		row.add_child(btn)
		var refresh := func():
			if Game.research_maxed(key):
				btn.text = "MÁXIMO"
				btn.disabled = true
			else:
				btn.text = Game.money_str(Game.research_cost(key))
				btn.disabled = not Game.can_start_research(key)
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
	bb.add_theme_stylebox_override("normal", _bbox(Color("8a3fc0"), 14, 14))
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
			if i >= 1:
				_lot_card(i)
		elif i == Game.districts_unlocked:
			var btn := _button(Game.money_str(Game.next_district_cost()), func(): _after_action(Game.buy_next_district()), 20)
			btn.custom_minimum_size = Vector2(170, 64)
			row.add_child(btn)
			refreshers.append(func(): btn.disabled = Game.money < Game.next_district_cost())
		else:
			row.add_child(_label("Bloqueado", 20, C_MUTED))


## Estacionamento de um bairro: construir, aumentar vagas e virar edifício-garagem.
func _lot_card(d: int) -> void:
	var card := _card()
	card.add_theme_stylebox_override("panel", _box(Color(0.1, 0.2, 0.32), 14, 12))
	window_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var title := _label("", 19, C_GOLD)
	v.add_child(title)
	var info := _label("", 16, C_MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var b1 := _button("", func(): _after_action(Game.buy_lot(d)), 16)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.custom_minimum_size = Vector2(0, 52)
	row.add_child(b1)
	var b2 := _button("", func(): _after_action(Game.buy_lot_floor(d)), 16)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.custom_minimum_size = Vector2(0, 52)
	b2.add_theme_stylebox_override("normal", _bbox(Color("2f6fe0")))
	row.add_child(b2)
	var refresh := func():
		var l := Game.lot_lvl(d)
		if l == 0:
			title.text = "Estacionamento do bairro: não construído"
			info.text = "Atende a demanda local do bairro e rende sozinho."
			b1.text = "Construir  " + Game.money_str(Game.lot_cost(d))
			b2.visible = false
		else:
			var fl := Game.lot_floors(d)
			title.text = "Estacionamento do bairro: %d vagas%s" % [Game.lot_capacity(d), ("  |  garagem %d andares" % fl) if fl > 0 else ""]
			info.text = "Rende %s/h" % Game.money_str(Game.lot_income_at(d, Game.price()) * 3600.0)
			b1.text = ("+10 vagas  " + Game.money_str(Game.lot_cost(d))) if l < Game.lot_max_lvl() else "Vagas no máximo"
			b2.visible = true
			if l < 3:
				b2.text = "Garagem: nível 3"
				b2.disabled = true
			else:
				b2.text = ("+1 andar  " + Game.money_str(Game.lot_floor_cost(d))) if fl < 8 else "Andares no máximo"
				b2.disabled = not Game.can_buy_lot_floor(d)
		b1.disabled = not Game.can_buy_lot(d)
	refresh.call()
	refreshers.append(refresh)


# ---------------------------------------------------------------- Prestígio

func _build_prestige() -> void:
	var head := _card()
	head.add_theme_stylebox_override("panel", _box(Color("3a2a10"), 16, 14))
	window_body.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	head.add_child(hv)
	var pts := _label("", 26, C_GOLD)
	hv.add_child(pts)
	var desc := _label("Venda o império para um grande grupo investidor: você recomeça a cidade do zero, mas ganha Pontos de Prestígio para upgrades permanentes. Gemas, conquistas e upgrades de prestígio ficam com você.", 16, C_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(desc)
	var gain := _label("", 19, C_GREEN_TEXT)
	gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(gain)
	var sell := _button("Vender o império", _confirm_prestige, 20)
	sell.custom_minimum_size = Vector2(0, 58)
	sell.add_theme_stylebox_override("normal", _bbox(Color("c08a1a")))
	sell.add_theme_stylebox_override("hover", _bbox(Color("d69c22")))
	hv.add_child(sell)
	var href := func():
		pts.text = "Pontos de Prestígio: %d" % Game.prestige_points
		var g := Game.prestige_gain()
		if g >= 1:
			gain.text = "Vendendo agora você ganha +%d pontos. (Vendas feitas: %d)" % [g, Game.prestige_count]
		else:
			gain.text = "Fature mais para poder vender: o 1º ponto vem com R$ 2 milhões faturados. (Faturado: %s)" % Game.money_str(Game.total_earned)
		sell.disabled = g < 1
	href.call()
	refreshers.append(href)
	for tier in [1, 2, 3, 4]:
		var unlocked := Game.tier_unlocked(tier)
		var th := _label("Nível %d: %s" % [tier, Game.TIER_NAMES[tier]] + ("" if unlocked else "  (invista %d pontos para abrir)" % int(Game.TIER_REQ[tier])), 22, C_GOLD if unlocked else C_MUTED)
		window_body.add_child(th)
		for key in Game.PRESTIGE.keys():
			var u: Dictionary = Game.PRESTIGE[key]
			if int(u.tier) != tier:
				continue
			var card := _card()
			if not unlocked:
				card.modulate = Color(1, 1, 1, 0.55)
			window_body.add_child(card)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			card.add_child(row)
			var text := VBoxContainer.new()
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.add_child(_label("%s  (%d/%d)" % [u.name, Game.plvl(key), int(u.max)], 20))
			var dl := _label(u.desc, 16, C_MUTED)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(dl)
			row.add_child(text)
			var btn := _button("", func(): _after_action(Game.buy_prestige(key)), 18)
			btn.custom_minimum_size = Vector2(130, 60)
			btn.add_theme_stylebox_override("normal", _bbox(Color("c08a1a")))
			row.add_child(btn)
			var r := func():
				if Game.plvl(key) >= int(u.max):
					btn.text = "MÁXIMO"
					btn.disabled = true
				else:
					btn.text = "%d pts" % Game.prestige_cost(key)
					btn.disabled = not Game.can_buy_prestige(key)
			r.call()
			refreshers.append(r)


func _confirm_prestige() -> void:
	window_title.text = "Vender o império?"
	refreshers.clear()
	for c in window_body.get_children():
		c.queue_free()
	_hint("Você vai recomeçar numa cidade nova (dinheiro, melhorias, bairros, serviços e funcionários zerados) e ganhar +%d Pontos de Prestígio. Tem certeza?" % Game.prestige_gain())
	var yes := _button("Sim, vender!", _do_prestige, 22)
	yes.add_theme_stylebox_override("normal", _bbox(Color("c08a1a")))
	window_body.add_child(yes)
	window_body.add_child(_button("Cancelar", func(): _rebuild_window(), 22))


func _do_prestige() -> void:
	if Game.do_prestige():
		Sfx.play("build", -2.0)
	current_tab = "prestige"
	_rebuild_window()


func _draw_stars() -> void:
	var r := 8.5
	for i in 5:
		var c := Vector2(10 + i * 19, 10)
		var fill := clampf(Game.rating - i, 0.0, 1.0)
		_star(c, r, Color(1, 1, 1, 0.18))
		if fill > 0.0:
			_star(c, r * (0.45 + 0.55 * fill), C_GOLD)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	stars.draw_colored_polygon(pts, col)


func show_customer(car) -> void:
	customer = car
	current_tab = "customer"
	_rebuild_window()
	window.visible = true


func _build_customer() -> void:
	var car = customer
	if car == null or not is_instance_valid(car):
		window_title.text = "Cliente"
		_hint("Este cliente já foi embora.")
		return
	window_title.text = car.cname
	var card := _card()
	window_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var kinds := ["Sedã", "Picape", "Ônibus", "Hatch", "SUV", "Van", "Táxi", "Moto"]
	v.add_child(_label("%s  |  %s" % [car.job, kinds[clampi(car.kind, 0, kinds.size() - 1)]], 20, C_MUTED))
	var status := _label("", 22)
	v.add_child(status)
	var info := _label("", 19, C_MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var spent := _label("", 22, C_GREEN_TEXT)
	v.add_child(spent)
	var mood := _label("", 19)
	mood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(mood)
	var refresh := func():
		if not is_instance_valid(car):
			status.text = "Foi embora."
			return
		status.text = car.status
		if car.angry:
			info.text = "Chegou, viu o estacionamento lotado e foi embora. Isso derruba a sua avaliação!"
			spent.text = "Gastou: R$ 0"
			mood.text = "Humor: irritado"
			mood.add_theme_color_override("font_color", Color("ff6b6b"))
			return
		info.text = "%s  |  Vai ficar %s h pagando %s/h" % [
			"Veio trabalhar" if car.worker else "Veio às compras/lazer", ("%.1f" % car.hours).replace(".", ","), Game.price_str(Game.price())]
		spent.text = "Gastou até agora: %s" % Game.money_str(car.spent)
		var ratio := Game.price() / Game.fair_price()
		if ratio > 1.3:
			mood.text = "Humor: achou caro"
			mood.add_theme_color_override("font_color", Color("ffb347"))
		elif Game.rating >= 4.0:
			mood.text = "Humor: muito satisfeito"
			mood.add_theme_color_override("font_color", C_GREEN_TEXT)
		else:
			mood.text = "Humor: satisfeito"
			mood.add_theme_color_override("font_color", Color.WHITE)
	refresh.call()
	refreshers.append(refresh)


func _build_achievements() -> void:
	var done := Game.achievements.size()
	var head := _label("Conquistas  %d/%d" % [done, Game.ACHIEVEMENTS.size()], 24, C_GOLD)
	window_body.add_child(head)
	for a in Game.ACHIEVEMENTS:
		var got: bool = Game.achievements.has(a.id)
		var card := _card()
		if got:
			card.add_theme_stylebox_override("panel", _box(Color("1f5a3a"), 16, 12))
		window_body.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(a.name, 20, Color.WHITE if got else C_MUTED))
		text.add_child(_label(a.desc, 16, C_MUTED))
		row.add_child(text)
		row.add_child(_label(("Feita! " if got else "") + "+%d gemas" % int(a.gems), 17, C_GEM))


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
	_build_achievements()
	var stats := _label("Carros atendidos: %s   Faturamento total: %s" % [Game.int_str(Game.total_cars), Game.money_str(Game.total_earned)], 17, C_MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_body.add_child(stats)
	var reset := _button("Recomeçar do zero", _confirm_reset, 18)
	reset.add_theme_stylebox_override("normal", _bbox(Color("5a2a35"), 12, 10))
	window_body.add_child(reset)


func _confirm_reset() -> void:
	window_title.text = "Recomeçar?"
	refreshers.clear()
	for c in window_body.get_children():
		c.queue_free()
	_hint("Todo o progresso será apagado. Tem certeza?")
	var yes := _button("Sim, apagar tudo", _do_reset, 22)
	yes.add_theme_stylebox_override("normal", _bbox(Color("a02a3a"), 12, 12))
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
	dbl.add_theme_stylebox_override("normal", _bbox(Color("8a3fc0"), 14, 14))
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
