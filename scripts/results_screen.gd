extends CanvasLayer

# ── Scene Paths ───────────────────────────────────────────────────────────────
const MAIN_MENU_SCENE : String = "res://scenes/main_menu.tscn"
const FONT_PATH       : String = "res://assets/Global/text/fonts/BoldPixels.ttf"

# ── Colors ────────────────────────────────────────────────────────────────────
const OVERLAY_COLOR      : Color = Color(0.00, 0.00, 0.00, 0.85)
const PANEL_BG_COLOR     : Color = Color(0.08, 0.08, 0.12, 0.95)
const PANEL_BORDER_COLOR : Color = Color(0.40, 0.40, 0.55, 0.90)

const PLAYER_WIN_COLOR   : Color = Color(0.30, 0.85, 1.00, 1.00)
const AI_WIN_COLOR       : Color = Color(1.00, 0.55, 0.15, 1.00)
const TIE_COLOR          : Color = Color(0.85, 0.85, 0.85, 1.00)

const STAT_COLOR         : Color = Color(0.88, 0.88, 0.88, 1.00)
const PLAYER_HDR_COLOR   : Color = Color(0.30, 0.85, 1.00, 1.00)
const AI_HDR_COLOR       : Color = Color(1.00, 0.55, 0.15, 1.00)

const ALGO_HDR_COLOR     : Color = Color(0.80, 0.50, 1.00, 1.00)
const ALGO_STAT_COLOR    : Color = Color(0.90, 0.80, 1.00, 1.00)
const ALGO_BG_COLOR      : Color = Color(0.12, 0.08, 0.18, 0.95)
const ALGO_DIV_COLOR     : Color = Color(0.45, 0.30, 0.65, 0.60)

const REMATCH_COLOR      : Color = Color(0.20, 0.65, 0.20, 1.00)
const QUIT_COLOR         : Color = Color(0.75, 0.15, 0.15, 1.00)
const TIME_COLOR         : Color = Color(0.95, 0.95, 0.60, 1.00)

# ── Font Sizes ────────────────────────────────────────────────────────────────
const TITLE_FONT_SIZE     : int = 56
const SUBTITLE_FONT_SIZE  : int = 32
const TIME_FONT_SIZE      : int = 28
const SECTION_FONT_SIZE   : int = 26
const STAT_FONT_SIZE      : int = 22
const ALGO_STAT_FONT_SIZE : int = 20
const BUTTON_FONT_SIZE    : int = 30

# ── Node References ───────────────────────────────────────────────────────────
var _font    : FontFile = null
var _ui_root : Control  = null

var _winner_lbl  : Label  = null
var _reason_lbl  : Label  = null
var _time_lbl    : Label  = null
var _rematch_btn : Button = null

# Player stat labels
var _p_kei_lbl     : Label = null
var _p_hurdles_lbl : Label = null
var _p_slides_lbl  : Label = null
var _p_colls_lbl   : Label = null
var _p_sab_lbl     : Label = null
var _p_streak_lbl  : Label = null
var _p_dist_lbl    : Label = null

# AI stat labels
var _a_kei_lbl     : Label = null
var _a_hurdles_lbl : Label = null
var _a_slides_lbl  : Label = null
var _a_colls_lbl   : Label = null
var _a_sab_lbl     : Label = null
var _a_dist_lbl    : Label = null

# Algorithm stat labels
var _algo_astar_lbl   : Label = null
var _algo_idastar_lbl : Label = null
var _algo_greedy_lbl  : Label = null
var _algo_minimax_lbl : Label = null
var _algo_hitrate_lbl : Label = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	_load_font()
	_build_ui()
	hide()

	if GameState.has_signal("race_finished"):
		GameState.race_finished.connect(_on_race_finished)

func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile
	else:
		push_warning("[ResultsScreen] Font not found at %s. Using default." % FONT_PATH)

func _on_race_finished(_winner_name: String) -> void:
	_refresh_labels()

	_ui_root.modulate.a = 0.0
	show()

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ui_root, "modulate:a", 1.0, 0.4)

	if _rematch_btn:
		_rematch_btn.grab_focus()

func _refresh_labels() -> void:
	match GameState.winner:
		"player":
			_winner_lbl.text     = "PLAYER WINS!"
			_winner_lbl.modulate = PLAYER_WIN_COLOR
		"ai":
			_winner_lbl.text     = "OPPONENT AI WINS!"
			_winner_lbl.modulate = AI_WIN_COLOR
		_:
			_winner_lbl.text     = "IT'S A TIE!"
			_winner_lbl.modulate = TIE_COLOR

	_reason_lbl.text = "Victory by: " + String(GameState.get("win_reason")).replace("_", " ").capitalize()

	var t : float      = GameState.get("match_timer") if GameState.get("match_timer") != null else 60.0
	var time_spent : float = maxf(0.0, 60.0 - t)
	var m  : int   = int(time_spent / 60.0)
	var s  : int   = int(time_spent) % 60
	var cs : int   = int(fmod(time_spent, 1.0) * 100)
	_time_lbl.text = "Match Duration: %02d:%02d.%02d" % [m, s, cs]

# ── Button Callbacks ──────────────────────────────────────────────────────────

func _on_rematch_pressed() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_ui_root, "modulate:a", 0.0, 0.2)
	await tween.finished
	hide()

	get_tree().paused = false
	if GameState.has_method("reset_match"):
		GameState.reset_match()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_ui_root, "modulate:a", 0.0, 0.2)
	await tween.finished
	hide()

	get_tree().paused = false
	if GameState.has_method("reset_match"):
		GameState.reset_match()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_root)

	var overlay := ColorRect.new()
	overlay.color        = OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _get_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   50)
	margin.add_theme_constant_override("margin_right",  50)
	margin.add_theme_constant_override("margin_top",    40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	margin.add_child(main_vbox)

	# 1. Header
	_winner_lbl = _make_label("RACE FINISHED", TITLE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
	main_vbox.add_child(_winner_lbl)

	_reason_lbl = _make_label("Reason: --", SUBTITLE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, Color.LIGHT_GRAY)
	main_vbox.add_child(_reason_lbl)

	_time_lbl = _make_label("Match Duration: 00:00.00", TIME_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, TIME_COLOR)
	main_vbox.add_child(_time_lbl)

	_add_hdivider(main_vbox, PANEL_BORDER_COLOR)

	# 2. Stats Columns
	var columns_hbox := HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 80)
	columns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(columns_hbox)

	# 2a. Player Column
	var player_col := VBoxContainer.new()
	player_col.add_theme_constant_override("separation", 12)
	player_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(player_col)

	player_col.add_child(_make_label("HUMAN PLAYER", SECTION_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, PLAYER_HDR_COLOR))
	_add_hdivider(player_col, PANEL_BORDER_COLOR)

	_p_kei_lbl     = _add_stat_row(player_col, "Avg. KEI")
	_p_hurdles_lbl = _add_stat_row(player_col, "High Jumps")
	_p_slides_lbl  = _add_stat_row(player_col, "Low Slides")
	_p_colls_lbl   = _add_stat_row(player_col, "Collisions")
	_p_sab_lbl     = _add_stat_row(player_col, "Sabotages Used")
	_p_streak_lbl  = _add_stat_row(player_col, "Max Combo")
	_p_dist_lbl    = _add_stat_row(player_col, "Distance (px)")

	# 2b. AI Column
	var ai_col := VBoxContainer.new()
	ai_col.add_theme_constant_override("separation", 12)
	ai_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(ai_col)

	ai_col.add_child(_make_label("OPPONENT AI", SECTION_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, AI_HDR_COLOR))
	_add_hdivider(ai_col, PANEL_BORDER_COLOR)

	_a_kei_lbl     = _add_stat_row(ai_col, "Avg. KEI")
	_a_hurdles_lbl = _add_stat_row(ai_col, "High Jumps")
	_a_slides_lbl  = _add_stat_row(ai_col, "Low Slides")
	_a_colls_lbl   = _add_stat_row(ai_col, "Collisions")
	_a_sab_lbl     = _add_stat_row(ai_col, "Sabotages Used")
	_a_dist_lbl    = _add_stat_row(ai_col, "Distance (px)")

	_add_spacer(ai_col, 10)

	# Algorithm Panel
	var algo_panel := PanelContainer.new()
	algo_panel.add_theme_stylebox_override("panel", _get_algo_style())
	ai_col.add_child(algo_panel)

	var algo_margin := MarginContainer.new()
	algo_margin.add_theme_constant_override("margin_left",   20)
	algo_margin.add_theme_constant_override("margin_right",  20)
	algo_margin.add_theme_constant_override("margin_top",    16)
	algo_margin.add_theme_constant_override("margin_bottom", 16)
	algo_panel.add_child(algo_margin)

	var algo_vbox := VBoxContainer.new()
	algo_vbox.add_theme_constant_override("separation", 8)
	algo_margin.add_child(algo_vbox)

	algo_vbox.add_child(_make_label("ALGORITHM METRICS", SECTION_FONT_SIZE - 2, HORIZONTAL_ALIGNMENT_CENTER, ALGO_HDR_COLOR))
	_add_hdivider(algo_vbox, ALGO_DIV_COLOR)

	_algo_astar_lbl   = _add_algo_row(algo_vbox, "A* Plans")
	_algo_idastar_lbl = _add_algo_row(algo_vbox, "IDA* Fallbacks")
	_algo_greedy_lbl  = _add_algo_row(algo_vbox, "Greedy Evasions")
	_algo_minimax_lbl = _add_algo_row(algo_vbox, "Minimax Triggers")
	_algo_hitrate_lbl = _add_algo_row(algo_vbox, "Hazard Hit Rate")

	_add_spacer(main_vbox, 20)

	# 3. Action Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(btn_hbox)

	_rematch_btn = _make_button("REMATCH", REMATCH_COLOR)
	_rematch_btn.pressed.connect(_on_rematch_pressed)
	btn_hbox.add_child(_rematch_btn)

	var quit_btn := _make_button("MAIN MENU", QUIT_COLOR)
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_hbox.add_child(quit_btn)

# ── Component Factories ───────────────────────────────────────────────────────

func _make_label(text: String, size: int, align: HorizontalAlignment, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = align
	lbl.modulate             = color
	_apply_font(lbl, size)
	return lbl

func _add_stat_row(parent: VBoxContainer, label: String) -> Label:
	var hbox     := HBoxContainer.new()
	var title    := _make_label(label + ":", STAT_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, STAT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	var val_lbl  := _make_label("--", STAT_FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT, Color.WHITE)
	hbox.add_child(val_lbl)
	parent.add_child(hbox)
	return val_lbl

func _add_algo_row(parent: VBoxContainer, label: String) -> Label:
	var hbox    := HBoxContainer.new()
	var title   := _make_label(label + ":", ALGO_STAT_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, ALGO_STAT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	var val_lbl := _make_label("--", ALGO_STAT_FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT, Color.WHITE)
	hbox.add_child(val_lbl)
	parent.add_child(hbox)
	return val_lbl

func _make_button(label_text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text               = label_text
	btn.custom_minimum_size = Vector2(300.0, 70.0)
	btn.focus_mode         = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_font(btn, BUTTON_FONT_SIZE)

	# normal — slightly darkened base colour
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color.darkened(0.2)
	normal_style.set_corner_radius_all(8)

	# hover — slightly lightened base colour
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = bg_color.lightened(0.1)
	hover_style.set_corner_radius_all(8)

	# pressed — darkened further; must be a StyleBoxFlat, NOT StyleBoxFlat.darkened()
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = bg_color.darkened(0.4)
	pressed_style.set_corner_radius_all(8)

	btn.add_theme_stylebox_override("normal",  normal_style)
	btn.add_theme_stylebox_override("hover",   hover_style)
	btn.add_theme_stylebox_override("focus",   hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

# ── Styling Helpers ───────────────────────────────────────────────────────────

func _apply_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)

func _add_spacer(parent: Node, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, height)
	parent.add_child(s)

func _add_hdivider(parent: Node, color: Color) -> void:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(0.0, 3.0)
	d.color = color
	parent.add_child(d)

func _get_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG_COLOR
	s.set_corner_radius_all(16)
	s.set_border_width_all(4)
	s.border_color = PANEL_BORDER_COLOR
	return s

func _get_algo_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ALGO_BG_COLOR
	s.set_corner_radius_all(8)
	s.set_border_width_all(2)
	s.border_color = ALGO_DIV_COLOR
	return s
