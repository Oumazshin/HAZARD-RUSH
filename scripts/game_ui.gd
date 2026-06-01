# game_ui.gd
# ─────────────────────────────────────────────────────────────────────────────
# In-game HUD overlay. All UI nodes are built programmatically in _ready()
# so the scene file is minimal. Attach to scenes/GameUI.tscn (CanvasLayer).
# Add GameUI.tscn to main.tscn (the scene that holds both sub-viewports).
#
# Displays:
#   • Match countdown timer  (top centre — driven by GameState.match_timer_updated)
#   • Player / AI speed bars (upper-left / lower-left of their respective halves)
#   • Screen divider         (horizontal line at the centre of the screen)
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

# ── Asset paths ───────────────────────────────────────────────────────────────
const FONT_PATH     : String = "res://assets/Global/text/fonts/BoldPixels.ttf"
const ICON_RESTART  : String = "res://assets/Global/Icons/Restart.png"
const ICON_SETTINGS : String = "res://assets/Global/Icons/Settings.png"

# ── Visual config ─────────────────────────────────────────────────────────────
const MAX_SPEED         : float   = 500.0
const LABEL_FONT_SIZE   : int     = 16
const TIMER_FONT_SIZE   : int     = 22
const BAR_MIN_SIZE      : Vector2 = Vector2(120, 14)
const DIVIDER_THICKNESS : int     = 4
const DIVIDER_COLOR     : Color   = Color(0.05, 0.05, 0.05, 0.95)
const TIMER_BG_COLOR    : Color   = Color(0.0,  0.0,  0.0,  0.55)
const P1_BAR_COLOR      : Color   = Color(0.3,  0.85, 1.0,  1.0)
const AI_BAR_COLOR      : Color   = Color(1.0,  0.55, 0.15, 1.0)
const TIMER_URGENT_COLOR: Color   = Color(1.0,  0.25, 0.15, 1.0)  # red flash < 10 s
const HUD_MARGIN        : float   = 10.0

# ── Runtime state ─────────────────────────────────────────────────────────────
var _font          : FontFile    = null
var _prev_p_x      : float       = 0.0
var _prev_a_x      : float       = 0.0

# UI node references (created in _build_ui)
var _timer_label   : Label       = null
var _p_speed_bar   : ProgressBar = null
var _a_speed_bar   : ProgressBar = null
var _p_speed_label : Label       = null
var _a_speed_label : Label       = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 10
	_load_font()
	_build_ui()
	# Drive the countdown display from GameState's authoritative timer signal
	GameState.match_timer_updated.connect(_on_match_timer_updated)

func _process(delta: float) -> void:
	_update_speed_bars(delta)
	_prev_p_x = GameState.player_position
	_prev_a_x = GameState.ai_position

# ── Public ────────────────────────────────────────────────────────────────────
func reset() -> void:
	if _timer_label:
		_timer_label.text    = "01:00.00"
		_timer_label.modulate = Color.WHITE

# ── Build ─────────────────────────────────────────────────────────────────────
func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile
	else:
		push_warning("[GameUI] Font not found: '%s'" % FONT_PATH)

func _build_ui() -> void:
	var root := Control.new()
	root.name           = "UIRoot"
	root.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_divider(root)
	_build_timer(root)
	_build_speed_hud(root, true)    # Player — upper section
	_build_speed_hud(root, false)   # AI     — lower section

# ── Screen divider ────────────────────────────────────────────────────────────
func _build_divider(parent: Control) -> void:
	var div             := ColorRect.new()
	div.name            =  "Divider"
	div.color           =  DIVIDER_COLOR
	div.mouse_filter    =  Control.MOUSE_FILTER_IGNORE
	div.anchor_left     =  0.0
	div.anchor_right    =  1.0
	div.anchor_top      =  0.5
	div.anchor_bottom   =  0.5
	div.offset_top      = -float(DIVIDER_THICKNESS) / 2.0
	div.offset_bottom   =  float(DIVIDER_THICKNESS) / 2.0
	parent.add_child(div)

# ── Countdown timer ───────────────────────────────────────────────────────────
func _build_timer(parent: Control) -> void:
	var bg              := PanelContainer.new()
	bg.name             =  "TimerPanel"
	bg.mouse_filter     =  Control.MOUSE_FILTER_IGNORE
	bg.anchor_left      =  0.5
	bg.anchor_right     =  0.5
	bg.anchor_top       =  0.0
	bg.anchor_bottom    =  0.0
	bg.offset_left      = -70.0
	bg.offset_right     =  70.0
	bg.offset_top       =  4.0
	bg.offset_bottom    =  44.0

	var panel_style     := StyleBoxFlat.new()
	panel_style.bg_color = TIMER_BG_COLOR
	panel_style.corner_radius_top_left     = 6
	panel_style.corner_radius_top_right    = 6
	panel_style.corner_radius_bottom_left  = 6
	panel_style.corner_radius_bottom_right = 6
	bg.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(bg)

	_timer_label                      = Label.new()
	_timer_label.name                 = "CountdownTimer"
	_timer_label.text                 = "01:00.00"   # initial display = 60 s
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_timer_label.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_apply_font(_timer_label, TIMER_FONT_SIZE)
	bg.add_child(_timer_label)

# ── Speed HUD (per player) ────────────────────────────────────────────────────
func _build_speed_hud(parent: Control, is_player: bool) -> void:
	var anchor_top    : float  = 0.0      if is_player else 0.5
	var anchor_bottom : float  = 0.5      if is_player else 1.0
	var label_text    : String = "PLAYER" if is_player else "AI"
	var bar_color     : Color  = P1_BAR_COLOR if is_player else AI_BAR_COLOR

	var hud           := VBoxContainer.new()
	hud.name          =  "PlayerHUD" if is_player else "AIHUD"
	hud.mouse_filter  =  Control.MOUSE_FILTER_IGNORE
	hud.anchor_left   =  0.0
	hud.anchor_right  =  0.0
	hud.anchor_top    =  anchor_top
	hud.anchor_bottom =  anchor_bottom
	hud.offset_left   =  HUD_MARGIN
	hud.offset_right  =  HUD_MARGIN + 180.0
	hud.offset_top    =  HUD_MARGIN
	hud.offset_bottom = -HUD_MARGIN
	parent.add_child(hud)

	var name_lbl          := Label.new()
	name_lbl.text         =  label_text
	name_lbl.mouse_filter =  Control.MOUSE_FILTER_IGNORE
	_apply_font(name_lbl, LABEL_FONT_SIZE)
	hud.add_child(name_lbl)

	var row           := HBoxContainer.new()
	row.mouse_filter  =  Control.MOUSE_FILTER_IGNORE
	hud.add_child(row)

	var speed_val                 := Label.new()
	speed_val.text                =  "0"
	speed_val.custom_minimum_size =  Vector2(42, 0)
	speed_val.mouse_filter        =  Control.MOUSE_FILTER_IGNORE
	_apply_font(speed_val, LABEL_FONT_SIZE)
	row.add_child(speed_val)

	var bar                := ProgressBar.new()
	bar.min_value          =  0.0
	bar.max_value          =  1.0
	bar.value              =  0.0
	bar.show_percentage    =  false
	bar.custom_minimum_size = BAR_MIN_SIZE
	bar.mouse_filter       =  Control.MOUSE_FILTER_IGNORE

	var fill_style         := StyleBoxFlat.new()
	fill_style.bg_color    =  bar_color
	var bg_style           := StyleBoxFlat.new()
	bg_style.bg_color      =  Color(0.08, 0.08, 0.08, 0.7)
	bar.add_theme_stylebox_override("fill",       fill_style)
	bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(bar)

	if is_player:
		_p_speed_bar   = bar
		_p_speed_label = speed_val
	else:
		_a_speed_bar   = bar
		_a_speed_label = speed_val

func _apply_font(label: Label, size: int) -> void:
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)

# ── Countdown update (signal-driven from GameState) ───────────────────────────
func _on_match_timer_updated(time_left: float) -> void:
	if _timer_label == null:
		return
	var t   : float = maxf(time_left, 0.0)
	var m   : int   = int(t / 60.0)
	var s   : int   = int(t) % 60
	var cs  : int   = int(fmod(t, 1.0) * 100)
	_timer_label.text = "%02d:%02d.%02d" % [m, s, cs]
	# Visual urgency: flash red when ≤ 10 seconds remain
	_timer_label.modulate = TIMER_URGENT_COLOR if t <= 10.0 else Color.WHITE

# ── Speed bar update ──────────────────────────────────────────────────────────
func _update_speed_bars(delta: float) -> void:
	if delta <= 0.0:
		return
	var pv : float = clamp(
		abs(GameState.player_position - _prev_p_x) / (delta * MAX_SPEED), 0.0, 1.0)
	var av : float = clamp(
		abs(GameState.ai_position - _prev_a_x) / (delta * MAX_SPEED), 0.0, 1.0)

	if _p_speed_bar:   _p_speed_bar.value  = pv
	if _a_speed_bar:   _a_speed_bar.value  = av
	if _p_speed_label: _p_speed_label.text = "%d" % int(pv * MAX_SPEED)
	if _a_speed_label: _a_speed_label.text = "%d" % int(av * MAX_SPEED)
