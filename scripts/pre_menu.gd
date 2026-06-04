extends CanvasLayer

#  HAZARD RUSH — Group 6, BSCS 3-3
#  COSC 304: Introduction to Artificial Intelligence
#  PUP – College of Computer and Information Sciences
#  June 2026
# =============================================================

const FONT_PATH := "res://assets/new/BoldPixels.ttf"

# ── Brand palette ──────────────────────────────────────────────────────────────
const C_BG        := Color(0.039, 0.055, 0.102, 1.0)   # #0A0E1A  card dark
const C_GOLD      := Color(0.957, 0.769, 0.188, 1.0)   # #F4C430  accent gold
const C_RED       := Color(0.902, 0.224, 0.275, 1.0)   # #E63946  danger red
const C_GREEN     := Color(0.10,  0.50,  0.20,  1.0)   # matches PLAY button
const C_TEXT      := Color(0.941, 0.941, 0.941, 1.0)   # #F0F0F0  body
const C_MUTED     := Color(0.706, 0.706, 0.706, 1.0)   # #B4B4B4  muted
const C_BTN_DARK  := Color(0.118, 0.180, 0.251, 1.0)   # #1E2D40  nav button bg
const C_HEADER_BG := Color(0.188, 0.255, 0.376, 1.0)   # #304160  badge bg

var _font: Font = null

# Panel references
var _intro_panel:      Control
var _credits_panel:    Control
var _disclaimer_panel: Control
var _active_panel:     Control


# ══════════════════════════════════════════════════════════════════════════════
#  BOOT
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 10
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build_ui()


# ══════════════════════════════════════════════════════════════════════════════
#  TOP-LEVEL LAYOUT
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# Root control fills the entire viewport
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Semi-transparent dark backdrop — main menu stays visible behind
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	# Center container
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)

	# Main card — wider and taller for larger font comfort
	var card := _make_card()
	centre.add_child(card)

	var card_margin := MarginContainer.new()
	for prop in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		card_margin.add_theme_constant_override(prop, 32)
	card.add_child(card_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card_margin.add_child(vbox)

	vbox.add_child(_build_title_bar())
	vbox.add_child(_make_divider())

	# Content host — three panels overlap here; only one is visible at a time
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	vbox.add_child(host)

	_intro_panel      = _build_intro_panel()
	_credits_panel    = _build_credits_panel()
	_disclaimer_panel = _build_disclaimer_panel()

	for panel: Control in [_intro_panel, _credits_panel, _disclaimer_panel]:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(panel)

	_credits_panel.visible    = false
	_disclaimer_panel.visible = false
	_active_panel             = _intro_panel

	vbox.add_child(_make_divider())
	vbox.add_child(_build_button_bar())
	vbox.add_child(_build_footer())


# ══════════════════════════════════════════════════════════════════════════════
#  TITLE BAR
# ══════════════════════════════════════════════════════════════════════════════
func _build_title_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Red vertical stripe accent
	var stripe := ColorRect.new()
	stripe.color = C_RED
	stripe.custom_minimum_size = Vector2(6, 44)
	row.add_child(stripe)
	_gap(row, 14)

	var title := Label.new()
	title.text = "\u26A1  HAZARD RUSH"
	_apply_font(title, 34, C_GOLD)   # ← 34 pt title
	row.add_child(title)

	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flex)

	row.add_child(_make_pill("GROUP 6  \u00B7  BSCS 3-3  \u00B7  PUP CCIS",
			C_HEADER_BG, C_MUTED, 12))   # ← 12 pt badge
	return row


# ══════════════════════════════════════════════════════════════════════════════
#  INTRO PANEL
# ══════════════════════════════════════════════════════════════════════════════
func _build_intro_panel() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(_make_section_header("ABOUT THE GAME"))
	vbox.add_child(_make_rtl_scroll(_get_intro_bbcode()))
	return vbox


func _get_intro_bbcode() -> String:
	return (
		"[color=#F4C430][b]HAZARD RUSH[/b][/color] is a two-dimensional competitive tactical "
		+ "racing game developed as a project requirement for [b]COSC 304: Introduction to "
		+ "Artificial Intelligence[/b] at the Polytechnic University of the Philippines.\n\n"
		+ "The game is structured as a [color=#F4C430]1v1 sprint[/color] in which a human "
		+ "player races against an AI-controlled opponent across a side-scrolling "
		+ "[b]110-meter hurdle course[/b]. The primary objective is to cross the finish line "
		+ "within [color=#E63946]60 seconds[/color] before the opposing runner.\n\n"
		+ "[color=#F4C430][b]THE AI OPPONENT[/b][/color]\n"
		+ "The AI is driven entirely by [b]four classical search algorithms[/b] from Russell "
		+ "& Norvig's [i]Artificial Intelligence: A Modern Approach[/i] (4th ed., 2021). "
		+ "There is [b]no machine learning[/b], no neural network, and no reinforcement "
		+ "learning anywhere in the system.\n\n"
		+ "[color=#F4C430]  \u25B8  A* Search[/color] — Cost-optimal obstacle lookahead planner (~250ms)\n"
		+ "[color=#F4C430]  \u25B8  IDA* Search[/color] — Memory-bounded fallback, O(N) memory\n"
		+ "[color=#F4C430]  \u25B8  Minimax + Alpha-Beta[/color] — Adversarial sabotage evaluator\n"
		+ "[color=#F4C430]  \u25B8  Greedy Best-First[/color] — Single-frame evasion reflex\n\n"
		+ "[color=#F4C430][b]HOW TO PLAY[/b][/color]\n"
		+ "[color=#E63946]\u25B8[/color]  [b]Sprint:[/b]    Alternate [color=#F4C430][A][/color]"
		+ " and [color=#F4C430][D][/color] within 200ms — builds KEI momentum\n"
		+ "[color=#E63946]\u25B8[/color]  [b]Jump:[/b]     Press [color=#F4C430][Space / \u2191][/color]"
		+ " — clears High Hurdles (0.40s\u20130.15s window)\n"
		+ "[color=#E63946]\u25B8[/color]  [b]Slide:[/b]    Hold [color=#F4C430][\u2193 / S][/color]"
		+ " for 0.30s — passes under Low Obstacles\n"
		+ "[color=#E63946]\u25B8[/color]  [b]Conserve:[/b] Hold [color=#F4C430][Shift][/color]"
		+ " — slows KEI decay; speed capped at 60\u0025\n"
		+ "[color=#E63946]\u25B8[/color]  [b]Sabotage:[/b] Press [color=#F4C430][F / RShift][/color]"
		+ " within the 0.30s trigger window\n\n"
		+ "[color=#F4C430][b]THE KEI SYSTEM[/b][/color]\n"
		+ "Your [b]Kinetic Exertion Indicator (KEI)[/b] is a normalized [0.0\u20131.0] momentum "
		+ "value updated at 60 fps. Velocity scales linearly with KEI. Obstacle collisions "
		+ "inflict [color=#E63946]50\u201375\u0025 KEI crashes[/color]. Both competitors follow "
		+ "[b]identical[/b] KEI rules — the AI holds no informational privilege."
	)


# ══════════════════════════════════════════════════════════════════════════════
#  CREDITS PANEL
# ══════════════════════════════════════════════════════════════════════════════
func _build_credits_panel() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(_make_section_header("CREDITS"))
	vbox.add_child(_make_rtl_scroll(_get_credits_bbcode()))
	return vbox


func _get_credits_bbcode() -> String:
	return (
		"[center][color=#F4C430][b]\u26A1  HAZARD RUSH[/b][/color]\n"
		+ "[color=#B4B4B4]BSCS 3-3  \u00B7  Group 6  \u00B7  June 2026[/color][/center]\n\n"
		+ "[color=#F4C430][b]DEVELOPMENT TEAM[/b][/color]\n"
		+ "[color=#F4C430]\u25B8[/color]  Bacolor, James Clark C.\n"
		+ "[color=#F4C430]\u25B8[/color]  Caole, Stephanie J.\n"
		+ "[color=#F4C430]\u25B8[/color]  Soriano, Shouma King J.\n\n"
		+ "[color=#F4C430][b]COURSE & FACULTY[/b][/color]\n"
		+ "[b]Course:[/b]       COSC 304 \u2014 Introduction to Artificial Intelligence\n"
		+ "[b]Program:[/b]      Bachelor of Science in Computer Science (BSCS)\n"
		+ "[b]Instructor:[/b]   Prof. Ria A. Sagum, MCS\n"
		+ "[b]College:[/b]      College of Computer and Information Sciences (CCIS)\n"
		+ "[b]University:[/b]   Polytechnic University of the Philippines \u2014 Sta. Mesa, Manila\n\n"
		+ "[color=#F4C430][b]AI ALGORITHM STACK[/b][/color]\n"
		+ "[color=#E63946]\u25CF[/color]  [b]A* Search[/b] \u2014 Cost-optimal obstacle lookahead planner\n"
		+ "   Lookahead N = 2\u20135 obstacles; invoked every 15 frames (~250ms at 60 fps)\n\n"
		+ "[color=#E63946]\u25CF[/color]  [b]IDA* Search[/b] \u2014 Memory-bounded fallback planner\n"
		+ "   f-cost threshold DFS; O(N) call stack; activates on A* FAILURE or N \u2264 2\n\n"
		+ "[color=#E63946]\u25CF[/color]  [b]Minimax + Alpha-Beta Pruning[/b] \u2014 Adversarial sabotage evaluator\n"
		+ "   4-ply game tree; MAX = AI, MIN = player; event-driven at trigger zones\n\n"
		+ "[color=#E63946]\u25CF[/color]  [b]Greedy Best-First Search[/b] \u2014 Immediate evasion reflex\n"
		+ "   f(n) = h(n) only; 2-node space; fires every frame in TTC [0.40s\u20130.15s]\n\n"
		+ "[color=#F4C430][b]REFERENCES[/b][/color]\n"
		+ "Russell, S. J., & Norvig, P. (2021). [i]Artificial Intelligence: A Modern Approach[/i] (4th ed.). Pearson.\n"
		+ "Hart, P. E., Nilsson, N. J., & Raphael, B. (1968). [i]IEEE Trans. Systems Science, 4[/i](2), 100\u2013107.\n"
		+ "Korf, R. E. (1985). Depth-first iterative-deepening. [i]Artificial Intelligence, 27[/i](1), 97\u2013109.\n\n"
		+ "[color=#F4C430][b]GAME INSPIRATION[/b][/color]\n"
		+ "Structurally inspired by [b]Track & Field[/b] (Konami, 1983). "
		+ "Referenced for academic attribution purposes only.\n\n"
		+ "[center][color=#B4B4B4]\u00A9 2026  \u00B7  PUP CCIS  \u00B7  BSCS 3-3 Group 6  \u00B7  Academic Use Only[/color][/center]"
	)


# ══════════════════════════════════════════════════════════════════════════════
#  DISCLAIMER PANEL
# ══════════════════════════════════════════════════════════════════════════════
func _build_disclaimer_panel() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(_make_section_header("DISCLAIMER"))
	vbox.add_child(_make_rtl_scroll(_get_disclaimer_bbcode()))
	return vbox


func _get_disclaimer_bbcode() -> String:
	return (
		"[color=#F4C430][b]ACADEMIC DISCLAIMER[/b][/color]\n\n"
		+ "This game, [b]HAZARD RUSH[/b], was developed by [b]Group 6 of BSCS 3-3[/b] as a "
		+ "project requirement for [b]COSC 304: Introduction to Artificial Intelligence[/b], "
		+ "under the Bachelor of Science in Computer Science (BSCS) program at the [b]College "
		+ "of Computer and Information Sciences (CCIS), Polytechnic University of the "
		+ "Philippines (PUP) \u2013 Sta. Mesa, Manila[/b]. This project was created solely "
		+ "for [color=#E63946]academic, educational, and demonstration purposes[/color] and "
		+ "was presented during the course final requirement period in [b]June 2026[/b].\n\n"
		+ "[color=#F4C430][b]AI METHODOLOGY[/b][/color]\n"
		+ "All game mechanics, AI algorithms, and system architectures implemented herein are "
		+ "original academic implementations by the group members. The AI opponent operates "
		+ "exclusively on [b]classical search algorithms[/b] \u2014 specifically [b]A* Search, "
		+ "IDA* Search, Minimax with Alpha-Beta Pruning, and Greedy Best-First Search[/b] \u2014 "
		+ "drawn from Russell and Norvig\u2019s [i]Artificial Intelligence: A Modern Approach[/i] "
		+ "(4th ed., 2021). [b]No machine learning, neural networks, or trained models[/b] of "
		+ "any kind are present in this system.\n\n"
		+ "[color=#F4C430][b]SCOPE & DISTRIBUTION[/b][/color]\n"
		+ "This system is intended for [b]local academic evaluation only[/b] and shall "
		+ "[color=#E63946]not[/color] be distributed publicly. No commercial use or "
		+ "redistribution outside the academic setting of PUP CCIS is authorized.\n\n"
		+ "[color=#F4C430][b]ASSET ATTRIBUTION[/b][/color]\n"
		+ "The developers make no commercial claims regarding any assets or inspirations "
		+ "referenced within this project. Structural inspiration was drawn from [b]Konami\u2019s "
		+ "1983 arcade release Track and Field[/b], acknowledged for academic attribution only. "
		+ "All original assets remain the intellectual property of their respective creators.\n\n"
		+ "[color=#F4C430][b]INSTITUTIONAL NOTICE[/b][/color]\n"
		+ "The [b]Polytechnic University of the Philippines[/b] does not endorse any commercial "
		+ "product or external service referenced within this project. The views and design "
		+ "decisions herein represent the academic work of the student group and do not reflect "
		+ "official positions of PUP or CCIS.\n\n"
		+ "[color=#B4B4B4][i]Group 6  \u00B7  BSCS 3-3  \u00B7  COSC 304 \u2014 Introduction "
		+ "to Artificial Intelligence\nPUP CCIS  \u00B7  Sta. Mesa, Manila  \u00B7  June 2026[/i][/color]"
	)


# ══════════════════════════════════════════════════════════════════════════════
#  BUTTON BAR
# ══════════════════════════════════════════════════════════════════════════════
func _build_button_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	# CONTINUE — dismisses this overlay, revealing the main menu beneath
	var cont_btn := _make_btn("\u25B6  CONTINUE", C_GREEN, Color.WHITE, 220)
	cont_btn.pressed.connect(_on_continue_pressed)
	row.add_child(cont_btn)

	var credits_btn := _make_btn("CREDITS", C_BTN_DARK, C_GOLD, 165)
	credits_btn.pressed.connect(_on_credits_pressed)
	row.add_child(credits_btn)

	var disc_btn := _make_btn("DISCLAIMER", C_BTN_DARK, C_GOLD, 165)
	disc_btn.pressed.connect(_on_disclaimer_pressed)
	row.add_child(disc_btn)

	return row


# ══════════════════════════════════════════════════════════════════════════════
#  FOOTER
# ══════════════════════════════════════════════════════════════════════════════
func _build_footer() -> Label:
	var lbl := Label.new()
	lbl.text = "COSC 304: Introduction to Artificial Intelligence  \u00B7  PUP CCIS  \u00B7  June 2026"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(lbl, 12, Color(C_MUTED.r, C_MUTED.g, C_MUTED.b, 0.45))   # ← 12 pt footer
	return lbl


# ══════════════════════════════════════════════════════════════════════════════
#  REUSABLE WIDGET BUILDERS
# ══════════════════════════════════════════════════════════════════════════════
func _make_card() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(980, 660)   # ← larger card
	var s := StyleBoxFlat.new()
	s.bg_color     = C_BG
	s.border_color = C_GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	s.shadow_size  = 20
	pc.add_theme_stylebox_override("panel", s)
	return pc


func _make_divider() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxLine.new()
	s.color     = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.30)
	s.thickness = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep


func _make_section_header(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var accent := ColorRect.new()
	accent.color = C_RED
	accent.custom_minimum_size = Vector2(5, 24)
	row.add_child(accent)
	_gap(row, 10)
	var lbl := Label.new()
	lbl.text = title
	_apply_font(lbl, 16, C_GOLD)   # ← 16 pt section headers
	row.add_child(lbl)
	return row


func _make_rtl_scroll(bbcode: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled        = true
	rtl.fit_content           = true
	rtl.scroll_active         = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font:
		rtl.add_theme_font_override("normal_font", _font)
		rtl.add_theme_font_override("bold_font",   _font)
	rtl.add_theme_font_size_override("normal_font_size", 15)   # ← 15 pt body
	rtl.add_theme_font_size_override("bold_font_size",   15)
	rtl.add_theme_color_override("default_color", C_TEXT)
	rtl.text = bbcode
	scroll.add_child(rtl)
	return scroll


func _make_btn(label_text: String, bg: Color, fg: Color, min_w: int) -> Button:
	var btn := Button.new()
	btn.text                = label_text
	btn.custom_minimum_size = Vector2(min_w, 50)   # ← taller buttons
	btn.focus_mode          = Control.FOCUS_NONE
	_apply_font(btn, 16, fg)   # ← 16 pt button text
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal",  _flat(bg,                  8, Color.TRANSPARENT, 0))
	btn.add_theme_stylebox_override("hover",   _flat(bg.lightened(0.18),  8, C_GOLD,            1))
	btn.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.22),   8, Color.TRANSPARENT, 0))
	return btn


func _make_pill(text: String, bg: Color, fg: Color, font_size: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _flat(bg, 5, Color.TRANSPARENT, 0))
	var margin := MarginContainer.new()
	for prop in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(prop, 12)
	for prop in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(prop, 5)
	pc.add_child(margin)
	var lbl := Label.new()
	lbl.text = text
	_apply_font(lbl, font_size, fg)
	margin.add_child(lbl)
	return pc


func _flat(bg: Color, radius: int, border_color: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border_color
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s


func _apply_font(node: Control, font_size: int, color: Color) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)


func _gap(parent: Node, w: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(w, 0)
	parent.add_child(sp)


# ══════════════════════════════════════════════════════════════════════════════
#  PANEL SWITCHER
# ══════════════════════════════════════════════════════════════════════════════
func _swap_to(target: Control) -> void:
	_active_panel.visible = false
	target.visible        = true
	_active_panel         = target


# ══════════════════════════════════════════════════════════════════════════════
#  BUTTON HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

## Dismisses this overlay — main menu is now fully interactive beneath
func _on_continue_pressed() -> void:
	queue_free()


## Toggle: click once to open Credits, click again to return to Intro
func _on_credits_pressed() -> void:
	if _active_panel == _credits_panel:
		_swap_to(_intro_panel)
	else:
		_swap_to(_credits_panel)


## Toggle: click once to open Disclaimer, click again to return to Intro
func _on_disclaimer_pressed() -> void:
	if _active_panel == _disclaimer_panel:
		_swap_to(_intro_panel)
	else:
		_swap_to(_disclaimer_panel)
