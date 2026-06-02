# scripts/results_screen.gd
# ─────────────────────────────────────────────────────────────────────────────
# ResultsScreen — CanvasLayer that overlays on race finish.
# Reads all performance and algorithm counters from GameState and displays
# them in a two-column stat panel with a full-width Algorithm Metrics section.
# ─────────────────────────────────────────────────────────────────────────────
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

const STAT_COLOR         : Color = Color(0.75, 0.75, 0.75, 1.00)
const PLAYER_HDR_COLOR   : Color = Color(0.30, 0.85, 1.00, 1.00)
const AI_HDR_COLOR       : Color = Color(1.00, 0.55, 0.15, 1.00)

const ALGO_HDR_COLOR     : Color = Color(0.80, 0.50, 1.00, 1.00)
const ALGO_TILE_LABEL    : Color = Color(0.65, 0.65, 0.65, 1.00)
const ALGO_BG_COLOR      : Color = Color(0.10, 0.07, 0.16, 0.95)
const ALGO_DIV_COLOR     : Color = Color(0.45, 0.30, 0.65, 0.60)

const REMATCH_COLOR      : Color = Color(0.20, 0.65, 0.20, 1.00)
const QUIT_COLOR         : Color = Color(0.75, 0.15, 0.15, 1.00)
const TIME_COLOR         : Color = Color(0.95, 0.95, 0.60, 1.00)
const VSEP_COLOR         : Color = Color(0.35, 0.35, 0.50, 0.80)

# Difficulty badge colors matching the main menu buttons
const DIFF_COLORS : Array = [
	Color(0.30, 1.00, 0.40, 1.0),   # EASY   – green
	Color(1.00, 0.80, 0.20, 1.0),   # MEDIUM – gold
	Color(1.00, 0.40, 0.40, 1.0),   # HARD   – red
]
const DIFF_NAMES : Array = ["EASY", "MEDIUM", "HARD"]

# ── Font Sizes ────────────────────────────────────────────────────────────────
const TITLE_FONT_SIZE     : int = 52
const SUBTITLE_FONT_SIZE  : int = 28
const TIME_FONT_SIZE      : int = 24
const DIFF_FONT_SIZE      : int = 22
const SECTION_FONT_SIZE   : int = 24
const STAT_FONT_SIZE      : int = 20
const ALGO_TILE_HDR_SIZE  : int = 16
const ALGO_TILE_VAL_SIZE  : int = 28
const BUTTON_FONT_SIZE    : int = 28

# ── Node References ───────────────────────────────────────────────────────────
var _font    : FontFile = null
var _ui_root : Control  = null

var _winner_lbl  : Label  = null
var _reason_lbl  : Label  = null
var _time_lbl    : Label  = null
var _diff_lbl    : Label  = null   # NEW – difficulty badge
var _rematch_btn : Button = null

# Player stat value labels (right-aligned in each row)
var _p_kei_lbl     : Label = null
var _p_hurdles_lbl : Label = null
var _p_slides_lbl  : Label = null
var _p_colls_lbl   : Label = null
var _p_sab_lbl     : Label = null
var _p_streak_lbl  : Label = null
var _p_dist_lbl    : Label = null

# AI stat value labels
var _a_kei_lbl     : Label = null
var _a_hurdles_lbl : Label = null
var _a_slides_lbl  : Label = null
var _a_colls_lbl   : Label = null
var _a_sab_lbl     : Label = null
var _a_hits_lbl    : Label = null   # NEW – sabotage hits (replaces missing 7th row)
var _a_dist_lbl    : Label = null

# Algorithm metric tile value labels
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

# ─────────────────────────────────────────────────────────────────────────────
#  EVENT HANDLER
# ─────────────────────────────────────────────────────────────────────────────

func _on_race_finished(_winner_name: String) -> void:
	_resolve_winner()     # ensure winner is set even for time_up
	_refresh_labels()

	_ui_root.modulate.a = 0.0
	show()

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ui_root, "modulate:a", 1.0, 0.4)

	if _rematch_btn:
		_rematch_btn.grab_focus()

# If the race ended by time_up and winner was never explicitly set,
# determine the winner by position then by KEI (tiebreaker rules from Table 5).
func _resolve_winner() -> void:
	if not GameState.winner.is_empty():
		return
	if GameState.player_position > GameState.ai_position:
		GameState.winner = "player"
	elif GameState.ai_position > GameState.player_position:
		GameState.winner = "ai"
	else:
		# Exact distance tie — higher KEI wins
		GameState.winner = "player" if GameState.player_kei >= GameState.ai_kei else "ai"

# ─────────────────────────────────────────────────────────────────────────────
#  DATA POPULATION
# ─────────────────────────────────────────────────────────────────────────────

func _refresh_labels() -> void:
	# ── Winner ──────────────────────────────────────────────────────────────
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

	# ── Victory reason ───────────────────────────────────────────────────────
	match GameState.win_reason:
		"finish_line":
			_reason_lbl.text = "Victory by: Finish Line Crossing"
		"time_up":
			_reason_lbl.text = "Victory by: Time Limit (Distance Comparison)"
		_:
			var r : String = GameState.win_reason.replace("_", " ").capitalize()
			_reason_lbl.text = "Victory by: " + r

	# ── Match duration ───────────────────────────────────────────────────────
	var t          : float = maxf(0.0, 60.0 - GameState.match_timer)
	var m          : int   = int(t / 60.0)
	var s          : int   = int(t) % 60
	var cs         : int   = int(fmod(t, 1.0) * 100)
	_time_lbl.text = "Match Duration:  %02d:%02d.%02d" % [m, s, cs]

	# ── Difficulty badge ─────────────────────────────────────────────────────
	var diff_idx        : int = clampi(int(GameState.difficulty), 0, 2)
	_diff_lbl.text     = "Difficulty:  " + DIFF_NAMES[diff_idx]
	_diff_lbl.modulate  = DIFF_COLORS[diff_idx]

	# ── Player stats ─────────────────────────────────────────────────────────
	_p_kei_lbl.text     = "%.3f"  % GameState.player_kei
	_p_hurdles_lbl.text = "%d"    % GameState.player_hurdles_dodged
	_p_slides_lbl.text  = "%d"    % GameState.player_slides_done
	_p_colls_lbl.text   = "%d"    % GameState.player_collisions
	_p_sab_lbl.text     = "%d"    % GameState.player_sabotages_used
	_p_streak_lbl.text  = "%d"    % GameState.player_best_streak
	_p_dist_lbl.text    = "%.0f px" % GameState.player_position

	# ── AI stats ─────────────────────────────────────────────────────────────
	_a_kei_lbl.text     = "%.3f"  % GameState.ai_kei
	_a_hurdles_lbl.text = "%d"    % GameState.ai_hurdles_dodged
	_a_slides_lbl.text  = "%d"    % GameState.ai_slides_done
	_a_colls_lbl.text   = "%d"    % GameState.ai_collisions
	_a_sab_lbl.text     = "%d"    % GameState.ai_sabotages_activated
	_a_hits_lbl.text    = "%d"    % GameState.ai_sabotage_hits
	_a_dist_lbl.text    = "%.0f px" % GameState.ai_position

	# ── Algorithm metrics ────────────────────────────────────────────────────
	_algo_astar_lbl.text   = "%d" % GameState.ai_astar_plans
	_algo_idastar_lbl.text = "%d" % GameState.ai_idastar_fallbacks
	_algo_greedy_lbl.text  = "%d" % GameState.ai_greedy_count
	_algo_minimax_lbl.text = "%d" % GameState.ai_minimax_activations

	var hits : int   = GameState.ai_sabotage_hits
	var acts : int   = GameState.ai_sabotages_activated
	var rate : float = (float(hits) / float(acts) * 100.0) if acts > 0 else 0.0
	_algo_hitrate_lbl.text = "%.1f%%" % rate

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

# ─────────────────────────────────────────────────────────────────────────────
#  UI CONSTRUCTION
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Root + dark overlay ───────────────────────────────────────────────────
	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_root)

	var overlay := ColorRect.new()
	overlay.color        = OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(overlay)

	# ── ScrollContainer so panel never clips on small windows ─────────────────
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_root.add_child(scroll)

	# ── Center wrapper ────────────────────────────────────────────────────────
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	# ── Outer panel ───────────────────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG_COLOR, PANEL_BORDER_COLOR, 16, 4))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# ── 1. HEADER SECTION ────────────────────────────────────────────────────
	_winner_lbl = _make_label("RACE FINISHED", TITLE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
	main_vbox.add_child(_winner_lbl)

	_reason_lbl = _make_label("Victory by: --", SUBTITLE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, Color.LIGHT_GRAY)
	main_vbox.add_child(_reason_lbl)

	_time_lbl = _make_label("Match Duration:  00:00.00", TIME_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, TIME_COLOR)
	main_vbox.add_child(_time_lbl)

	_diff_lbl = _make_label("Difficulty:  MEDIUM", DIFF_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, DIFF_COLORS[1])
	main_vbox.add_child(_diff_lbl)

	_add_hdivider(main_vbox, PANEL_BORDER_COLOR)

	# ── 2. STATS COLUMNS ─────────────────────────────────────────────────────
	var columns_hbox := HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 0)
	columns_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(columns_hbox)

	# 2a. Player column
	var player_col := VBoxContainer.new()
	player_col.add_theme_constant_override("separation", 10)
	player_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(player_col)

	player_col.add_child(_make_label("HUMAN PLAYER", SECTION_FONT_SIZE,
			HORIZONTAL_ALIGNMENT_CENTER, PLAYER_HDR_COLOR))
	_add_hdivider(player_col, PLAYER_HDR_COLOR)

	_p_kei_lbl     = _add_stat_row(player_col, "Final KEI")
	_p_hurdles_lbl = _add_stat_row(player_col, "High Jumps")
	_p_slides_lbl  = _add_stat_row(player_col, "Low Slides")
	_p_colls_lbl   = _add_stat_row(player_col, "Collisions")
	_p_sab_lbl     = _add_stat_row(player_col, "Sabotages Used")
	_p_streak_lbl  = _add_stat_row(player_col, "Max Sprint Combo")
	_p_dist_lbl    = _add_stat_row(player_col, "Distance")

	# Vertical separator between columns
	var vsep := ColorRect.new()
	vsep.custom_minimum_size  = Vector2(2, 0)
	vsep.color                = VSEP_COLOR
	vsep.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(vsep)

	# Add 12 px padding on each side of the separator
	_add_hspacer(columns_hbox, 12)
	columns_hbox.move_child(vsep, 1)

	# 2b. AI column
	var ai_col := VBoxContainer.new()
	ai_col.add_theme_constant_override("separation", 10)
	ai_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(ai_col)

	ai_col.add_child(_make_label("OPPONENT AI", SECTION_FONT_SIZE,
			HORIZONTAL_ALIGNMENT_CENTER, AI_HDR_COLOR))
	_add_hdivider(ai_col, AI_HDR_COLOR)

	_a_kei_lbl     = _add_stat_row(ai_col, "Final KEI")
	_a_hurdles_lbl = _add_stat_row(ai_col, "High Jumps")
	_a_slides_lbl  = _add_stat_row(ai_col, "Low Slides")
	_a_colls_lbl   = _add_stat_row(ai_col, "Collisions")
	_a_sab_lbl     = _add_stat_row(ai_col, "Sabotages Fired")
	_a_hits_lbl    = _add_stat_row(ai_col, "Sabotage Hits")   # matches player's 6th row
	_a_dist_lbl    = _add_stat_row(ai_col, "Distance")

	_add_hdivider(main_vbox, PANEL_BORDER_COLOR)

	# ── 3. ALGORITHM METRICS — full-width panel ───────────────────────────────
	var algo_panel := PanelContainer.new()
	algo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	algo_panel.add_theme_stylebox_override("panel",
			_panel_style(ALGO_BG_COLOR, ALGO_DIV_COLOR, 8, 2))
	main_vbox.add_child(algo_panel)

	var algo_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		algo_margin.add_theme_constant_override("margin_" + side, 18)
	algo_panel.add_child(algo_margin)

	var algo_vbox := VBoxContainer.new()
	algo_vbox.add_theme_constant_override("separation", 10)
	algo_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	algo_margin.add_child(algo_vbox)

	algo_vbox.add_child(_make_label("ALGORITHM METRICS  (AI Decision Stack)",
			SECTION_FONT_SIZE - 2, HORIZONTAL_ALIGNMENT_CENTER, ALGO_HDR_COLOR))
	_add_hdivider(algo_vbox, ALGO_DIV_COLOR)

	# 5 stat tiles in a horizontal row
	var tiles_hbox := HBoxContainer.new()
	tiles_hbox.add_theme_constant_override("separation", 8)
	tiles_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	algo_vbox.add_child(tiles_hbox)

	_algo_astar_lbl   = _add_algo_tile(tiles_hbox, "A*\nPLANS")
	_algo_idastar_lbl = _add_algo_tile(tiles_hbox, "IDA*\nUSED")
	_algo_greedy_lbl  = _add_algo_tile(tiles_hbox, "GREEDY\nEVASIONS")
	_algo_minimax_lbl = _add_algo_tile(tiles_hbox, "MINIMAX\nTRIGGERS")
	_algo_hitrate_lbl = _add_algo_tile(tiles_hbox, "SABOTAGE\nHIT RATE")

	_add_hdivider(main_vbox, PANEL_BORDER_COLOR)

	# ── 4. ACTION BUTTONS ────────────────────────────────────────────────────
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(btn_hbox)

	_rematch_btn = _make_button("REMATCH",    REMATCH_COLOR)
	_rematch_btn.pressed.connect(_on_rematch_pressed)
	btn_hbox.add_child(_rematch_btn)

	var quit_btn := _make_button("MAIN MENU", QUIT_COLOR)
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_hbox.add_child(quit_btn)

# ─────────────────────────────────────────────────────────────────────────────
#  COMPONENT FACTORIES
# ─────────────────────────────────────────────────────────────────────────────

func _make_label(text: String, size: int,
		align: HorizontalAlignment, color: Color) -> Label:
	var lbl                  := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = align
	lbl.modulate             = color
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(lbl, size)
	return lbl

# One stat row: "[label_text]:    [value -- right-aligned]"
func _add_stat_row(parent: VBoxContainer, label: String) -> Label:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := _make_label(label + ":", STAT_FONT_SIZE,
			HORIZONTAL_ALIGNMENT_LEFT, STAT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var val := _make_label("--", STAT_FONT_SIZE,
			HORIZONTAL_ALIGNMENT_RIGHT, Color.WHITE)
	val.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(val)

	parent.add_child(hbox)
	return val

# One algo tile: title (small, two-line) above value (large)
func _add_algo_tile(parent: HBoxContainer, title: String) -> Label:
	var vbox := VBoxContainer.new()
	vbox.alignment           = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	parent.add_child(vbox)

	var ttl := _make_label(title, ALGO_TILE_HDR_SIZE,
			HORIZONTAL_ALIGNMENT_CENTER, ALGO_TILE_LABEL)
	vbox.add_child(ttl)

	var val := _make_label("--", ALGO_TILE_VAL_SIZE,
			HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
	vbox.add_child(val)

	return val

func _make_button(label_text: String, bg_color: Color) -> Button:
	var btn                     := Button.new()
	btn.text                    = label_text
	btn.custom_minimum_size     = Vector2(280, 64)
	btn.focus_mode              = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_font(btn, BUTTON_FONT_SIZE)

	var normal  := StyleBoxFlat.new()
	normal.bg_color = bg_color.darkened(0.2)
	normal.set_corner_radius_all(8)

	var hover   := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.1)
	hover.set_corner_radius_all(8)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.4)
	pressed.set_corner_radius_all(8)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("focus",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn

# ─────────────────────────────────────────────────────────────────────────────
#  STYLING HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _apply_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)

func _add_hdivider(parent: Node, color: Color) -> void:
	var d                     := ColorRect.new()
	d.custom_minimum_size     = Vector2(0, 2)
	d.color                   = color
	d.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	parent.add_child(d)

func _add_hspacer(parent: Node, width: float) -> void:
	var s                   := Control.new()
	s.custom_minimum_size   = Vector2(width, 0)
	parent.add_child(s)

func _panel_style(bg: Color, border: Color,
		radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	return s
