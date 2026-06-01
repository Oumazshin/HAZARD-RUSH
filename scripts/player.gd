extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
#  PLAYER CONTROLLER
#  Audit fixes applied (see HAZARD RUSH Audit Report):
#   K-1  Collision penalties now routed through GameState.apply_kei_penalty()
#         which enforces -50 % (standard) / -75 % (sabotage) correctly.
#   K-2  200 ms alternation window now enforced on A / D sprint input.
#   K-3  Passive decay aligned to KEI spec: -0.008/frame = 288 speed/sec.
#   K-4  Stumble elevated decay added: -0.015/frame = 540 speed/sec.
#   K-*  KEI floor (60 speed = 0.10 KEI) enforced everywhere.
# ─────────────────────────────────────────────────────────────────────────────

# --- Movement constants ---
const MAX_SPEED      : float = 600.0
const SPEED_INCREMENT: float = 100.0   # speed gained per valid alternating press
const PENALTY_DROP   : float = 150.0   # speed lost on rhythm break or same-key press
const JUMP_VELOCITY  : float = -400.0
const GRAVITY        : float = 980.0

# --- KEI-aligned decay constants (design doc Table 1) ────────────────────────
# KEI_DECAY_PASSIVE = 0.008/frame  →  0.008 × 600 × 60 fps = 288 speed/sec
# KEI_DECAY_STUMBLE = 0.015/frame  →  0.015 × 600 × 60 fps = 540 speed/sec
# KEI_FLOOR         = 0.10         →  0.10  × 600           =  60 speed
const SPEED_DECAY_PER_SEC  : float = 288.0
const STUMBLE_DECAY_PER_SEC: float = 540.0
const KEI_FLOOR_SPEED      : float = 60.0

# --- 200 ms sprint timing window (design doc Table 2) ────────────────────────
const MAX_TAP_GAP: float = 0.200

# --- Sabotage (offence) ───────────────────────────────────────────────────────
const SABOTAGE_COOLDOWN: float = 6.0

# --- Early Warning System (EWS) ──────────────────────────────────────────────
const EWS_LEAD_TIME: float = 2.0
const EWS_MIN_ALPHA: float = 0.30
const EWS_MAX_ALPHA: float = 0.92

# --- Asset paths ─────────────────────────────────────────────────────────────
const EWS_ALERT_TEX := "res://assets/new/symbol_alert/spritesheet.png"
const FONT_PATH     := "res://assets/Global/text/fonts/BoldPixels.ttf"

# --- State ───────────────────────────────────────────────────────────────────
var current_speed    : float  = 0.0
var last_key_pressed : String = ""
var _last_tap_time   : float  = -1.0   # epoch seconds from Time.get_ticks_msec
var is_sliding       : bool   = false
var is_stumbling     : bool   = false
var time_elapsed     : float  = 0.0
var _was_sliding     : bool   = false
var _sabotage_cooldown: float = 0.0
var _sabotage_charges : int   = 0

# --- Power-up state ──────────────────────────────────────────────────────────
var _shield_active    : bool = false   # Cherries: absorb next hit
var _jump_boost_active: bool = false   # Pineapple: next jump ×2

# --- UI & Animation references ───────────────────────────────────────────────
@onready var anim: AnimationPlayer = $AnimationPlayer
@export var speed_bar  : ProgressBar
@export var warning_ui : Control
@export var timer_label: Label

var _warning_label  : Label            = null
var _ews_sprite     : AnimatedSprite2D = null
var _sabotage_label : Label            = null
var _ai_sabotage_sys: Node             = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("player_character")   # targeted by opponent debuff power-ups
	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value     = 0
	if warning_ui:
		_setup_warning_ui()
	_setup_sabotage_label()
	await get_tree().process_frame
	_ai_sabotage_sys = get_tree().get_first_node_in_group("sabotage_system_ai")

# ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _sabotage_cooldown > 0.0:
		_sabotage_cooldown = max(0.0, _sabotage_cooldown - delta)
	_update_sabotage_label()

	if not GameState.is_racing():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 1. Momentum decay — KEI-aligned (design doc Table 1)
	#    Passive:  -0.008 KEI/frame = 288 speed/sec
	#    Stumble:  -0.015 KEI/frame = 540 speed/sec  (elevated, still applies during stumble)
	if not is_stumbling:
		current_speed -= SPEED_DECAY_PER_SEC * delta
	else:
		current_speed -= STUMBLE_DECAY_PER_SEC * delta
	current_speed = max(KEI_FLOOR_SPEED, current_speed)

	# 2. Slide input
	if Input.is_action_pressed("ui_down") and not is_stumbling:
		is_sliding = is_on_floor() or is_sliding
	else:
		is_sliding = false

	if is_sliding and not _was_sliding:
		AudioManager.play_sfx("slide")
	_was_sliding = is_sliding

	# 3. Gravity & Jump
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) \
				and not is_stumbling and not is_sliding:
			# Pineapple power-up doubles jump height for one jump
			var effective_jump := JUMP_VELOCITY * 2.0 if _jump_boost_active else JUMP_VELOCITY
			velocity.y = effective_jump
			if _jump_boost_active:
				_jump_boost_active = false
			AudioManager.play_sfx("jump")
		else:
			velocity.y = 30.0

	# 4. Forward velocity
	velocity.x = current_speed * 0.8 if is_sliding else current_speed

	# 5. Move
	move_and_slide()

	# 6. Animations
	handle_animations()

	# 7. Write to shared GameState (Physics module write — design doc frame order step 6)
	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value     = current_speed
	GameState.player_kei      = current_speed / MAX_SPEED
	GameState.player_position = global_position.x

	_update_ews()

	if GameState.is_racing():
		time_elapsed += delta
		var time_remaining: float = maxf(0.0, 60.0 - time_elapsed)
		if timer_label:
			timer_label.add_theme_color_override("font_color",
				Color(1.0, 0.3, 0.3) if time_remaining <= 10.0 else Color.WHITE)
			timer_label.text = "TIME: " + str(snapped(time_remaining, 0.1))

# ─────────────────────────────────────────────────────────────────────────────
#  Animations
# ─────────────────────────────────────────────────────────────────────────────

func handle_animations() -> void:
	if is_stumbling:         play_anim("stumble"); return
	if is_sliding:           play_anim("slide");   return
	if not is_on_floor():    play_anim("jump");    return
	if current_speed > 10:
		anim.speed_scale = current_speed / 400.0
		play_anim("run")
	else:
		anim.speed_scale = 1.0
		play_anim("idle")

func play_anim(anim_name: String) -> void:
	if anim.current_animation == anim_name: return
	if anim.has_animation(anim_name): anim.play(anim_name)
	else:                             anim.play("RESET")

# ─────────────────────────────────────────────────────────────────────────────
#  Input — 200 ms alternation window enforced (design doc Table 2)
# ─────────────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sabotage"):
		_try_sabotage()
		return

	# No sprint input accepted during stumble state (design doc Table 1)
	if is_stumbling: return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_pressed: String = ""
		if event.keycode == KEY_A: key_pressed = "A"
		elif event.keycode == KEY_D: key_pressed = "D"

		if key_pressed != "":
			var now: float = Time.get_ticks_msec() / 1000.0

			if key_pressed == last_key_pressed:
				# Same key pressed twice — rhythm break, scaled penalty
				current_speed = max(KEI_FLOOR_SPEED, current_speed - PENALTY_DROP)

			else:
				# Different key — enforce 200 ms ceiling
				if _last_tap_time >= 0.0 and (now - _last_tap_time) > MAX_TAP_GAP:
					# Gap exceeded 200 ms → KEI decay event, no speed gain
					current_speed = max(KEI_FLOOR_SPEED, current_speed - PENALTY_DROP)
				else:
					# Valid alternating press within window → grant speed
					current_speed = min(current_speed + SPEED_INCREMENT, MAX_SPEED)

				last_key_pressed = key_pressed
				_last_tap_time   = now

# ─────────────────────────────────────────────────────────────────────────────
#  Sabotage (offence)
# ─────────────────────────────────────────────────────────────────────────────

func _try_sabotage() -> void:
	if not GameState.is_racing(): return
	if _ai_sabotage_sys == null or not is_instance_valid(_ai_sabotage_sys):
		_ai_sabotage_sys = get_tree().get_first_node_in_group("sabotage_system_ai")
	if _ai_sabotage_sys == null:
		push_warning("[Player] sabotage_system_ai group not found.")
		return
	if _ai_sabotage_sys.is_locked_out(): return
	if _sabotage_charges > 0:
		_sabotage_charges -= 1
	elif _sabotage_cooldown > 0.0:
		return
	else:
		_sabotage_cooldown = SABOTAGE_COOLDOWN
	_ai_sabotage_sys.trigger("player")
	print("[Player] Sabotage launched!")

# ─────────────────────────────────────────────────────────────────────────────
#  Power-up system — 8 fruit effects
# ─────────────────────────────────────────────────────────────────────────────

func receive_powerup(effect: int, value: float) -> void:
	match effect:
		0: _apply_speed_boost(0.30, value)                        # Apple
		1: _apply_debuff_to_opponent("slow",   0.25, value)       # Bananas
		2: _shield_active = true;  print("[Player] Shield ON.")   # Cherries
		3: _apply_ghost_mode(value)                               # Kiwi
		4: print("[Player] Score Rush placeholder (%.0fs)" % value) # Melon
		5: _sabotage_cooldown = 0.0; _sabotage_charges += 1       # Orange
		6: _apply_high_jump(value)                                # Pineapple
		7: _apply_debuff_to_opponent("freeze", 0.0, value)        # Strawberry

func _apply_speed_boost(factor: float, _duration: float) -> void:
	current_speed = min(current_speed + MAX_SPEED * factor, MAX_SPEED)

func _apply_high_jump(window: float) -> void:
	_jump_boost_active = true
	await get_tree().create_timer(window).timeout
	_jump_boost_active = false

func _apply_ghost_mode(duration: float) -> void:
	var hitbox := get_node_or_null("Hitbox")
	if hitbox: hitbox.set_deferred("monitoring", false)
	modulate = Color(1.0, 1.0, 1.0, 0.45)
	await get_tree().create_timer(duration).timeout
	if hitbox and is_instance_valid(hitbox): hitbox.set_deferred("monitoring", true)
	modulate = Color.WHITE

func _apply_debuff_to_opponent(debuff_type: String, factor: float, duration: float) -> void:
	for opp in get_tree().get_nodes_in_group("opponent_ai"):
		if opp.has_method("apply_debuff"):
			opp.apply_debuff(debuff_type, factor, duration)

## Receive a debuff from the AI's offensive power-up.
func apply_debuff(debuff_type: String, factor: float, duration: float) -> void:
	match debuff_type:
		"slow":
			current_speed = max(KEI_FLOOR_SPEED, current_speed * (1.0 - factor))
			await get_tree().create_timer(duration).timeout
		"freeze":
			if not is_stumbling:
				is_stumbling = true
				await get_tree().create_timer(duration).timeout
				is_stumbling = false

# ─────────────────────────────────────────────────────────────────────────────
#  Collision and hit
# ─────────────────────────────────────────────────────────────────────────────

func _on_radar_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles") and warning_ui:
		warning_ui.show()
		if "type" in area:
			warning_ui.modulate = Color.RED if area.type == 0 else Color.BLUE
		await get_tree().create_timer(0.5).timeout
		warning_ui.hide()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles"):
		trigger_momentum_crash(area.has_meta("sabotage"))

func trigger_momentum_crash(is_sabotage: bool = false) -> void:
	# Visual hit effect (ImpactEffect self-destructs after animation)
	ImpactEffect.spawn_at(global_position, get_parent())

	# Cherries shield absorbs one hit without momentum loss
	if _shield_active:
		_shield_active = false
		print("[Player] Shield absorbed the hit!")
		return

	if is_stumbling: return
	is_stumbling = true

	# KEI penalty routed through GameState — correct multipliers enforced:
	#   Standard hurdle: -50 % current KEI  (GameState.KEI_PENALTY_OBSTACLE = 0.50)
	#   Sabotage hazard: -75 % current KEI  (GameState.KEI_PENALTY_SABOTAGE = 0.75)
	# GameState.apply_kei_penalty also emits collision_event and enforces KEI floor.
	GameState.apply_kei_penalty("player", "SABOTAGE" if is_sabotage else "HIGH_HURDLE")
	# Sync raw speed FROM the corrected KEI so the two values stay consistent
	current_speed = GameState.player_kei * MAX_SPEED

	if has_node("Camera2D2"):
		$Camera2D2.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	play_anim("stumble")
	await get_tree().create_timer(0.15).timeout
	if has_node("Camera2D2"):
		$Camera2D2.offset = Vector2.ZERO
	await get_tree().create_timer(0.35).timeout
	is_stumbling = false
	var hitbox := get_node_or_null("Hitbox")
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.75).timeout
		hitbox.set_deferred("monitoring", true)

# ─────────────────────────────────────────────────────────────────────────────
#  Sabotage UI label
# ─────────────────────────────────────────────────────────────────────────────

func _setup_sabotage_label() -> void:
	if warning_ui == null: return
	var cl := warning_ui.get_parent()
	if cl == null: return
	_sabotage_label = Label.new()
	_sabotage_label.name = "SabotageStatus"
	_sabotage_label.anchor_left   = 1.0
	_sabotage_label.anchor_right  = 1.0
	_sabotage_label.anchor_top    = 0.0
	_sabotage_label.anchor_bottom = 0.0
	_sabotage_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_sabotage_label.offset_left   = -340.0
	_sabotage_label.offset_right  =  -18.0
	_sabotage_label.offset_top    =   16.0
	_sabotage_label.offset_bottom =   48.0
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
	if _sabotage_label == null: return
	if _ai_sabotage_sys == null or not is_instance_valid(_ai_sabotage_sys):
		_ai_sabotage_sys = get_tree().get_first_node_in_group("sabotage_system_ai")
	if _ai_sabotage_sys and _ai_sabotage_sys.is_locked_out():
		_sabotage_label.text = "SABOTAGE [F]: LOCKED (%.1fs)" % _ai_sabotage_sys.get_lockout_remaining()
		_sabotage_label.add_theme_color_override("font_color", Color(0.85, 0.30, 0.30))
	elif _sabotage_charges > 0:
		var s := "S" if _sabotage_charges > 1 else ""
		_sabotage_label.text = "SABOTAGE [F]: %d CHARGE%s" % [_sabotage_charges, s]
		_sabotage_label.add_theme_color_override("font_color", Color(0.25, 0.85, 1.0))
	elif _sabotage_cooldown <= 0.0:
		_sabotage_label.text = "SABOTAGE [F]: READY"
		_sabotage_label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.45))
	else:
		_sabotage_label.text = "SABOTAGE [F]: %.1fs" % _sabotage_cooldown
		_sabotage_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

# ─────────────────────────────────────────────────────────────────────────────
#  Early Warning System
# ─────────────────────────────────────────────────────────────────────────────

func _setup_warning_ui() -> void:
	warning_ui.visible      = false
	warning_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_ui.anchor_left   = 0.5
	warning_ui.anchor_right  = 0.5
	warning_ui.anchor_top    = 0.0
	warning_ui.anchor_bottom = 0.0
	warning_ui.offset_left   = -150.0
	warning_ui.offset_right  =  150.0
	warning_ui.offset_top    =  160.0
	warning_ui.offset_bottom =  226.0
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
	if sheet == null: return
	var sf := SpriteFrames.new()
	sf.add_animation("alert")
	for i in 16:
		var a    := AtlasTexture.new()
		a.atlas  =  sheet
		a.region =  Rect2(i * 80, 0, 80, 80)
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
	_ews_sprite.position = warning_ui.get_global_rect().get_center()

func _update_ews() -> void:
	if warning_ui == null: return
	var lane             := get_parent()
	var nearest_dx       : float = INF
	var nearest_is_slide : bool  = false
	var found            : bool  = false
	for h in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and not lane.is_ancestor_of(h): continue
		var dx: float = h.global_position.x - global_position.x
		if dx <= 0.0: continue
		if dx < nearest_dx:
			nearest_dx       = dx
			nearest_is_slide = String(h.name).begins_with("Saw")
			found            = true
	if not found or current_speed < 20.0: _hide_ews(); return
	var ttc: float = nearest_dx / current_speed
	if ttc > EWS_LEAD_TIME: _hide_ews(); return
	var t    : float = clampf(ttc / EWS_LEAD_TIME, 0.0, 1.0)
	var alpha: float = lerpf(EWS_MAX_ALPHA, EWS_MIN_ALPHA, t)
	if _ews_sprite != null:
		_ews_sprite.modulate    = Color(0.45, 0.70, 1.0, alpha) if nearest_is_slide \
								  else Color(1.0, 0.55, 0.55, alpha)
		_ews_sprite.visible     = true
		_ews_sprite.speed_scale = lerpf(0.8, 2.0, 1.0 - t)
		if not _ews_sprite.is_playing(): _ews_sprite.play("alert")
	else:
		var col := Color(0.20, 0.45, 1.0, alpha) if nearest_is_slide \
				   else Color(1.0, 0.25, 0.25, alpha)
		var rect := warning_ui as ColorRect
		if rect: rect.color = col
		warning_ui.visible = true
		if _warning_label:
			_warning_label.text = "v  SLIDE" if nearest_is_slide else "^  JUMP"

func _hide_ews() -> void:
	if _ews_sprite != null:
		_ews_sprite.visible = false
		_ews_sprite.stop()
	else:
		warning_ui.visible = false
