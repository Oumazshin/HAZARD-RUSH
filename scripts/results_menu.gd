
extends CanvasLayer

const FONT    := "res://assets/new/BoldPixels.ttf"
const BTN_TEX := "res://assets/new/button.png"

var _winner_label : Label
var _reason_label : Label
var _font: Font = null

func _ready() -> void:
	if ResourceLoader.exists(FONT):
		_font = load(FONT)
	var old_panel := get_node_or_null("Panel")
	if old_panel:
		old_panel.hide()
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)

func _apply_font(node: Control, size: int, color: Color) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)

func _make_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(170, 50)
	_apply_font(btn, 16, Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	if ResourceLoader.exists(BTN_TEX):
		var sheet := load(BTN_TEX)
		for state_name in ["normal", "hover", "pressed", "focus"]:
			var idx: int = {"normal":0,"hover":1,"pressed":2,"focus":3}[state_name]
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(idx * 16, 0, 16, 16)
			var s := StyleBoxTexture.new()
			s.texture = atlas
			s.texture_margin_left = 4.0
			s.texture_margin_right = 4.0
			s.texture_margin_top = 3.0
			s.texture_margin_bottom = 3.0
			btn.add_theme_stylebox_override(state_name, s)
		btn.modulate = color
	else:
		for state in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = color if state == "normal" else \
						 (color.lightened(0.18) if state == "hover" else \
						 (color.darkened(0.15) if state == "pressed" else color))
			s.border_color = color.lightened(0.35)
			s.set_border_width_all(1)
			s.set_corner_radius_all(8)
			s.set_content_margin_all(12)
			btn.add_theme_stylebox_override(state, s)
	return btn

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

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

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_winner_label = Label.new()
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_winner_label, 52, Color(1.0, 0.85, 0.20))
	vbox.add_child(_winner_label)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.90, 0.75, 0.20, 0.50)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 2)
	vbox.add_child(sep)

	_reason_label = Label.new()
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_reason_label, 20, Color(0.82, 0.82, 0.82))
	vbox.add_child(_reason_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(spacer)

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

func _on_play_again() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
