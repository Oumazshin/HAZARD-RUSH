extends Control

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	GameState.reset()
	_build_ui()

func _build_ui() -> void:
	var screen_size = get_viewport_rect().size

	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.15)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Center column
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(420, 500)
	vbox.position = Vector2(screen_size.x / 2.0 - 210.0, screen_size.y / 2.0 - 250.0)
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "HAZARD RUSH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Race against the AI!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(subtitle)

	# Divider
	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(1.0, 0.85, 0.0, 0.35)
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 2)
	vbox.add_child(sep)

	# Difficulty label
	var diff_label = Label.new()
	diff_label.text = "SELECT DIFFICULTY"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 15)
	diff_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(diff_label)

	# Difficulty buttons row
	var diff_hbox = HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(diff_hbox)

	var easy_btn   = _make_diff_button("EASY",   Color(0.15, 0.55, 0.20))
	var medium_btn = _make_diff_button("MEDIUM", Color(0.75, 0.55, 0.05))
	var hard_btn   = _make_diff_button("HARD",   Color(0.60, 0.10, 0.10))

	easy_btn.pressed.connect(
		_on_difficulty_pressed.bind(GameState.Difficulty.EASY,   easy_btn, medium_btn, hard_btn))
	medium_btn.pressed.connect(
		_on_difficulty_pressed.bind(GameState.Difficulty.MEDIUM, easy_btn, medium_btn, hard_btn))
	hard_btn.pressed.connect(
		_on_difficulty_pressed.bind(GameState.Difficulty.HARD,   easy_btn, medium_btn, hard_btn))

	diff_hbox.add_child(easy_btn)
	diff_hbox.add_child(medium_btn)
	diff_hbox.add_child(hard_btn)

	# Default: Medium selected
	GameState.difficulty = GameState.Difficulty.MEDIUM
	_set_selected(medium_btn, Color(0.75, 0.55, 0.05))

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Play button
	var play_btn = _make_action_button("PLAY", Color(0.10, 0.50, 0.20))
	play_btn.custom_minimum_size = Vector2(320, 62)
	play_btn.add_theme_font_size_override("font_size", 28)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	# Controls hint
	var controls = Label.new()
	controls.text = "A / D = Sprint     SPACE = Jump     S = Slide"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(controls)

	# Quit button
	var quit_btn = _make_action_button("QUIT", Color(0.40, 0.10, 0.10))
	quit_btn.custom_minimum_size = Vector2(320, 46)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

# ── Button factories ──────────────────────────────────────────────────────────

func _make_diff_button(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(110, 46)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_apply_style(btn, color, false)
	return btn

func _make_action_button(label: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(320, 50)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_apply_style(btn, color, false)
	return btn

func _apply_style(btn: Button, color: Color, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var s = StyleBoxFlat.new()
		if state == "normal":
			s.bg_color = color.darkened(0.2) if not selected else color.lightened(0.15)
		elif state == "hover":
			s.bg_color = color.lightened(0.15)
		elif state == "pressed":
			s.bg_color = color.darkened(0.15)
		else:
			s.bg_color = color.darkened(0.2)
		s.border_color = Color(1.0, 0.85, 0.0) if selected else color.lightened(0.3)
		s.set_border_width_all(2 if selected else 1)
		s.set_corner_radius_all(8)
		s.set_content_margin_all(10)
		btn.add_theme_stylebox_override(state, s)

func _set_selected(btn: Button, color: Color) -> void:
	_apply_style(btn, color, true)

func _set_unselected(btn: Button, color: Color) -> void:
	_apply_style(btn, color, false)

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
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
