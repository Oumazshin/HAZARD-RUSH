extends CanvasLayer

var _winner_label : Label
var _reason_label : Label

func _ready() -> void:
	# Hide the old scene nodes so our new UI takes over
	var old_panel = get_node_or_null("Panel")
	if old_panel:
		old_panel.hide()

	_build_ui()
	visibility_changed.connect(_on_visibility_changed)

# ── Build the entire UI through code ─────────────────────────────────────────

func _build_ui() -> void:
	# Dark overlay behind the card
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center container keeps card in the middle of the screen
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Card
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color          = Color(0.07, 0.07, 0.10, 0.97)
	card_style.border_color      = Color(0.90, 0.75, 0.20)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.set_content_margin_all(44)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	# Vertical layout inside card
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Winner text
	_winner_label = Label.new()
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", 52)
	_winner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	vbox.add_child(_winner_label)

	# Gold divider
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.90, 0.75, 0.20, 0.50)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 2)
	vbox.add_child(sep)

	# Win reason
	_reason_label = Label.new()
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.add_theme_font_size_override("font_size", 20)
	_reason_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	vbox.add_child(_reason_label)

	# Space before buttons
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(spacer)

	# Button row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var play_btn := _make_button("PLAY AGAIN", Color(0.13, 0.55, 0.22))
	play_btn.pressed.connect(_on_play_again)
	hbox.add_child(play_btn)

	var quit_btn := _make_button("MAIN MENU", Color(0.45, 0.13, 0.13))
	quit_btn.pressed.connect(_on_quit)
	hbox.add_child(quit_btn)

func _make_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(170, 50)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",         Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color",   Color.WHITE)

	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color     = color if state == "normal" else \
						 (color.lightened(0.18) if state == "hover" else \
						 (color.darkened(0.15) if state == "pressed" else color))
		s.border_color = color.lightened(0.35)
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		s.set_content_margin_all(12)
		btn.add_theme_stylebox_override(state, s)
	return btn

# ── Display logic ─────────────────────────────────────────────────────────────

func _on_visibility_changed() -> void:
	if not visible or _winner_label == null:
		return

	match GameState.winner:
		"Player":
			_winner_label.text = "YOU WIN!"
			_winner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
		"AI":
			_winner_label.text = "AI WINS!"
			_winner_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_:
			_winner_label.text = "IT'S A TIE!"
			_winner_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))

	match GameState.win_reason:
		"finish_line":  _reason_label.text = "Crossed the finish line first."
		"time_up":      _reason_label.text = "Time ran out — greater distance covered."
		"kei_tiebreak": _reason_label.text = "Time ran out — decided by KEI."
		_:              _reason_label.text = ""

# ── Buttons ───────────────────────────────────────────────────────────────────

func _on_play_again() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
