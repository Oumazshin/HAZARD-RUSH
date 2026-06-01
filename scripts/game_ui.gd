# game_ui.gd
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

# ── Asset paths ───────────────────────────────────────────────────────────────
const FONT_PATH          : String = "res://assets/Global/text/fonts/BoldPixels.ttf"
const POWERUP_ASSET_BASE : String = "res://assets/environment/Fruits for PowerUps/"

# ── Sprite-sheet config ───────────────────────────────────────────────────────
const POWERUP_HFRAMES  : int   = 17
const POWERUP_ANIM_FPS : float = 12.0

# ── Power-up tables ───────────────────────────────────────────────────────────
const EFFECT_NAMES : Array = [
	"SPEED BOOST",   # 0 – Apple
	"BANANA PEEL",   # 1 – Bananas
	"SHIELD",        # 2 – Cherries
	"GHOST MODE",    # 3 – Kiwi
	"SCORE RUSH",    # 4 – Melon
	"SAB. CHARGE",   # 5 – Orange
	"HIGH JUMP",     # 6 – Pineapple
	"FREEZE OPP.",   # 7 – Strawberry
]
const EFFECT_COLORS : Array = [
	Color(0.35, 1.00, 0.35, 1.0),  # Apple     – green
	Color(1.00, 0.95, 0.20, 1.0),  # Bananas   – yellow
	Color(0.30, 0.85, 1.00, 1.0),  # Cherries  – cyan
	Color(0.90, 0.90, 0.90, 1.0),  # Kiwi      – silver
	Color(1.00, 0.85, 0.20, 1.0),  # Melon     – gold
	Color(1.00, 0.55, 0.15, 1.0),  # Orange    – orange
	Color(1.00, 0.50, 0.90, 1.0),  # Pineapple – pink
	Color(0.50, 0.90, 1.00, 1.0),  # Strawberry– sky
]
const EFFECT_SHEETS : Array = [
	POWERUP_ASSET_BASE + "Apple.png",
	POWERUP_ASSET_BASE + "Bananas.png",
	POWERUP_ASSET_BASE + "Cherries.png",
	POWERUP_ASSET_BASE + "Kiwi.png",
	POWERUP_ASSET_BASE + "Melon.png",
	POWERUP_ASSET_BASE + "Orange.png",
	POWERUP_ASSET_BASE + "Pineapple.png",
	POWERUP_ASSET_BASE + "Strawberry.png",
]

# ── Visual constants ──────────────────────────────────────────────────────────
const MAX_SPEED          : float = 600.0
const LABEL_FONT_SIZE    : int   = 18
const TIMER_FONT_SIZE    : int   = 24
const DIVIDER_THICKNESS  : int   = 4
const DIVIDER_COLOR      : Color = Color(0.05, 0.05, 0.05, 0.95)
const PANEL_BG_COLOR     : Color = Color(0.05, 0.05, 0.07, 0.85)
const TIMER_BG_COLOR     : Color = Color(0.00, 0.00, 0.00, 0.75)
const P1_BAR_COLOR       : Color = Color(0.30, 0.85, 1.00, 1.0)
const AI_BAR_COLOR       : Color = Color(1.00, 0.55, 0.15, 1.0)
const TIMER_URGENT_COLOR : Color = Color(1.00, 0.25, 0.15, 1.0)

# ── Countdown color table ─────────────────────────────────────────────────────
const CDOWN_COLORS : Array = [
	Color.WHITE,                       # 0 – unused
	Color(1.00, 0.30, 0.30, 1.0),      # 1 – red
	Color(1.00, 0.88, 0.20, 1.0),      # 2 – gold
	Color(0.40, 0.85, 1.00, 1.0),      # 3 – cyan
]

# ── Runtime ───────────────────────────────────────────────────────────────────
var _font : FontFile = null

# Countdown nodes
var _cdown_root    : Control   = null
var _cdown_overlay : ColorRect = null
var _cdown_sub     : Label     = null
var _cdown_num     : Label     = null

# HUD labels / bars
var _timer_label    : Label       = null
var _p_speed_bar    : ProgressBar = null
var _a_speed_bar    : ProgressBar = null
var _p_speed_label  : Label       = null
var _a_speed_label  : Label       = null
var _p_progress     : ProgressBar = null
var _a_progress     : ProgressBar = null
var _p_sabotage_lbl : Label       = null
var _a_sabotage_lbl : Label       = null

# Power-up display per side
var _p_powerup_panel     : PanelContainer = null
var _p_powerup_style     : StyleBoxFlat   = null
var _p_powerup_icon      : TextureRect    = null
var _p_powerup_name_lbl  : Label          = null
var _p_powerup_timer_lbl : Label          = null
var _p_powerup_atlas     : AtlasTexture   = null
var _p_powerup_type      : int            = -1
var _p_powerup_timer     : float          = 0.0
var _p_anim_frame        : int            = 0
var _p_anim_timer        : float          = 0.0

var _a_powerup_panel     : PanelContainer = null
var _a_powerup_style     : StyleBoxFlat   = null
var _a_powerup_icon      : TextureRect    = null
var _a_powerup_name_lbl  : Label          = null
var _a_powerup_timer_lbl : Label          = null
var _a_powerup_atlas     : AtlasTexture   = null
var _a_powerup_type      : int            = -1
var _a_powerup_timer     : float          = 0.0
var _a_anim_frame        : int            = 0
var _a_anim_timer        : float          = 0.0

# Cached node refs
var _player_node   : Node = null
var _ai_sys_node   : Node = null
var _ai_racer_node : Node = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	add_to_group("game_ui")
	_load_font()
	
	for child in get_children():
		if child is Label:
			child.queue_free()
			
	_build_ui()
	GameState.match_timer_updated.connect(_on_match_timer_updated)
	call_deferred("_cache_nodes")

func _cache_nodes() -> void:
	_player_node   = get_tree().get_first_node_in_group("player_character")
	_ai_sys_node   = get_tree().get_first_node_in_group("sabotage_system_ai")
	_ai_racer_node = get_tree().get_first_node_in_group("opponent_ai")

func _process(delta: float) -> void:
	_update_speed_bars()
	_update_race_progress()
	_update_sabotage_status()
	_tick_powerup(true,  delta)
	_tick_powerup(false, delta)

func reset() -> void:
	if _timer_label:
		_timer_label.text     = "01:00.00"
		_timer_label.modulate = Color.WHITE
	_clear_powerup(true)
	_clear_powerup(false)

func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := Control.new()
	root.name         = "UIRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_divider(root)
	_build_timer(root)
	_build_race_progress(root)
	_build_unified_hud(root, true)
	_build_unified_hud(root, false)
	_build_countdown(root)

func _build_divider(parent: Control) -> void:
	var div          := ColorRect.new()
	div.color        =  DIVIDER_COLOR
	div.mouse_filter =  Control.MOUSE_FILTER_IGNORE
	div.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	div.anchor_right  =  1.0
	div.offset_top    = -float(DIVIDER_THICKNESS) / 2.0
	div.offset_bottom =  float(DIVIDER_THICKNESS) / 2.0
	parent.add_child(div)

func _build_timer(parent: Control) -> void:
	var bg := PanelContainer.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg.offset_left   = -80.0
	bg.offset_right  =  80.0
	bg.offset_top    =  15.0
	bg.offset_bottom =  59.0

	var ps                        := StyleBoxFlat.new()
	ps.bg_color                   =  TIMER_BG_COLOR
	ps.set_corner_radius_all(8)
	ps.border_width_bottom        = 2
	ps.border_color               = Color(0.2, 0.2, 0.2, 1.0)
	bg.add_theme_stylebox_override("panel", ps)
	parent.add_child(bg)

	_timer_label                      = Label.new()
	_timer_label.text                 = "01:00.00"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_apply_font(_timer_label, TIMER_FONT_SIZE)
	_apply_shadow(_timer_label)
	bg.add_child(_timer_label)

func _build_unified_hud(parent: Control, is_player: bool) -> void:
	var wrapper := HBoxContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_constant_override("separation", 10)
	
	if is_player:
		wrapper.set_anchors_preset(Control.PRESET_TOP_LEFT)
		wrapper.offset_top    = 15.0
		wrapper.grow_vertical = Control.GROW_DIRECTION_END
	else:
		wrapper.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		wrapper.offset_bottom = -15.0
		wrapper.grow_vertical = Control.GROW_DIRECTION_BEGIN
		
	wrapper.offset_left = 20.0
	parent.add_child(wrapper)

	var bar_color : Color = P1_BAR_COLOR if is_player else AI_BAR_COLOR

	# ── A. KEI bar panel ──
	var kei_bg := PanelContainer.new()
	kei_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	kei_bg.custom_minimum_size = Vector2(350, 0)
	kei_bg.size_flags_vertical = Control.SIZE_FILL
	var kei_sty                := StyleBoxFlat.new()
	kei_sty.bg_color           =  PANEL_BG_COLOR
	kei_sty.set_corner_radius_all(6)
	kei_sty.border_width_left  = 4
	kei_sty.border_color       = bar_color
	kei_sty.content_margin_left = 16; kei_sty.content_margin_right = 16
	kei_sty.content_margin_top  = 12; kei_sty.content_margin_bottom = 12
	kei_bg.add_theme_stylebox_override("panel", kei_sty)
	wrapper.add_child(kei_bg)

	var kei_vbox := VBoxContainer.new()
	kei_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	kei_vbox.add_theme_constant_override("separation", 6)
	kei_bg.add_child(kei_vbox)

	var hdr := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "PLAYER KEI" if is_player else "AI KEI"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(name_lbl, LABEL_FONT_SIZE); _apply_shadow(name_lbl)
	
	var spd_lbl := Label.new()
	spd_lbl.text = "0"
	spd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(spd_lbl, LABEL_FONT_SIZE); _apply_shadow(spd_lbl)
	
	hdr.add_child(name_lbl); hdr.add_child(spd_lbl)
	kei_vbox.add_child(hdr)

	var bar := ProgressBar.new()
	bar.min_value = 0.0; bar.max_value = 1.0; bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_sty := StyleBoxFlat.new()
	fill_sty.bg_color = bar_color
	fill_sty.set_corner_radius_all(4)
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color = Color(0.08, 0.08, 0.08, 0.8)
	bg_sty.set_border_width_all(1)
	bg_sty.border_color = Color(0.2, 0.2, 0.2, 1.0)
	bar.add_theme_stylebox_override("fill", fill_sty)
	bar.add_theme_stylebox_override("background", bg_sty)
	kei_vbox.add_child(bar)

	# ── B. Sabotage panel ──
	var sab_bg := PanelContainer.new()
	sab_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	sab_bg.custom_minimum_size = Vector2(180, 0)
	sab_bg.size_flags_vertical = Control.SIZE_FILL
	var sab_sty                := StyleBoxFlat.new()
	sab_sty.bg_color           =  PANEL_BG_COLOR
	sab_sty.set_corner_radius_all(6)
	sab_sty.content_margin_left = 12; sab_sty.content_margin_right = 12
	sab_sty.content_margin_top  = 10; sab_sty.content_margin_bottom = 10
	sab_bg.add_theme_stylebox_override("panel", sab_sty)
	wrapper.add_child(sab_bg)

	var sab_vbox := VBoxContainer.new()
	sab_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sab_vbox.add_theme_constant_override("separation", 2)
	sab_bg.add_child(sab_vbox)

	var sab_ttl := Label.new()
	sab_ttl.text = "SABOTAGE [F]" if is_player else "SABOTAGE"
	sab_ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sab_ttl.modulate = Color(0.6, 0.6, 0.6)
	_apply_font(sab_ttl, 14); _apply_shadow(sab_ttl)
	sab_vbox.add_child(sab_ttl)

	var sab_val := Label.new()
	sab_val.text = "--"
	sab_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(sab_val, 18); _apply_shadow(sab_val)
	sab_vbox.add_child(sab_val)

	# ── C. Power-up panel ──
	var pup_bg := PanelContainer.new()
	pup_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	pup_bg.custom_minimum_size = Vector2(210, 0)
	pup_bg.size_flags_vertical = Control.SIZE_FILL
	var pup_sty                := StyleBoxFlat.new()
	pup_sty.bg_color           =  PANEL_BG_COLOR
	pup_sty.set_corner_radius_all(6)
	pup_sty.border_width_left  = 0
	pup_sty.content_margin_left = 10; pup_sty.content_margin_right = 10
	pup_sty.content_margin_top  = 6;  pup_sty.content_margin_bottom = 6
	pup_bg.add_theme_stylebox_override("panel", pup_sty)
	wrapper.add_child(pup_bg)

	var pup_vbox := VBoxContainer.new()
	pup_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pup_vbox.add_theme_constant_override("separation", 3)
	pup_bg.add_child(pup_vbox)

	var pup_ttl := Label.new()
	pup_ttl.text = "POWER-UP"
	pup_ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pup_ttl.modulate = Color(0.6, 0.6, 0.6)
	_apply_font(pup_ttl, 13); _apply_shadow(pup_ttl)
	pup_vbox.add_child(pup_ttl)

	var pup_icon := TextureRect.new()
	pup_icon.custom_minimum_size   = Vector2(64, 64)
	pup_icon.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# NEW FIX: Prevents Layout engine from crushing the fruit invisible!
	pup_icon.expand_mode           = TextureRect.EXPAND_IGNORE_SIZE 
	pup_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pup_icon.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	pup_vbox.add_child(pup_icon)

	var pup_name := Label.new()
	pup_name.text = "--"
	pup_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pup_name.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_apply_font(pup_name, 15); _apply_shadow(pup_name)
	pup_vbox.add_child(pup_name)

	var pup_tmr := Label.new()
	pup_tmr.text = ""
	pup_tmr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pup_tmr.modulate = Color(0.78, 0.78, 0.78)
	_apply_font(pup_tmr, 12); _apply_shadow(pup_tmr)
	pup_vbox.add_child(pup_tmr)

	# Store refs appropriately
	if is_player:
		_p_speed_bar = bar;          _p_speed_label = spd_lbl
		_p_sabotage_lbl              = sab_val
		_p_powerup_panel = pup_bg;   _p_powerup_style = pup_sty
		_p_powerup_icon              = pup_icon
		_p_powerup_name_lbl          = pup_name; _p_powerup_timer_lbl = pup_tmr
	else:
		_a_speed_bar = bar;          _a_speed_label = spd_lbl
		_a_sabotage_lbl              = sab_val
		_a_powerup_panel = pup_bg;   _a_powerup_style = pup_sty
		_a_powerup_icon              = pup_icon
		_a_powerup_name_lbl          = pup_name; _a_powerup_timer_lbl = pup_tmr

func _build_race_progress(parent: Control) -> void:
	var bg := PanelContainer.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	bg.offset_left = 20.0; bg.offset_right = 90.0
	bg.offset_top = -230.0; bg.offset_bottom = 230.0
	
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	ps.set_corner_radius_all(8)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.15, 0.15, 0.15, 1.0)
	bg.add_theme_stylebox_override("panel", ps)
	parent.add_child(bg)

	var mv := VBoxContainer.new()
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(mv)

	var hd := Label.new()
	hd.text = "TRACK"; hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(hd, 12); _apply_shadow(hd); mv.add_child(hd)

	var bh := HBoxContainer.new()
	bh.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	bh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bh.alignment           = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 10)
	mv.add_child(bh)

	_p_progress = _create_progress_bar(P1_BAR_COLOR)
	_a_progress = _create_progress_bar(AI_BAR_COLOR)
	bh.add_child(_p_progress)
	bh.add_child(_a_progress)

func _create_progress_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0; bar.max_value = 1.0
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(18, 0)
	
	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = fill_color
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.06, 0.06, 0.06, 0.85)
	
	bar.add_theme_stylebox_override("fill", style_fill)
	bar.add_theme_stylebox_override("background", style_bg)
	return bar

# ── FULLY CENTERED COUNTDOWN UI ─────────────────────────────────────────────

func _build_countdown(parent: Control) -> void:
	_cdown_root              = Control.new()
	_cdown_root.name         = "CountdownRoot"
	_cdown_root.z_index      = 50
	_cdown_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cdown_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cdown_root.visible      = false
	parent.add_child(_cdown_root)

	_cdown_overlay              = ColorRect.new()
	_cdown_overlay.color        = Color(0.0, 0.0, 0.0, 0.0)
	_cdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cdown_root.add_child(_cdown_overlay)

	# Standalone GET READY Label
	_cdown_sub = Label.new()
	_cdown_sub.text = "GET READY"
	_cdown_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cdown_sub.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_cdown_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cdown_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cdown_sub.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_cdown_sub.position.y -= 140 
	_cdown_sub.modulate = Color(0.85, 0.85, 0.85, 0.0)
	_apply_font(_cdown_sub, 56); _apply_shadow(_cdown_sub)
	_cdown_root.add_child(_cdown_sub)

	# Standalone Number Label 
	_cdown_num = Label.new()
	_cdown_num.text = ""
	_cdown_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cdown_num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_cdown_num.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cdown_num.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cdown_num.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_cdown_num.modulate.a = 0.0
	_apply_font(_cdown_num, 160); _apply_shadow(_cdown_num)
	_cdown_root.add_child(_cdown_num)

# ── FAST & ELASTIC COUNTDOWN ANIMATION ─────────────────────────────────────

func run_countdown() -> void:
	_cdown_root.visible = true
	_cdown_overlay.color = Color(0.0, 0.0, 0.0, 0.65) 
	
	_cdown_sub.text = "GET READY"
	_cdown_sub.modulate.a = 0.0
	_cdown_sub.scale = Vector2(0.5, 0.5)
	
	_cdown_num.text = ""
	_cdown_num.modulate.a = 0.0
	
	# Center pivot dynamically for scaling
	_cdown_sub.reset_size()
	_cdown_sub.pivot_offset = _cdown_sub.get_minimum_size() / 2.0
	
	# 1. Animate "GET READY" in (Bouncy Elastic Effect)
	var tw_ready := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_ready.tween_property(_cdown_sub, "modulate:a", 1.0, 0.4)
	tw_ready.tween_property(_cdown_sub, "scale", Vector2(1.0, 1.0), 0.4)
	
	await get_tree().create_timer(1.2).timeout
	
	# Fade out "GET READY"
	create_tween().tween_property(_cdown_sub, "modulate:a", 0.0, 0.2)
	await get_tree().create_timer(0.2).timeout
	
	# 2. Number Sequence (3, 2, 1)
	for i in range(3, 0, -1):
		_cdown_num.text = str(i)
		_cdown_num.modulate = CDOWN_COLORS[i]
		_cdown_num.modulate.a = 1.0
		
		_cdown_num.reset_size()
		_cdown_num.pivot_offset = _cdown_num.get_minimum_size() / 2.0
		_cdown_num.scale = Vector2(0.3, 0.3)
		
		if AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("beep")
			
		# Elastic pop-in effect
		var tw_in := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(_cdown_num, "scale", Vector2(1.2, 1.2), 0.5)
		
		await get_tree().create_timer(0.6).timeout
		
		# Smoothly sweep out and fade
		var tw_out := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_out.tween_property(_cdown_num, "modulate:a", 0.0, 0.25)
		tw_out.tween_property(_cdown_num, "scale", Vector2(2.5, 2.5), 0.25)
		
		await get_tree().create_timer(0.25).timeout

	# 3. "GO!" Sequence
	_cdown_num.text = "GO!"
	_cdown_num.modulate = Color(0.30, 1.00, 0.45, 1.0)
	_cdown_num.modulate.a = 1.0
	
	_cdown_num.reset_size()
	_cdown_num.pivot_offset = _cdown_num.get_minimum_size() / 2.0
	_cdown_num.scale = Vector2(0.2, 0.2)
	
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("go")
		
	# Huge Elastic pop-in for "GO!"
	var tw_go := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_go.tween_property(_cdown_num, "scale", Vector2(1.8, 1.8), 0.8)
	
	# Gradually fade the dark overlay while "GO" is on screen
	create_tween().tween_property(_cdown_overlay, "color:a", 0.0, 0.5)
	
	await get_tree().create_timer(0.8).timeout
	
	# Final cinematic fade out for "GO!"
	var tw_go_out := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_go_out.tween_property(_cdown_num, "modulate:a", 0.0, 0.3)
	tw_go_out.tween_property(_cdown_num, "scale", Vector2(3.5, 3.5), 0.3)
	
	await get_tree().create_timer(0.3).timeout
	_cdown_root.visible = false

# ── Helper functions ──────────────────────────────────────────────────────────

func _apply_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)

func _apply_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x",     2)
	label.add_theme_constant_override("shadow_offset_y",     2)
	label.add_theme_constant_override("shadow_outline_size", 3)

# ── Per-frame updates ─────────────────────────────────────────────────────────

func _on_match_timer_updated(time_left: float) -> void:
	if _timer_label == null: return
	var t  : float = maxf(time_left, 0.0)
	var m  : int   = int(t / 60.0)
	var s  : int   = int(t) % 60
	var cs : int   = int(fmod(t, 1.0) * 100)
	_timer_label.text     = "%02d:%02d.%02d" % [m, s, cs]
	_timer_label.modulate = TIMER_URGENT_COLOR if t <= 10.0 else Color.WHITE

func _update_speed_bars() -> void:
	var pv : float = clampf(GameState.player_kei, 0.0, 1.0)
	var av : float = clampf(GameState.ai_kei,     0.0, 1.0)
	if _p_speed_bar:   _p_speed_bar.value  = pv
	if _a_speed_bar:   _a_speed_bar.value  = av
	if _p_speed_label: _p_speed_label.text = "%d" % int(pv * MAX_SPEED)
	if _a_speed_label: _a_speed_label.text = "%d" % int(av * MAX_SPEED)

func _update_race_progress() -> void:
	if _p_progress == null or _a_progress == null: return
	var finish : float = GameState.finish_line_x
	if finish <= 0.0: return
	_p_progress.value = clampf(GameState.player_position / finish, 0.0, 1.0)
	_a_progress.value = clampf(GameState.ai_position     / finish, 0.0, 1.0)

func _update_sabotage_status() -> void:
	_update_sabotage_label(_p_sabotage_lbl, _player_node, _ai_sys_node)
	_update_sabotage_label(_a_sabotage_lbl, _ai_racer_node, null, _ai_sys_node)

func _update_sabotage_label(lbl: Label, logic_node: Node, primary_sys: Node = null, fallback_sys: Node = null) -> void:
	if lbl == null: return
	
	var is_locked: bool = false
	var lock_time: float = 0.0
	var charges = logic_node.get("_sabotage_charges") if logic_node else null
	
	var cooldown = null
	if logic_node and logic_node.get("_sabotage_cooldown") != null:
		cooldown = logic_node.get("_sabotage_cooldown")
	elif fallback_sys and fallback_sys.get("sabotage_cooldown") != null:
		cooldown = fallback_sys.get("sabotage_cooldown")

	if primary_sys and primary_sys.has_method("is_locked_out") and primary_sys.is_locked_out():
		is_locked = true
		lock_time = primary_sys.get_lockout_remaining()

	if is_locked:
		lbl.text = "LOCKED (%.1fs)" % lock_time
		lbl.add_theme_color_override("font_color", Color(0.85, 0.30, 0.30))
	elif charges != null and charges > 0:
		lbl.text = "%d CHARGES" % charges
		lbl.add_theme_color_override("font_color", Color(0.25, 0.85, 1.0))
	elif cooldown != null and cooldown <= 0.0:
		lbl.text = "READY"
		lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.45))
	elif cooldown != null:
		lbl.text = "%.1fs" % cooldown if logic_node == _player_node else "WAITING"
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

func show_powerup(is_player: bool, effect_type: int, duration: float) -> void:
	if effect_type < 0 or effect_type >= EFFECT_NAMES.size():
		return
	var dur : float = maxf(duration, 1.5)
	
	if is_player:
		_p_powerup_type  = effect_type
		_p_powerup_timer = dur
	else:
		_a_powerup_type  = effect_type
		_a_powerup_timer = dur
		
	_load_powerup_icon(is_player, effect_type)
	var panel : PanelContainer = _p_powerup_panel if is_player else _a_powerup_panel
	if panel:
		var tw := create_tween()
		tw.tween_property(panel, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.07)
		tw.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)

func _load_powerup_icon(is_player: bool, effect_type: int) -> void:
	var icon   : TextureRect  = _p_powerup_icon     if is_player else _a_powerup_icon
	var name_l : Label        = _p_powerup_name_lbl if is_player else _a_powerup_name_lbl
	var sty    : StyleBoxFlat = _p_powerup_style    if is_player else _a_powerup_style

	if effect_type < 0 or effect_type >= EFFECT_SHEETS.size(): return
	var path : String = EFFECT_SHEETS[effect_type]
	if not ResourceLoader.exists(path): return

	var sheet := load(path) as Texture2D
	if sheet == null: return

	var fw : int = int(float(sheet.get_width()) / float(POWERUP_HFRAMES))
	var fh : int = sheet.get_height()

	var atlas          := AtlasTexture.new()
	atlas.atlas        = sheet
	atlas.filter_clip  = true
	atlas.region       = Rect2(0, 0, fw, fh)

	icon.texture  = atlas
	name_l.text   = EFFECT_NAMES[effect_type]
	name_l.add_theme_color_override("font_color", EFFECT_COLORS[effect_type])
	if sty:
		sty.border_width_left = 4
		sty.border_color      = EFFECT_COLORS[effect_type]

	if is_player:
		_p_powerup_atlas = atlas; _p_anim_frame = 0; _p_anim_timer = 0.0
	else:
		_a_powerup_atlas = atlas; _a_anim_frame = 0; _a_anim_timer = 0.0

func _tick_powerup(is_player: bool, delta: float) -> void:
	var ptype   : int          = _p_powerup_type  if is_player else _a_powerup_type
	if ptype == -1: return

	var ptimer  : float        = _p_powerup_timer if is_player else _a_powerup_timer
	var atlas   : AtlasTexture = _p_powerup_atlas if is_player else _a_powerup_atlas
	var tmr_lbl : Label        = _p_powerup_timer_lbl if is_player else _a_powerup_timer_lbl

	var new_timer := maxf(ptimer - delta, 0.0)
	
	if is_player: _p_powerup_timer = new_timer
	else:         _a_powerup_timer = new_timer

	if new_timer <= 0.0:
		_clear_powerup(is_player)
		return

	if tmr_lbl:
		tmr_lbl.text = "%.1fs" % new_timer

	if atlas == null: return
	
	var frame_dur : float = 1.0 / POWERUP_ANIM_FPS
	var current_anim_timer: float = _p_anim_timer if is_player else _a_anim_timer
	var current_anim_frame: int   = _p_anim_frame if is_player else _a_anim_frame
	
	current_anim_timer += delta
	if current_anim_timer >= frame_dur:
		current_anim_timer -= frame_dur
		current_anim_frame = (current_anim_frame + 1) % POWERUP_HFRAMES
		var sheet := atlas.atlas
		if sheet:
			var fw : int = int(float(sheet.get_width()) / float(POWERUP_HFRAMES))
			atlas.region = Rect2(current_anim_frame * fw, 0, fw, sheet.get_height())
			
	if is_player:
		_p_anim_timer = current_anim_timer
		_p_anim_frame = current_anim_frame
	else:
		_a_anim_timer = current_anim_timer
		_a_anim_frame = current_anim_frame

func _clear_powerup(is_player: bool) -> void:
	var icon   : TextureRect  = _p_powerup_icon     if is_player else _a_powerup_icon
	var name_l : Label        = _p_powerup_name_lbl if is_player else _a_powerup_name_lbl
	var tmr_l  : Label        = _p_powerup_timer_lbl if is_player else _a_powerup_timer_lbl
	var sty    : StyleBoxFlat = _p_powerup_style     if is_player else _a_powerup_style
	
	if icon:   icon.texture = null
	if name_l: name_l.text  = "--"; name_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if tmr_l:  tmr_l.text   = ""
	if sty:    sty.border_width_left = 0
	
	if is_player:
		_p_powerup_type  = -1; _p_powerup_timer = 0.0
		_p_powerup_atlas = null; _p_anim_frame = 0; _p_anim_timer = 0.0
	else:
		_a_powerup_type  = -1; _a_powerup_timer = 0.0
		_a_powerup_atlas = null; _a_anim_frame = 0; _a_anim_timer = 0.0
