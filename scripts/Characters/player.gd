extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
#  PLAYER CONTROLLER
# ─────────────────────────────────────────────────────────────────────────────

# --- Movement constants (INCREASED SPEED & MOMENTUM) ---
const MAX_SPEED       : float = 800.0   # Increased from 600
const SPEED_INCREMENT : float = 150.0   # Increased from 100
const PENALTY_DROP    : float = 200.0   # Increased from 150
const JUMP_VELOCITY   : float = -500.0  # Increased to match speed
const GRAVITY         : float = 1200.0  # Increased for snappier jumps

# --- KEI-aligned decay constants (Scaled for 800 Max Speed) ---
const SPEED_DECAY_PER_SEC   : float = 384.0  # 0.008 * 800 * 60fps
const STUMBLE_DECAY_PER_SEC : float = 720.0  # 0.015 * 800 * 60fps
const KEI_FLOOR_SPEED       : float = 80.0   # 10% of 800

const MAX_TAP_GAP       : float = 0.200
const SABOTAGE_COOLDOWN : float = 6.0

# --- Asset path ---
const EWS_ALERT_TEX := "res://assets/new/symbol_alert/spritesheet.png"

# --- State ---
var current_speed      : float  = 0.0
var last_key_pressed   : String = ""
var _last_tap_time     : float  = -1.0
var is_sliding         : bool   = false
var is_stumbling       : bool   = false
var _was_sliding       : bool   = false
var _sabotage_cooldown : float  = 0.0
var _sabotage_charges  : int    = 0

var _shield_active     : bool = false
var _jump_boost_active : bool = false

@onready var anim : AnimationPlayer = $AnimationPlayer
@export var speed_bar : ProgressBar

var _ai_sabotage_sys : Node = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("player_character")
	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value     = 0
	await get_tree().process_frame
	_ai_sabotage_sys = get_tree().get_first_node_in_group("sabotage_system_ai")

func _physics_process(delta: float) -> void:
	if _sabotage_cooldown > 0.0:
		_sabotage_cooldown = max(0.0, _sabotage_cooldown - delta)

	if not GameState.is_racing():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_stumbling:
		current_speed -= SPEED_DECAY_PER_SEC * delta
	else:
		current_speed -= STUMBLE_DECAY_PER_SEC * delta
	current_speed = max(KEI_FLOOR_SPEED, current_speed)

	if Input.is_action_pressed("ui_down") and not is_stumbling:
		is_sliding = is_on_floor() or is_sliding
	else:
		is_sliding = false

	if is_sliding and not _was_sliding:
		AudioManager.play_sfx("slide")
	_was_sliding = is_sliding

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) \
				and not is_stumbling and not is_sliding:
			var effective_jump := JUMP_VELOCITY * 2.0 if _jump_boost_active else JUMP_VELOCITY
			velocity.y = effective_jump
			if _jump_boost_active: _jump_boost_active = false
			AudioManager.play_sfx("jump")
		else:
			velocity.y = 30.0

	velocity.x = current_speed * 0.8 if is_sliding else current_speed
	move_and_slide()
	handle_animations()

	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value     = current_speed
		
	GameState.player_kei      = current_speed / MAX_SPEED
	GameState.player_position = global_position.x

func handle_animations() -> void:
	if is_stumbling:       play_anim("stumble"); return
	if is_sliding:         play_anim("slide");   return
	if not is_on_floor():  play_anim("jump");    return
	if current_speed > 10:
		anim.speed_scale = current_speed / 500.0 # Adjusted scale for new speed
		play_anim("run")
	else:
		anim.speed_scale = 1.0
		play_anim("idle")

func play_anim(anim_name: String) -> void:
	if anim.current_animation == anim_name: return
	if anim.has_animation(anim_name): anim.play(anim_name)
	else:                             anim.play("RESET")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sabotage"):
		_try_sabotage()
		return

	if is_stumbling: return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_pressed : String = ""
		if event.keycode == KEY_A: key_pressed = "A"
		elif event.keycode == KEY_D: key_pressed = "D"

		if key_pressed != "":
			var now : float = Time.get_ticks_msec() / 1000.0

			if key_pressed == last_key_pressed:
				current_speed = max(KEI_FLOOR_SPEED, current_speed - PENALTY_DROP)
			else:
				if _last_tap_time >= 0.0 and (now - _last_tap_time) > MAX_TAP_GAP:
					current_speed = max(KEI_FLOOR_SPEED, current_speed - PENALTY_DROP)
				else:
					current_speed = min(current_speed + SPEED_INCREMENT, MAX_SPEED)
				last_key_pressed = key_pressed
				_last_tap_time   = now

func _try_sabotage() -> void:
	if not GameState.is_racing(): return
	if _ai_sabotage_sys == null or not is_instance_valid(_ai_sabotage_sys):
		_ai_sabotage_sys = get_tree().get_first_node_in_group("sabotage_system_ai")
	if _ai_sabotage_sys == null: return
	if _ai_sabotage_sys.is_locked_out(): return
	
	if _sabotage_charges > 0:
		_sabotage_charges -= 1
	elif _sabotage_cooldown > 0.0:
		return
	else:
		_sabotage_cooldown = SABOTAGE_COOLDOWN
		
	_ai_sabotage_sys.trigger("player")

# ─────────────────────────────────────────────────────────────────────────────
#  Power-up system & VFX
# ─────────────────────────────────────────────────────────────────────────────

func _play_powerup_vfx(glow_color: Color) -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", glow_color, 0.15)
	tw.tween_property(self, "modulate", Color.WHITE, 0.35)

func receive_powerup(effect: int, value: float) -> void:
	var ui = get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("show_powerup"):
		ui.show_powerup(true, effect, value)

	match effect:
		0: 
			_apply_speed_boost(0.30, value)
			_play_powerup_vfx(Color(0.35, 1.0, 0.35)) # Green Apple
		1: 
			_apply_debuff_to_opponent("slow", 0.25, value)
		2: 
			_shield_active = true
			_play_powerup_vfx(Color(0.3, 0.85, 1.0)) # Cyan Shield
		3: 
			_apply_ghost_mode(value)
		4: 
			_play_powerup_vfx(Color(1.0, 0.85, 0.2)) # Gold Melon
		5: 
			_sabotage_cooldown = 0.0; _sabotage_charges += 1
			_play_powerup_vfx(Color(1.0, 0.55, 0.15)) # Orange
		6: 
			_apply_high_jump(value)
			_play_powerup_vfx(Color(1.0, 0.5, 0.9)) # Pink Pineapple
		7: 
			_apply_debuff_to_opponent("freeze", 0.0, value)

func _apply_speed_boost(factor: float, _duration: float) -> void:
	current_speed = min(current_speed + MAX_SPEED * factor, MAX_SPEED)

func _apply_high_jump(window: float) -> void:
	_jump_boost_active = true
	await get_tree().create_timer(window).timeout
	_jump_boost_active = false

func _apply_ghost_mode(duration: float) -> void:
	var hitbox := get_node_or_null("Hitbox")
	if hitbox: hitbox.set_deferred("monitoring", false)
	modulate = Color(1.0, 1.0, 1.0, 0.45) # Transparent Ghost
	await get_tree().create_timer(duration).timeout
	if hitbox and is_instance_valid(hitbox): hitbox.set_deferred("monitoring", true)
	modulate = Color.WHITE

func _apply_debuff_to_opponent(debuff_type: String, factor: float, duration: float) -> void:
	for opp in get_tree().get_nodes_in_group("opponent_ai"):
		if opp.has_method("apply_debuff"):
			opp.apply_debuff(debuff_type, factor, duration)

func apply_debuff(debuff_type: String, factor: float, duration: float) -> void:
	match debuff_type:
		"slow":
			_play_powerup_vfx(Color(1.0, 0.95, 0.2)) # Banana Yellow
			current_speed = max(KEI_FLOOR_SPEED, current_speed * (1.0 - factor))
			await get_tree().create_timer(duration).timeout
		"freeze":
			_play_powerup_vfx(Color(0.5, 0.9, 1.0)) # Ice Blue
			if not is_stumbling:
				is_stumbling = true
				await get_tree().create_timer(duration).timeout
				is_stumbling = false

# ─────────────────────────────────────────────────────────────────────────────
#  Collision and hit (WITH EXTENDED INVULNERABILITY)
# ─────────────────────────────────────────────────────────────────────────────

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles"):
		trigger_momentum_crash(area.has_meta("sabotage"))

func trigger_momentum_crash(is_sabotage: bool = false) -> void:
	ImpactEffect.spawn_at(global_position, get_parent())

	if _shield_active:
		_shield_active = false
		return

	if is_stumbling: return
	is_stumbling = true

	GameState.apply_kei_penalty("player", "SABOTAGE" if is_sabotage else "HIGH_HURDLE")
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
		
		# Visual Invulnerability Blinking Effect
		var blink_tw = create_tween().set_loops(6) # Blinks 6 times over 1.5s
		blink_tw.tween_property(self, "modulate:a", 0.3, 0.125)
		blink_tw.tween_property(self, "modulate:a", 1.0, 0.125)
		
		# INCREASED INVULNERABILITY WINDOW (1.5 seconds)
		await get_tree().create_timer(1.5).timeout
		
		blink_tw.kill()
		modulate.a = 1.0
		hitbox.set_deferred("monitoring", true)
