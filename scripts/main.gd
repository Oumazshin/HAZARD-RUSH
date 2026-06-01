extends Node2D

# ── Asset paths ───────────────────────────────────────────────────────────────
const EARTH_SPIKE_DIR := "res://assets/new/Earth_Spike/"
# Add your custom font path here if you have one, or leave null for default
const FONT := ""

@onready var countdown_label : Label        = $HUD/CountdownLabel
@onready var results_menu                   = get_node_or_null("ResultsMenu")
@onready var hud              : CanvasLayer = $HUD

var results_shown   : bool  = false
var time_left       : float = 60.0
var hit_flash       : ColorRect
var timer_display   : Label
var player_kei_bar  : ProgressBar
var ai_kei_bar      : ProgressBar

# ── Race progress bar ─────────────────────────────────────────────────────────
const TRACK_W : float = 620.0
const TRACK_H : float = 26.0
var track_panel    : Panel
var player_marker  : ColorRect
var ai_marker      : ColorRect
var _track_start_x  : float = 16.0
var _track_finish_x : float = 12613.0
var _track_bounds_ready : bool = false

# ── Low-KEI danger vignette ───────────────────────────────────────────────────
var low_kei_vignette      : ColorRect
const LOW_KEI_THRESHOLD   : float = 0.30

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if results_menu: results_menu.hide()
	
	if countdown_label:
		countdown_label.text       = ""
		countdown_label.modulate.a = 0.0
		
	GameState.set_phase(GameState.RacePhase.PRE_MATCH)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.collision_event.connect(_on_collision_event)
	
	_setup_hud()
	_setup_progress_bar()
	_setup_low_kei_vignette()
	_apply_difficulty_to_hurdles()
	_apply_hurdle_visuals()
	_start_countdown()

# ── 1. Programmatic UI Setup (Top HUD) ────────────────────────────────────────
func _setup_hud() -> void:
	var vp     := get_viewport().get_visible_rect().size
	var half_h := vp.y / 2.0
	var m      := 14.0

	# ── Hit flash overlay (Behind UI)
	hit_flash          = ColorRect.new()
	hit_flash.color    = Color(1.0, 0.0, 0.0, 0.0)
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hit_flash)

	# ── PLAYER panel — top left
	var p_vbox := _add_hud_panel(Vector2(m, m), Vector2(280.0, 84.0))
	var p_name := _make_label("PLAYER", 20, Color(0.35, 1.0, 0.50))
	p_vbox.add_child(p_name)
	player_kei_bar = _make_bar(Color(0.20, 0.85, 0.35))
	p_vbox.add_child(player_kei_bar)

	# ── Timer panel — top centre
	var t_vbox    := _add_hud_panel(Vector2(vp.x / 2.0 - 90.0, m), Vector2(180.0, 54.0))
	var time_icon := _make_label("⏱  TIME", 13, Color(0.85, 0.85, 0.85))
	time_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_vbox.add_child(time_icon)
	timer_display = _make_label("60.0", 26, Color.WHITE)
	timer_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_vbox.add_child(timer_display)

	# ── AI OPPONENT panel — bottom left
	var ai_vbox := _add_hud_panel(Vector2(m, half_h + m), Vector2(280.0, 84.0))
	var ai_name := _make_label("AI OPPONENT", 20, Color(1.0, 0.42, 0.42))
	ai_vbox.add_child(ai_name)
	ai_kei_bar = _make_bar(Color(1.0, 0.35, 0.35))
	ai_vbox.add_child(ai_kei_bar)

func _add_hud_panel(pos: Vector2, size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color("#0a0a1a") # Deep dark blue
	style.border_color = Color("#ffd900") # Golden yellow border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = pos
	panel.size     = size
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	return vbox

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if FONT != "" and ResourceLoader.exists(FONT):
		lbl.add_theme_font_override("font", load(FONT))
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl

func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value           = 1.0
	bar.value               = 0.5
	bar.show_percentage     = false
	bar.custom_minimum_size = Vector2(255, 16)
	
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1a1a29")
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	return bar

# ── 2. Programmatic UI Setup (Race Track) ─────────────────────────────────────
func _setup_progress_bar() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0
	var y  := 100.0

	# Track Label
	var cap := _make_label("RACE PROGRESS", 12, Color(0.85, 0.85, 0.85))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size     = Vector2(TRACK_W, 16)
	cap.position = Vector2(cx - TRACK_W / 2.0, y - 20.0)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cap)

	# Styled Background Track
	track_panel = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color     = Color("#141424") # Dark track color
	st.border_color = Color("#ffd900") # Yellow border to match
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	track_panel.add_theme_stylebox_override("panel", st)
	track_panel.position     = Vector2(cx - TRACK_W / 2.0, y)
	track_panel.size         = Vector2(TRACK_W, TRACK_H)
	track_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(track_panel)

	# Finish Line
	var fin := ColorRect.new()
	fin.color        = Color.WHITE
	fin.size         = Vector2(4, TRACK_H - 4) # Slightly smaller than height
	fin.position     = Vector2(TRACK_W - 6, 2)
	fin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_panel.add_child(fin)

	# Player Marker
	player_marker          = ColorRect.new()
	player_marker.color    = Color("#40e666") # Bright green
	player_marker.size     = Vector2(7, 10)
	player_marker.position = Vector2(4, 3)
	player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_panel.add_child(player_marker)

	# AI Marker
	ai_marker          = ColorRect.new()
	ai_marker.color    = Color("#ff5959") # Bright red
	ai_marker.size     = Vector2(7, 10)
	ai_marker.position = Vector2(4, TRACK_H - 13)
	ai_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_panel.add_child(ai_marker)

func _update_progress_bar() -> void:
	if not _track_bounds_ready:
		var goal = get_tree().root.get_node_or_null("Main/SplitScreenUI/TopPlayerView/Viewport1/GameWorld/PlayerLane/Goal")
		if goal: _track_finish_x = goal.global_position.x
		_track_bounds_ready = true

	var span   : float = maxf(1.0, _track_finish_x - _track_start_x)
	var usable : float = TRACK_W - 14.0 # Padding for markers
	
	var pp     : float = clampf((GameState.player_position - _track_start_x) / span, 0.0, 1.0)
	var ap     : float = clampf((GameState.ai_position     - _track_start_x) / span, 0.0, 1.0)
	
	player_marker.position.x = 4.0 + pp * usable
	ai_marker.position.x     = 4.0 + ap * usable

# ── Per-frame ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if player_kei_bar: player_kei_bar.value = GameState.player_kei
	if ai_kei_bar:     ai_kei_bar.value     = GameState.ai_kei

	if GameState.is_racing():
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_end_by_distance()
			
		GameState.match_timer       = time_left
		GameState.race_elapsed_time = 60.0 - time_left
		GameState.match_timer_updated.emit(time_left)
		
		if timer_display:
			timer_display.text = str(snapped(time_left, 0.1))
			timer_display.add_theme_color_override("font_color", Color("#ff5959") if time_left <= 10.0 else Color.WHITE)

	_update_progress_bar()
	_update_low_kei_vignette()

# ── Countdown ─────────────────────────────────────────────────────────────────
func _start_countdown() -> void:
	if not countdown_label:
		time_left = 60.0
		GameState.set_phase(GameState.RacePhase.RACING)
		return
		
	for num in ["3", "2", "1"]:
		countdown_label.text       = num
		AudioManager.play_sfx("beep")
		countdown_label.scale      = Vector2(2.5, 2.5)
		countdown_label.modulate.a = 1.0
		var tw_num := create_tween().set_parallel(true)
		tw_num.tween_property(countdown_label, "scale",      Vector2(1.0, 1.0), 0.85)
		tw_num.tween_property(countdown_label, "modulate:a", 0.0,               0.85)
		await get_tree().create_timer(1.0).timeout

	countdown_label.text       = "GO!"
	AudioManager.play_sfx("go")
	countdown_label.scale      = Vector2(1.0, 1.0)
	countdown_label.modulate.a = 1.0
	var tw_go := create_tween().set_parallel(true)
	tw_go.tween_property(countdown_label, "scale",      Vector2(2.8, 2.8), 0.7)
	tw_go.tween_property(countdown_label, "modulate:a", 0.0,               0.7)
	await get_tree().create_timer(0.75).timeout
	countdown_label.text = ""
	
	time_left = 60.0
	GameState.set_phase(GameState.RacePhase.RACING)

# ── Hit flash & Game End ──────────────────────────────────────────────────────
func _on_collision_event(racer: String, _obstacle_type: String) -> void:
	if racer != "player" or hit_flash == null:
		return
	hit_flash.color.a = 0.45
	var tw_flash := create_tween()
	tw_flash.tween_property(hit_flash, "color:a", 0.0, 0.55)

func _end_by_distance() -> void:
	if GameState.player_position > GameState.ai_position:
		GameState.winner   = "player"
		GameState.win_reason = "time_up"
	elif GameState.ai_position > GameState.player_position:
		GameState.winner   = "ai"
		GameState.win_reason = "time_up"
	else:
		GameState.winner   = "player" if GameState.player_kei >= GameState.ai_kei else "ai"
		GameState.win_reason = "time_up"
	GameState.set_phase(GameState.RacePhase.FINISHED)

func _on_phase_changed(new_phase) -> void:
	if new_phase == GameState.RacePhase.FINISHED:
		if not results_shown:
			results_shown = true
			get_tree().paused = true

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ── Low-KEI danger vignette ───────────────────────────────────────────────────
func _setup_low_kei_vignette() -> void:
	low_kei_vignette = ColorRect.new()
	low_kei_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	low_kei_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low_kei_vignette.color = Color.WHITE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.12, 1.0);
void fragment() {
vec2 d = UV - vec2(0.5);
float r = length(d) * 1.41421356;
float v = smoothstep(0.30, 0.92, r);
COLOR = vec4(tint.rgb, v * intensity);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("intensity", 0.0)
	low_kei_vignette.material = mat
	hud.add_child(low_kei_vignette)
	hud.move_child(low_kei_vignette, 0)

func _update_low_kei_vignette() -> void:
	if low_kei_vignette == null:
		return
	var mat := low_kei_vignette.material as ShaderMaterial
	if mat == null:
		return
	if GameState.is_racing() and GameState.player_kei < LOW_KEI_THRESHOLD:
		var pulse : float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
		var depth : float = 1.0 - (GameState.player_kei / LOW_KEI_THRESHOLD)
		var inten : float = lerpf(0.20, 0.75, pulse) * clampf(depth, 0.0, 1.0)
		mat.set_shader_parameter("intensity", inten)
	else:
		mat.set_shader_parameter("intensity", 0.0)

# ── Difficulty → hurdle density ───────────────────────────────────────────────
func _apply_difficulty_to_hurdles() -> void:
	await get_tree().process_frame
	var keep_ratio := 1.0
	match GameState.difficulty:
		GameState.Difficulty.EASY:   keep_ratio = 0.5
		GameState.Difficulty.MEDIUM: keep_ratio = 0.75
		GameState.Difficulty.HARD:   keep_ratio = 1.0
	if keep_ratio >= 0.999:
		return
	var player_h : Array = []
	var ai_h     : Array = []
	for h in get_tree().get_nodes_in_group("hurdles"):
		match _lane_of(h):
			"player": player_h.append(h)
			"ai":     ai_h.append(h)
	_thin_lane(player_h, keep_ratio)
	_thin_lane(ai_h,     keep_ratio)

func _lane_of(n: Node) -> String:
	var p : Node = n
	while p != null:
		var nm := String(p.name)
		if nm == "PlayerLane": return "player"
		if nm == "AILane":     return "ai"
		p = p.get_parent()
	return ""

func _thin_lane(hurdles: Array, keep_ratio: float) -> void:
	var n := hurdles.size()
	if n == 0:
		return
	hurdles.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var keep_count : int   = max(1, int(round(float(n) * keep_ratio)))
	var keep_every : float = float(n) / float(keep_count)
	var kept       := {}
	var idx        := 0.0
	while int(idx) < n and kept.size() < keep_count:
		kept[int(idx)] = true
		idx += keep_every
	for i in n:
		if kept.has(i):
			continue
		var h : Node = hurdles[i]
		h.hide()
		h.remove_from_group("hurdles")
		if h is CollisionObject2D:
			h.set_deferred("monitoring",   false)
			h.set_deferred("monitorable",  false)

# ── Earth_Spike animation ─────────────────────────────────────────────────────
func _apply_hurdle_visuals() -> void:
	await get_tree().process_frame
	if not ResourceLoader.exists(EARTH_SPIKE_DIR + "001.png"):
		return
	var sf := SpriteFrames.new()
	sf.add_animation("rise")
	for i in range(1, 10):
		var tex : Texture2D = load(EARTH_SPIKE_DIR + "%03d.png" % i)
		sf.add_frame("rise", tex)
	for i in range(8, 0, -1):
		var tex : Texture2D = load(EARTH_SPIKE_DIR + "%03d.png" % i)
		sf.add_frame("rise", tex)
	sf.set_animation_loop("rise", true)
	sf.set_animation_speed("rise", 7.0)

	for h in get_tree().get_nodes_in_group("hurdles"):
		if not String(h.name).begins_with("Spike"):
			continue
		var old_sprite := h.get_node_or_null("Sprite2D")
		if old_sprite:
			old_sprite.hide()
		var anim              := AnimatedSprite2D.new()
		anim.sprite_frames     = sf
		anim.texture_filter    = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.scale             = Vector2(0.25, 0.25)
		anim.position          = Vector2(0.0, -8.0)
		h.add_child(anim)
		anim.play("rise")
