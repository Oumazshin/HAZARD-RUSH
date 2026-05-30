extends CharacterBody2D

# --- Constants ---
const MAX_SPEED: float = 600.0
const SPEED_INCREMENT: float = 100.0
const SPEED_DECAY: float = 60.0
const PENALTY_DROP: float = 150.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

# --- Sabotage (offence) ---
# Press the "sabotage" Input Map action (default: F) to launch a hazard at the AI.
const SABOTAGE_COOLDOWN: float = 6.0

# --- Early Warning System (EWS) — warns ~1.5–2.0s before an obstacle ---
const EWS_LEAD_TIME: float = 2.0
const EWS_MIN_ALPHA: float = 0.30
const EWS_MAX_ALPHA: float = 0.92

# --- State Variables ---
var current_speed: float = 0.0
var last_key_pressed: String = ""
var is_sliding: bool = false
var is_stumbling: bool = false
var time_elapsed: float = 0.0
var _was_sliding: bool = false
var _sabotage_cooldown: float = 0.0   # counts down to 0 when ready

# --- Asset paths ---
const EWS_ALERT_TEX  := "res://assets/new/symbol_alert/spritesheet.png"
const IMPACT_TEX     := "res://assets/new/impact_small/spritesheet.png"
const FONT_PATH      := "res://assets/new/BoldPixels.ttf"

# --- UI & Animation References ---
@onready var anim: AnimationPlayer = $AnimationPlayer
@export var speed_bar: ProgressBar
@export var warning_ui: Control
@export var timer_label: Label

var _warning_label: Label = null
var _ews_sprite: AnimatedSprite2D = null
var _impact_frames: SpriteFrames = null
var _sabotage_label: Label = null   # "SABOTAGE [F]" cooldown indicator

func _ready() -> void:
	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value = 0
	if warning_ui:
		_setup_warning_ui()
	_setup_impact_frames()
	_setup_sabotage_label()

func _physics_process(delta: float) -> void:
	# Sabotage cooldown ticks even before the race fully starts.
	if _sabotage_cooldown > 0.0:
		_sabotage_cooldown = max(0.0, _sabotage_cooldown - delta)
	_update_sabotage_label()

	# Block movement until race starts
	if not GameState.is_racing():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 1. Decay Momentum
	if current_speed > 0 and not is_stumbling:
		current_speed -= SPEED_DECAY * delta
		current_speed = max(0, current_speed)

	# 2. Input Priority & MICRO-BOUNCE PROTECTION
	if Input.is_action_pressed("ui_down") and not is_stumbling:
		if is_on_floor() or is_sliding:
			is_sliding = true
		else:
			is_sliding = false
	else:
		is_sliding = false

	# Slide SFX — only on the frame the slide begins
	if is_sliding and not _was_sliding:
		AudioManager.play_sfx("slide")
	_was_sliding = is_sliding

	# 3. Enhanced Gravity & Jump Logic
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and not is_stumbling and not is_sliding:
			velocity.y = JUMP_VELOCITY
			AudioManager.play_sfx("jump")
		else:
			velocity.y = 30.0

	# 4. Apply Forward Velocity based on state
	if is_sliding:
		velocity.x = current_speed * 0.8
	else:
		velocity.x = current_speed

	# 5. Movement Execution
	move_and_slide()

	# 6. Animation Management
	handle_animations()

	# 7. UI Updates
	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value = current_speed
	GameState.player_kei = current_speed / MAX_SPEED
	GameState.player_position = global_position.x

	# Early Warning System
	_update_ews()

	if GameState.is_racing():
		time_elapsed += delta
		var time_remaining = max(0.0, 60.0 - time_elapsed)
		if timer_label:
			if time_remaining <= 10.0:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				timer_label.add_theme_color_override("font_color", Color.WHITE)
			timer_label.text = "TIME: " + str(snapped(time_remaining, 0.1))

# --- Animation Logic ---

func handle_animations():
	if is_stumbling:
		play_anim("stumble")
		return
	if is_sliding:
		play_anim("slide")
		return
	if not is_on_floor():
		play_anim("jump")
		return
	if current_speed > 10:
		anim.speed_scale = current_speed / 400.0
		play_anim("run")
	else:
		anim.speed_scale = 1.0
		play_anim("idle")

func play_anim(anim_name: String):
	if anim.current_animation == anim_name:
		return
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		anim.play("RESET")

# --- Input Mechanics ---

func _unhandled_input(event: InputEvent) -> void:
	# Sabotage — uses the "sabotage" Input Map action (Project Settings → Input Map).
	# Works even while stumbling because it's an attack on the opponent, not movement.
	if event.is_action_pressed("sabotage"):
		_try_sabotage()
		return

	if is_stumbling: return

	# Rhythm Tapping (A/D)
	if event is InputEventKey and event.pressed and not event.echo:
		var key_pressed: String = ""
		if event.keycode == KEY_A: key_pressed = "A"
		elif event.keycode == KEY_D: key_pressed = "D"

		if key_pressed != "":
			if key_pressed != last_key_pressed:
				current_speed = min(current_speed + SPEED_INCREMENT, MAX_SPEED)
				last_key_pressed = key_pressed
			else:
				current_speed = max(0, current_speed - PENALTY_DROP)

# --- Sabotage (offence) ---

func _try_sabotage() -> void:
	if not GameState.is_racing():
		return
	if _sabotage_cooldown > 0.0:
		return
	var ai_sys = get_tree().get_first_node_in_group("sabotage_system_ai")
	if ai_sys and ai_sys.has_method("trigger"):
		ai_sys.trigger("player")
		_sabotage_cooldown = SABOTAGE_COOLDOWN
		print("[Player] Sabotage launched at the AI!")
	else:
		push_warning("[Player] sabotage_system_ai group not found.")

func _setup_sabotage_label() -> void:
	if warning_ui == null:
		return
	var cl := warning_ui.get_parent()
	if cl == null:
		return
	_sabotage_label = Label.new()
	_sabotage_label.name = "SabotageStatus"
	_sabotage_label.anchor_left   = 1.0
	_sabotage_label.anchor_right  = 1.0
	_sabotage_label.anchor_top    = 0.0
	_sabotage_label.anchor_bottom = 0.0
	_sabotage_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_sabotage_label.offset_left   = -320.0
	_sabotage_label.offset_right  = -18.0
	_sabotage_label.offset_top    = 16.0
	_sabotage_label.offset_bottom = 48.0
	_sabotage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sabotage_label.add_theme_font_size_override("font_size", 18)
	_sabotage_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_sabotage_label.add_theme_constant_override("shadow_offset_x", 1)
	_sabotage_label.add_theme_constant_override("shadow_offset_y", 1)
	if ResourceLoader.exists(FONT_PATH):
		_sabotage_label.add_theme_font_override("font", load(FONT_PATH))
	_sabotage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_sabotage_label)

func _update_sabotage_label() -> void:
	if _sabotage_label == null:
		return
	if _sabotage_cooldown <= 0.0:
		_sabotage_label.text = "SABOTAGE [F]: READY"
		_sabotage_label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.45))
	else:
		_sabotage_label.text = "SABOTAGE [F]: %.1fs" % _sabotage_cooldown
		_sabotage_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

# --- Signals & Events ---

func _on_radar_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles") and warning_ui:
		warning_ui.show()
		if "type" in area:
			warning_ui.modulate = Color.RED if area.type == 0 else Color.BLUE
		await get_tree().create_timer(0.5).timeout
		warning_ui.hide()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles"):
		var is_sabotage := area.has_meta("sabotage")
		trigger_momentum_crash(is_sabotage)

func trigger_momentum_crash(is_sabotage: bool = false) -> void:
	if is_stumbling: return
	is_stumbling = true
	GameState.collision_event.emit("player", "SABOTAGE" if is_sabotage else "HIGH_HURDLE")
	_spawn_hit_effect()
	current_speed *= 0.15 if is_sabotage else 0.3
	if has_node("Camera2D2"):
		$Camera2D2.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	play_anim("stumble")
	await get_tree().create_timer(0.15).timeout
	if has_node("Camera2D2"):
		$Camera2D2.offset = Vector2.ZERO
	await get_tree().create_timer(0.35).timeout
	is_stumbling = false
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.75).timeout
		hitbox.set_deferred("monitoring", true)

# --- Early Warning System ---

func _setup_warning_ui() -> void:
	warning_ui.visible = false
	warning_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_ui.anchor_left   = 0.5
	warning_ui.anchor_right  = 0.5
	warning_ui.anchor_top    = 0.0
	warning_ui.anchor_bottom = 0.0
	warning_ui.offset_left   = -150.0
	warning_ui.offset_right  = 150.0
	warning_ui.offset_top    = 160.0
	warning_ui.offset_bottom = 226.0

	if not ResourceLoader.exists(EWS_ALERT_TEX):
		_warning_label = Label.new()
		_warning_label.name = "EWSLabel"
		warning_ui.add_child(_warning_label)
		_warning_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_warning_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		_warning_label.add_theme_font_size_override("font_size", 30)
		_warning_label.add_theme_color_override("font_color", Color.WHITE)
		_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	var sheet := load(EWS_ALERT_TEX) as Texture2D
	if sheet == null:
		return

	var sf := SpriteFrames.new()
	sf.add_animation("alert")
	for i in 16:
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2(i * 80, 0, 80, 80)
		sf.add_frame("alert", a)
	sf.set_animation_loop("alert", true)
	sf.set_animation_speed("alert", 12.0)

	_ews_sprite = AnimatedSprite2D.new()
	_ews_sprite.sprite_frames  = sf
	_ews_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ews_sprite.visible        = false
	_ews_sprite.scale          = Vector2(1.1, 1.1)
	var cl := warning_ui.get_parent()
	cl.add_child(_ews_sprite)
	await get_tree().process_frame
	var rect := warning_ui.get_global_rect()
	_ews_sprite.position = rect.get_center()

func _update_ews() -> void:
	if warning_ui == null:
		return
	var lane := get_parent()
	var nearest_dx: float = INF
	var nearest_is_slide: bool = false
	var found: bool = false
	for h in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and not lane.is_ancestor_of(h):
			continue
		var dx: float = h.global_position.x - global_position.x
		if dx <= 0.0:
			continue
		if dx < nearest_dx:
			nearest_dx = dx
			nearest_is_slide = String(h.name).begins_with("Saw")
			found = true

	if not found or current_speed < 20.0:
		_hide_ews()
		return
	var ttc: float = nearest_dx / current_speed
	if ttc > EWS_LEAD_TIME:
		_hide_ews()
		return

	var t:     float = clampf(ttc / EWS_LEAD_TIME, 0.0, 1.0)
	var alpha: float = lerpf(EWS_MAX_ALPHA, EWS_MIN_ALPHA, t)

	if _ews_sprite != null:
		_ews_sprite.modulate = (Color(0.45, 0.70, 1.0, alpha) if nearest_is_slide
								else Color(1.0, 0.55, 0.55, alpha))
		_ews_sprite.visible = true
		if not _ews_sprite.is_playing():
			_ews_sprite.play("alert")
		_ews_sprite.speed_scale = lerpf(0.8, 2.0, 1.0 - t)
	else:
		var col: Color = Color(0.20, 0.45, 1.0, alpha) if nearest_is_slide \
						 else Color(1.0, 0.25, 0.25, alpha)
		var rect := warning_ui as ColorRect
		if rect:
			rect.color = col
		warning_ui.visible = true
		if _warning_label:
			_warning_label.text = "v  SLIDE" if nearest_is_slide else "^  JUMP"

func _hide_ews() -> void:
	if _ews_sprite != null:
		_ews_sprite.visible = false
		_ews_sprite.stop()
	else:
		warning_ui.visible = false

# --- Collision impact effect ---

func _setup_impact_frames() -> void:
	if not ResourceLoader.exists(IMPACT_TEX):
		return
	var sheet := load(IMPACT_TEX) as Texture2D
	if sheet == null:
		return
	_impact_frames = SpriteFrames.new()
	_impact_frames.add_animation("hit")
	for i in 8:
		var a := AtlasTexture.new()
		a.atlas  = sheet
		a.region = Rect2(i * 80, 0, 80, 80)
		_impact_frames.add_frame("hit", a)
	_impact_frames.set_animation_loop("hit", false)
	_impact_frames.set_animation_speed("hit", 22.0)

func _spawn_hit_effect() -> void:
	if _impact_frames == null:
		return
	var hit_anim := AnimatedSprite2D.new()
	hit_anim.sprite_frames  = _impact_frames
	hit_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hit_anim.scale          = Vector2(1.4, 1.4)
	hit_anim.global_position = global_position
	get_parent().add_child(hit_anim)
	hit_anim.play("hit")
	hit_anim.animation_finished.connect(hit_anim.queue_free)
