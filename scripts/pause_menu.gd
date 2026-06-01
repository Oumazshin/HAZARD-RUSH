# pause_menu.gd
# ─────────────────────────────────────────────────────────────────────────────
# Pause Menu overlay.
#
# Scene setup (do this once):
#   1. In Godot Editor → Scene menu → New Scene
#   2. Root node type: CanvasLayer  → rename it "PauseMenu"
#   3. Attach this script to that CanvasLayer node
#   4. Save as res://scenes/PauseMenu.tscn
#   5. Open your main game scene (main.tscn)
#   6. In the Scene panel, right-click the root node → Instantiate Child Scene
#      → select PauseMenu.tscn
#   7. Save main.tscn
#
# How it works:
#   • Press Escape during RACING → game pauses (SceneTree.paused = true)
#   • Press Escape again, or click RESUME → game unpauses
#   • PROCESS_MODE_ALWAYS is set in _ready() so this node keeps receiving
#     input and button signals even while the SceneTree is paused.
#   • If the match ends (time-up or finish line) while the menu is open,
#     _on_phase_changed() auto-closes it and unpauses the tree.
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

# ── ⚠ Verify this path matches your project ───────────────────────────────────
const MAIN_MENU_SCENE : String = "res://scenes/MainMenu.tscn"

# ── Visual constants ──────────────────────────────────────────────────────────
const OVERLAY_COLOR      : Color = Color(0.00, 0.00, 0.00, 0.65)
const PANEL_BG_COLOR     : Color = Color(0.08, 0.08, 0.12, 0.97)
const PANEL_BORDER_COLOR : Color = Color(0.35, 0.35, 0.50, 0.80)
const TITLE_COLOR        : Color = Color(1.00, 0.85, 0.25, 1.00)
const RESUME_COLOR       : Color = Color(0.18, 0.60, 0.18, 1.00)
const QUIT_COLOR         : Color = Color(0.60, 0.12, 0.12, 1.00)
const TITLE_FONT_SIZE    : int   = 28
const BUTTON_FONT_SIZE   : int   = 17

var _font : FontFile = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# CRITICAL: must be ALWAYS so this node processes while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 20   # above GameUI (layer 10)
	_load_font()
	_build_ui()
	hide()   # hidden until the player presses Escape
	GameState.phase_changed.connect(_on_phase_changed)

func _load_font() -> void:
	const FONT_PATH : String = "res://assets/Global/text/fonts/BoldPixels.ttf"
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile

# ─────────────────────────────────────────────────────────────────────────────
#  Input — Escape toggles pause only during active racing
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Block pause during countdown, pre-match, and finished states
	if GameState.race_phase != GameState.RacePhase.RACING:
		return
	if visible:
		_resume()
	else:
		_pause()

# ─────────────────────────────────────────────────────────────────────────────
#  Pause / Resume
# ─────────────────────────────────────────────────────────────────────────────
func _pause() -> void:
	get_tree().paused = true
	show()

func _resume() -> void:
	get_tree().paused = false
	hide()

# Auto-close if the match ends (time-up or finish line) while we are open
func _on_phase_changed(new_phase: GameState.RacePhase) -> void:
	if new_phase == GameState.RacePhase.FINISHED and visible:
		get_tree().paused = false
		hide()

# ─────────────────────────────────────────────────────────────────────────────
#  Button callbacks
# ─────────────────────────────────────────────────────────────────────────────
func _on_resume_pressed() -> void:
	_resume()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	GameState.reset_match()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ─────────────────────────────────────────────────────────────────────────────
#  UI — built programmatically (no child nodes needed in the .tscn)
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Full-screen dark overlay — absorbs clicks so the game isn't clickable
	var overlay          := ColorRect.new()
	overlay.name         =  "Overlay"
	overlay.color        =  OVERLAY_COLOR
	overlay.mouse_filter =  Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Centred panel container
	var panel            := PanelContainer.new()
	panel.name           =  "Panel"
	panel.anchor_left    =  0.5
	panel.anchor_right   =  0.5
	panel.anchor_top     =  0.5
	panel.anchor_bottom  =  0.5
	panel.offset_left    = -170.0
	panel.offset_right   =  170.0
	panel.offset_top     = -145.0
	panel.offset_bottom  =  145.0

	var ps := StyleBoxFlat.new()
	ps.bg_color                        =  PANEL_BG_COLOR
	ps.corner_radius_top_left          =  10
	ps.corner_radius_top_right         =  10
	ps.corner_radius_bottom_left       =  10
	ps.corner_radius_bottom_right      =  10
	ps.border_width_left               =  2
	ps.border_width_right              =  2
	ps.border_width_top                =  2
	ps.border_width_bottom             =  2
	ps.border_color                    =  PANEL_BORDER_COLOR
	ps.content_margin_left             =  22.0
	ps.content_margin_right            =  22.0
	ps.content_margin_top              =  22.0
	ps.content_margin_bottom           =  22.0
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var vbox             := VBoxContainer.new()
	vbox.alignment       =  BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# ── Title ──────────────────────────────────────────────────────────────
	var title            := Label.new()
	title.text           =  "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate       =  TITLE_COLOR
	_apply_font(title, TITLE_FONT_SIZE)
	vbox.add_child(title)

	# ── Thin divider ───────────────────────────────────────────────────────
	var div              := ColorRect.new()
	div.custom_minimum_size = Vector2(0.0, 2.0)
	div.color            =  PANEL_BORDER_COLOR
	vbox.add_child(div)

	_add_spacer(vbox, 6.0)

	# ── Resume ─────────────────────────────────────────────────────────────
	var resume_btn := _make_button("RESUME", RESUME_COLOR)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	# ── Quit ───────────────────────────────────────────────────────────────
	var quit_btn := _make_button("QUIT TO MAIN MENU", QUIT_COLOR)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _make_button(label_text: String, bg_color: Color) -> Button:
	var btn                  := Button.new()
	btn.text                  = label_text
	btn.custom_minimum_size   = Vector2(300.0, 50.0)
	btn.focus_mode            = Control.FOCUS_ALL

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

	var hover := normal.duplicate() as StyleBoxFlat
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
	var s                    := Control.new()
	s.custom_minimum_size     = Vector2(0.0, height)
	parent.add_child(s)
