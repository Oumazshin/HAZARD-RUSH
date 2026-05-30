extends Node2D

@onready var countdown_label: Label = $HUD/CountdownLabel
@onready var results_menu = $ResultsMenu
@onready var hud: CanvasLayer = $HUD

var results_shown: bool = false
var player_kei_bar: ProgressBar
var ai_kei_bar: ProgressBar
var timer_display: Label
var hit_flash: ColorRect
var time_left: float = 60.0

func _ready() -> void:
	results_menu.hide()
	countdown_label.text       = ""
	countdown_label.modulate.a = 0.0
	_style_countdown_label()
	GameState.set_phase(GameState.RacePhase.PRE_MATCH)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.collision_event.connect(_on_collision_event)
	_setup_hud()
	_start_countdown()

func _style_countdown_label() -> void:
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.grow_horizontal        = Control.GROW_DIRECTION_BOTH
	countdown_label.grow_vertical          = Control.GROW_DIRECTION_BOTH
	countdown_label.custom_minimum_size    = Vector2(300, 150)
	countdown_label.offset_left            = -150
	countdown_label.offset_right           =  150
	countdown_label.offset_top             = -75
	countdown_label.offset_bottom          =  75
	countdown_label.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment     = VERTICAL_ALIGNMENT_CENTER
	countdown_label.pivot_offset           = Vector2(150, 75)
	countdown_label.add_theme_font_size_override("font_size", 96)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))

func _setup_hud() -> void:
	var vp     := get_viewport().get_visible_rect().size
	var half_h := vp.y / 2.0
	var m      := 14.0

	# ── PLAYER panel — top left ───────────────────────────────────────────────
	var p_vbox := _add_hud_panel(Vector2(m, m), Vector2(280.0, 84.0))

	var p_name := _make_label("PLAYER", 20, Color(0.35, 1.0, 0.50))
	p_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	p_name.add_theme_constant_override("shadow_offset_x", 1)
	p_name.add_theme_constant_override("shadow_offset_y", 1)
	p_vbox.add_child(p_name)

	player_kei_bar = _make_bar(Color(0.20, 0.85, 0.35), 16)
	p_vbox.add_child(player_kei_bar)

	# ── Timer panel — top centre ──────────────────────────────────────────────
	var t_vbox := _add_hud_panel(Vector2(vp.x / 2.0 - 90.0, m), Vector2(180.0, 54.0))
	var time_icon := _make_label("⏱ TIME", 13, Color(0.85, 0.85, 0.85))
	time_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_vbox.add_child(time_icon)
	timer_display = _make_label("60.0", 26, Color.WHITE)
	timer_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_display.add_theme_font_size_override("font_size", 26)
	t_vbox.add_child(timer_display)

	# ── AI OPPONENT panel — bottom left ───────────────────────────────────────
	var ai_vbox := _add_hud_panel(Vector2(m, half_h + m), Vector2(280.0, 84.0))

	var ai_name := _make_label("AI OPPONENT", 20, Color(1.0, 0.42, 0.42))
	ai_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	ai_name.add_theme_constant_override("shadow_offset_x", 1)
	ai_name.add_theme_constant_override("shadow_offset_y", 1)
	ai_vbox.add_child(ai_name)

	ai_kei_bar = _make_bar(Color(1.0, 0.35, 0.35), 16)
	ai_vbox.add_child(ai_kei_bar)

	# ── Hit flash overlay ─────────────────────────────────────────────────────
	hit_flash = ColorRect.new()
	hit_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hit_flash)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _add_hud_panel(pos: Vector2, size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.04, 0.04, 0.10, 0.88)
	style.border_color = Color(1.0, 0.85, 0.0, 0.60)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_deferred("position", pos)
	panel.set_deferred("size", size)
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	return vbox

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_bar(fill_color: Color, pct_font_size: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value           = 1.0
	bar.value               = 0.5
	bar.show_percentage     = true
	bar.custom_minimum_size = Vector2(255, 28)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.16, 0.95)
	bg.set_corner_radius_all(5)
	bg.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", bg)

	bar.add_theme_color_override("font_color", Color.WHITE)
	bar.add_theme_font_size_override("font_size", pct_font_size)
	return bar

# ── Per-frame ─────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if player_kei_bar:
		player_kei_bar.value = GameState.player_kei
	if ai_kei_bar:
		ai_kei_bar.value = GameState.ai_kei
	if timer_display and GameState.is_racing():
		timer_display.text = str(snapped(time_left, 0.1))
		var col := Color(1.0, 0.30, 0.30) if time_left <= 10.0 else Color.WHITE
		timer_display.add_theme_color_override("font_color", col)

# ── Countdown ─────────────────────────────────────────────────────────────────
func _start_countdown() -> void:
	for num in ["3", "2", "1"]:
		countdown_label.text       = num
		countdown_label.scale      = Vector2(2.5, 2.5)
		countdown_label.modulate.a = 1.0
		var tw_num := create_tween().set_parallel(true)
		tw_num.tween_property(countdown_label, "scale",      Vector2(1.0, 1.0), 0.85)
		tw_num.tween_property(countdown_label, "modulate:a", 0.0,               0.85)
		await get_tree().create_timer(1.0).timeout

	countdown_label.text       = "GO!"
	countdown_label.scale      = Vector2(1.0, 1.0)
	countdown_label.modulate.a = 1.0
	GameState.set_phase(GameState.RacePhase.RACING)
	var tw_go := create_tween().set_parallel(true)
	tw_go.tween_property(countdown_label, "scale",      Vector2(2.8, 2.8), 0.7)
	tw_go.tween_property(countdown_label, "modulate:a", 0.0,               0.7)
	await get_tree().create_timer(0.75).timeout
	countdown_label.text = ""
	_start_race_timer()

# ── Hit flash ─────────────────────────────────────────────────────────────────
func _on_collision_event(racer: String, _obstacle_type: String) -> void:
	if racer != "player" or hit_flash == null:
		return
	hit_flash.color.a = 0.45
	var tw_flash := create_tween()
	tw_flash.tween_property(hit_flash, "color:a", 0.0, 0.55)

# ── Race timer ────────────────────────────────────────────────────────────────
func _start_race_timer() -> void:
	time_left = 60.0
	while time_left > 0.0 and GameState.race_phase == GameState.RacePhase.RACING:
		await get_tree().create_timer(1.0).timeout
		time_left -= 1.0
	if GameState.race_phase == GameState.RacePhase.RACING:
		_end_by_distance()

func _end_by_distance() -> void:
	if GameState.player_position > GameState.ai_position:
		GameState.winner     = "Player"
		GameState.win_reason = "time_up"
	elif GameState.ai_position > GameState.player_position:
		GameState.winner     = "AI"
		GameState.win_reason = "time_up"
	else:
		GameState.winner     = "Player" if GameState.player_kei >= GameState.ai_kei else "AI"
		GameState.win_reason = "kei_tiebreak"
	GameState.set_phase(GameState.RacePhase.FINISHED)

func _on_phase_changed(new_phase) -> void:
	if new_phase == GameState.RacePhase.FINISHED:
		_display_results()

func _display_results() -> void:
	if results_shown:
		return
	results_shown = true
	results_menu.show()
	get_tree().paused = true

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
