extends Control

# ── Asset paths ───────────────────────────────────────────────────────────────
const BG_IMAGE       := "res://assets/backgrounds/BG 3.jpg"
const FONT           := "res://assets/new/BoldPixels.ttf"
const BTN_TEX        := "res://assets/new/button.png"
const ENTRY_TEX      := "res://assets/new/Entry.png"
const LOADING_TEX    := "res://assets/new/LOADING_CYCLE.png"
const LOGO_PATH      := "res://assets/Logo/Logo.svg"

# Path to the pre-menu overlay scene
const PRE_MENU_SCENE := "res://scenes/pre_menu.tscn"

var _font: Font = null

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	if ResourceLoader.exists(FONT):
		_font = load(FONT)
	GameState.reset()
	_build_ui()
	# ── Open the pre-game Intro / Credits / Disclaimer overlay on launch ──────
	# The overlay is a CanvasLayer (layer 10) added on top of this scene.
	# It is self-removing: the player clicks CONTINUE and it calls queue_free().
	# It can be reopened at any time via the INFO button added in _build_ui().
	_open_pre_menu()


# ── Pre-menu open / reopen ────────────────────────────────────────────────────

## Opens the overlay only if it is not already open.
## The instantiated scene's root node is named "PreMenu" (defined in pre_menu.tscn),
## so has_node("PreMenu") reliably detects whether it is currently active.
func _open_pre_menu() -> void:
	if not has_node("PreMenu"):
		add_child(preload(PRE_MENU_SCENE).instantiate())


func _build_ui() -> void:
	# ── Background ────────────────────────────────────────────────────────────
	if ResourceLoader.exists(BG_IMAGE):
		var bg_tex := TextureRect.new()
		bg_tex.texture = load(BG_IMAGE)
		bg_tex.set_anchors_preset(PRESET_FULL_RECT)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_tex)

	# ── Dark overlay ──────────────────────────────────────────────────────────
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── Full-screen center for menu VBox ──────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# ── Center column ─────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# ── Top Entry stripe ──────────────────────────────────────────────────────
	if ResourceLoader.exists(ENTRY_TEX):
		var entry_rect := TextureRect.new()
		entry_rect.texture = load(ENTRY_TEX)
		entry_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		entry_rect.stretch_mode = TextureRect.STRETCH_SCALE
		entry_rect.custom_minimum_size = Vector2(440, 32)
		entry_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(entry_rect)

	# NOTE: The logo is NOT placed here.
	# It floats independently at the top of the screen (see bottom of this
	# function). Removing it from the VBox means the menu items below are
	# centered freely without any logo-imposed gap pushing them down.
	# If the logo SVG is missing, the fallback title label is added here.
	if not ResourceLoader.exists(LOGO_PATH):
		var title := Label.new()
		title.text = "HAZARD RUSH"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_font(title, 48, Color(1.0, 0.85, 0.0))
		vbox.add_child(title)

	# ── Subtitle ──────────────────────────────────────────────────────────────
	var subtitle := Label.new()
	subtitle.text = "Race against the AI!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(subtitle, 16, Color(0.80, 0.80, 0.80))
	vbox.add_child(subtitle)

	# ── Bottom Entry stripe ───────────────────────────────────────────────────
	if ResourceLoader.exists(ENTRY_TEX):
		var entry2 := TextureRect.new()
		entry2.texture = load(ENTRY_TEX)
		entry2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		entry2.stretch_mode = TextureRect.STRETCH_SCALE
		entry2.flip_h = true
		entry2.custom_minimum_size = Vector2(440, 32)
		entry2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(entry2)

	# ── Difficulty label ──────────────────────────────────────────────────────
	var diff_label := Label.new()
	diff_label.text = "SELECT DIFFICULTY"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(diff_label, 14, Color(0.88, 0.88, 0.88))
	vbox.add_child(diff_label)

	# ── Difficulty buttons row ────────────────────────────────────────────────
	var diff_hbox := HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(diff_hbox)

	var easy_btn   := _make_diff_button("EASY",   Color(0.15, 0.55, 0.20))
	var medium_btn := _make_diff_button("MEDIUM", Color(0.75, 0.55, 0.05))
	var hard_btn   := _make_diff_button("HARD",   Color(0.60, 0.10, 0.10))

	easy_btn.pressed.connect(
		_on_difficulty_pressed.bind(GameState.Difficulty.EASY,   easy_btn, medium_btn, hard_btn))
	medium_btn.pressed.connect(
		_on_difficulty_pressed.bind(GameState.Difficulty.MEDIUM, easy_btn, medium_btn, hard_btn))
	hard_btn.pressed.connect(
		_on_difficulty_pressed.bind(GameState.Difficulty.HARD,   easy_btn, medium_btn, hard_btn))

	diff_hbox.add_child(easy_btn)
	diff_hbox.add_child(medium_btn)
	diff_hbox.add_child(hard_btn)

	GameState.difficulty = GameState.Difficulty.MEDIUM
	_set_selected(medium_btn, Color(0.75, 0.55, 0.05))

	# ── Spacer ────────────────────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# ── PLAY button ───────────────────────────────────────────────────────────
	var play_btn := _make_action_button("▶  PLAY", Color(0.10, 0.50, 0.20))
	play_btn.custom_minimum_size = Vector2(320, 62)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	# ── Controls hint ─────────────────────────────────────────────────────────
	var controls := Label.new()
	controls.text = "A / D = Sprint    SPACE = Jump    SHIFT = Slide    F = Sabotage"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(controls, 12, Color(0.70, 0.70, 0.70))
	vbox.add_child(controls)

	# ── Quit button ───────────────────────────────────────────────────────────
	var quit_btn := _make_action_button("QUIT", Color(0.40, 0.10, 0.10))
	quit_btn.custom_minimum_size = Vector2(320, 46)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	# ── Floating logo ─────────────────────────────────────────────────────────
	if ResourceLoader.exists(LOGO_PATH):
		var logo_rect                 := TextureRect.new()
		logo_rect.texture             = load(LOGO_PATH) as Texture2D
		logo_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		logo_rect.set_anchors_preset(Control.PRESET_CENTER_TOP)
		logo_rect.grow_horizontal     = Control.GROW_DIRECTION_BOTH
		logo_rect.grow_vertical       = Control.GROW_DIRECTION_END
		logo_rect.offset_left         = -210.0
		logo_rect.offset_right        = 210.0
		logo_rect.offset_top          = 12.0
		logo_rect.offset_bottom       = 232.0
		add_child(logo_rect)

	# ── INFO button — bottom-right corner, reopens the pre-menu overlay ───────
	# Floats independently from the VBox so it never disrupts the menu layout.
	# Anchored to PRESET_BOTTOM_RIGHT so it stays in the corner at any
	# window size.  Clicking it calls _open_pre_menu() which guards against
	# opening a second copy if one is already showing.
	var info_btn := Button.new()
	info_btn.text = "  \u2139  DISCLAIMER  "   # ℹ INFO
	info_btn.focus_mode = Control.FOCUS_NONE
	info_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	info_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_btn.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	# Position: 16 px from right edge, 16 px from bottom edge
	info_btn.offset_left   = -130.0
	info_btn.offset_right  = -16.0
	info_btn.offset_top    = -52.0
	info_btn.offset_bottom = -16.0
	_apply_font(info_btn, 13, Color(0.957, 0.769, 0.188))   # gold text
	# Style: dark semi-transparent with gold border
	var s_norm := StyleBoxFlat.new()
	s_norm.bg_color = Color(0.039, 0.055, 0.102, 0.85)
	s_norm.border_color = Color(0.957, 0.769, 0.188, 0.70)
	s_norm.set_border_width_all(1)
	s_norm.set_corner_radius_all(6)
	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = Color(0.188, 0.255, 0.376, 0.95)
	s_hover.border_color = Color(0.957, 0.769, 0.188, 1.0)
	s_hover.set_border_width_all(1)
	s_hover.set_corner_radius_all(6)
	var s_press := StyleBoxFlat.new()
	s_press.bg_color = Color(0.039, 0.055, 0.102, 1.0)
	s_press.border_color = Color(0.957, 0.769, 0.188, 1.0)
	s_press.set_border_width_all(1)
	s_press.set_corner_radius_all(6)
	info_btn.add_theme_stylebox_override("normal",  s_norm)
	info_btn.add_theme_stylebox_override("hover",   s_hover)
	info_btn.add_theme_stylebox_override("pressed", s_press)
	info_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	info_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	info_btn.pressed.connect(_open_pre_menu)
	add_child(info_btn)


# ── Helpers ───────────────────────────────────────────────────────────────────
func _apply_font(node: Control, font_size: int, color: Color) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)

func _btn_style_tex(state_idx: int) -> StyleBoxTexture:
	var sheet := load(BTN_TEX)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(state_idx * 16, 0, 16, 16)
	var s := StyleBoxTexture.new()
	s.texture = atlas
	s.texture_margin_left   = 4.0
	s.texture_margin_right  = 4.0
	s.texture_margin_top    = 3.0
	s.texture_margin_bottom = 3.0
	return s

func _btn_style_flat(color: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color.lightened(0.15) if selected else color.darkened(0.2)
	s.border_color = Color(1.0, 0.85, 0.0) if selected else color.lightened(0.3)
	s.set_border_width_all(2 if selected else 1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s

func _apply_button_style(btn: Button, color: Color, selected: bool) -> void:
	var has_tex := ResourceLoader.exists(BTN_TEX)
	if has_tex:
		btn.add_theme_stylebox_override("normal",  _btn_style_tex(0))
		btn.add_theme_stylebox_override("hover",   _btn_style_tex(1))
		btn.add_theme_stylebox_override("pressed", _btn_style_tex(2))
		btn.add_theme_stylebox_override("focus",   _btn_style_tex(3))
		btn.modulate = color.lightened(0.2) if selected else Color.WHITE
	else:
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, _btn_style_flat(color, selected))

func _make_diff_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(110, 46)
	_apply_font(btn, 14, Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_apply_button_style(btn, color, false)
	return btn

func _make_action_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(320, 50)
	_apply_font(btn, 18, Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_apply_button_style(btn, color, false)
	return btn

func _set_selected(btn: Button, color: Color) -> void:
	_apply_button_style(btn, color, true)

func _set_unselected(btn: Button, color: Color) -> void:
	_apply_button_style(btn, color, false)

# ── Callbacks ─────────────────────────────────────────────────────────────────
func _on_difficulty_pressed(diff: GameState.Difficulty,
		easy: Button, medium: Button, hard: Button) -> void:
	GameState.difficulty = diff
	_set_unselected(easy,   Color(0.15, 0.55, 0.20))
	_set_unselected(medium, Color(0.75, 0.55, 0.05))
	_set_unselected(hard,   Color(0.60, 0.10, 0.10))
	match diff:
		GameState.Difficulty.EASY:   _set_selected(easy,   Color(0.15, 0.55, 0.20))
		GameState.Difficulty.MEDIUM: _set_selected(medium, Color(0.75, 0.55, 0.05))
		GameState.Difficulty.HARD:   _set_selected(hard,   Color(0.60, 0.10, 0.10))

func _on_play_pressed() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)

	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)

	if ResourceLoader.exists(LOADING_TEX):
		var cycle_sheet := load(LOADING_TEX)
		var sf := SpriteFrames.new()
		sf.add_animation("spin")
		for i in 6:
			var a := AtlasTexture.new()
			a.atlas = cycle_sheet
			a.region = Rect2(i * 40, 0, 40, 36)
			sf.add_frame("spin", a)
		sf.set_animation_loop("spin", true)
		sf.set_animation_speed("spin", 12.0)
		var spinner := AnimatedSprite2D.new()
		spinner.sprite_frames = sf
		spinner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spinner.scale = Vector2(3.0, 3.0)
		spinner.position = get_viewport_rect().size / 2.0
		cl.add_child(spinner)
		spinner.play("spin")

	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, 1.0), 0.45)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
