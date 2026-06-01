# results_screen.gd
# ─────────────────────────────────────────────────────────────────────────────
# Match Results overlay.
# Scene setup: CanvasLayer root → attach this script → save as
# res://scenes/ResultsScreen.tscn → instance as child of main.tscn.
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

const MAIN_MENU_SCENE : String = "res://scenes/main_menu.tscn"

const OVERLAY_COLOR      : Color = Color(0.00, 0.00, 0.00, 0.78)
const PANEL_BG_COLOR     : Color = Color(0.06, 0.06, 0.10, 0.97)
const PANEL_BORDER_COLOR : Color = Color(0.35, 0.35, 0.50, 0.80)
const PLAYER_WIN_COLOR   : Color = Color(0.30, 0.85, 1.00, 1.00)
const AI_WIN_COLOR       : Color = Color(1.00, 0.55, 0.15, 1.00)
const TIE_COLOR          : Color = Color(0.85, 0.85, 0.85, 1.00)
const STAT_COLOR         : Color = Color(0.72, 0.72, 0.72, 1.00)
const REMATCH_COLOR      : Color = Color(0.18, 0.60, 0.18, 1.00)
const QUIT_COLOR         : Color = Color(0.60, 0.12, 0.12, 1.00)
const TITLE_FONT_SIZE    : int   = 32
const SUBTITLE_FONT_SIZE : int   = 17
const STAT_FONT_SIZE     : int   = 15
const BUTTON_FONT_SIZE   : int   = 17

var _font           : FontFile = null
var _winner_lbl     : Label    = null
var _reason_lbl     : Label    = null
var _player_kei_lbl : Label    = null
var _ai_kei_lbl     : Label    = null
var _time_lbl       : Label    = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 25
	_load_font()
	_build_ui()
	hide()
	GameState.race_finished.connect(_on_race_finished)

func _load_font() -> void:
	const FONT_PATH : String = "res://assets/new/BoldPixels.ttf"
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile

func _on_race_finished(_winner_name: String) -> void:
	_refresh_labels()
	show()

func _refresh_labels() -> void:
	match GameState.winner:
		"player":
			_winner_lbl.text     = "PLAYER WINS!"
			_winner_lbl.modulate = PLAYER_WIN_COLOR
		"ai":
			_winner_lbl.text     = "AI WINS!"
			_winner_lbl.modulate = AI_WIN_COLOR
		_:
			_winner_lbl.text     = "IT'S A TIE!"
			_winner_lbl.modulate = TIE_COLOR

	match GameState.win_reason:
		"finish_line": _reason_lbl.text = "Finish Line Crossed!"
		"time_up":     _reason_lbl.text = "Time's Up!"
		_:             _reason_lbl.text = ""

	_player_kei_lbl.text = "Player KEI  :  %.0f%%" % (GameState.player_kei * 100.0)
	_ai_kei_lbl.text     = "AI KEI         :  %.0f%%" % (GameState.ai_kei     * 100.0)

	var e  : float = GameState.race_elapsed_time
	var m  : int   = int(e / 60.0)
	var s  : int   = int(e) % 60
	var cs : int   = int(fmod(e, 1.0) * 100)
	_time_lbl.text = "Race Time  :  %02d:%02d.%02d" % [m, s, cs]

# ── Button callbacks ──────────────────────────────────────────────────────────
func _on_rematch_pressed() -> void:
	hide()
	get_tree().paused = false   # FIX: main.gd pauses tree on match end
	GameState.reset_match()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	hide()
	get_tree().paused = false   # FIX: main.gd pauses tree on match end
	GameState.reset_match()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	var overlay          := ColorRect.new()
	overlay.name         =  "Overlay"
	overlay.color        =  OVERLAY_COLOR
	overlay.mouse_filter =  Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel            := PanelContainer.new()
	panel.name           =  "ResultPanel"
	panel.anchor_left    =  0.5
	panel.anchor_right   =  0.5
	panel.anchor_top     =  0.5
	panel.anchor_bottom  =  0.5
	panel.offset_left    = -210.0
	panel.offset_right   =  210.0
	panel.offset_top     = -210.0
	panel.offset_bottom  =  210.0

	var ps := StyleBoxFlat.new()
	ps.bg_color                        =  PANEL_BG_COLOR
	ps.corner_radius_top_left          =  12
	ps.corner_radius_top_right         =  12
	ps.corner_radius_bottom_left       =  12
	ps.corner_radius_bottom_right      =  12
	ps.border_width_left               =  2
	ps.border_width_right              =  2
	ps.border_width_top                =  2
	ps.border_width_bottom             =  2
	ps.border_color                    =  PANEL_BORDER_COLOR
	ps.content_margin_left             =  26.0
	ps.content_margin_right            =  26.0
	ps.content_margin_top              =  26.0
	ps.content_margin_bottom           =  26.0
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var vbox             := VBoxContainer.new()
	vbox.alignment       =  BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_winner_lbl = Label.new()
	_winner_lbl.text               = "?"
	_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_winner_lbl, TITLE_FONT_SIZE)
	vbox.add_child(_winner_lbl)

	_reason_lbl = Label.new()
	_reason_lbl.text               = ""
	_reason_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_lbl.modulate           = STAT_COLOR
	_apply_font(_reason_lbl, SUBTITLE_FONT_SIZE)
	vbox.add_child(_reason_lbl)

	_add_spacer(vbox, 4.0)
	var div              := ColorRect.new()
	div.custom_minimum_size = Vector2(0.0, 2.0)
	div.color            =  PANEL_BORDER_COLOR
	vbox.add_child(div)
	_add_spacer(vbox, 4.0)

	_player_kei_lbl = _make_stat_label("Player KEI  :  --")
	vbox.add_child(_player_kei_lbl)
	_ai_kei_lbl = _make_stat_label("AI KEI         :  --")
	vbox.add_child(_ai_kei_lbl)
	_time_lbl = _make_stat_label("Race Time  :  --:--")
	vbox.add_child(_time_lbl)

	_add_spacer(vbox, 10.0)

	var rematch_btn := _make_button("REMATCH",           REMATCH_COLOR)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	vbox.add_child(rematch_btn)

	var quit_btn    := _make_button("QUIT TO MAIN MENU", QUIT_COLOR)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _make_stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = STAT_COLOR
	_apply_font(lbl, STAT_FONT_SIZE)
	return lbl

func _make_button(label_text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(330.0, 50.0)
	btn.focus_mode = Control.FOCUS_ALL

	var normal := StyleBoxFlat.new()
	normal.bg_color                   = bg_color
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left        = 12.0
	normal.content_margin_right       = 12.0
	normal.content_margin_top         = 8.0
	normal.content_margin_bottom      = 8.0

	var hover   := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg_color.darkened(0.15)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	_apply_font_btn(btn, BUTTON_FONT_SIZE)
	return btn

func _apply_font(label: Label, size: int) -> void:
	if _font: label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)

func _apply_font_btn(btn: Button, size: int) -> void:
	if _font: btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", size)

func _add_spacer(parent: Node, height: float) -> void:
	var s                 := Control.new()
	s.custom_minimum_size  = Vector2(0.0, height)
	parent.add_child(s)
