extends CharacterBody2D

# --- Constants ---
const MAX_SPEED: float = 600.0
const SPEED_INCREMENT: float = 100.0
const SPEED_DECAY: float = 60.0
const PENALTY_DROP: float = 150.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

# --- State Variables ---
var current_speed: float = 0.0
var last_key_pressed: String = ""
var is_sliding: bool = false
var is_stumbling: bool = false
var time_elapsed: float = 0.0

# --- UI & Animation References ---
@onready var anim: AnimationPlayer = $AnimationPlayer
@export var speed_bar: ProgressBar
@export var warning_ui: Control
@export var timer_label: Label

func _ready() -> void:
	if speed_bar:
		speed_bar.max_value = MAX_SPEED
		speed_bar.value = 0

func _physics_process(delta: float) -> void:
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
		# If we are holding down, ONLY slide if we are on the floor, 
		# OR if we were ALREADY sliding (ignores 1-frame physics bumps)
		if is_on_floor() or is_sliding:
			is_sliding = true
		else:
			is_sliding = false
	else:
		is_sliding = false

	# 3. Enhanced Gravity & Jump Logic
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		# Only jump if NOT sliding
		if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and not is_stumbling and not is_sliding:
			velocity.y = JUMP_VELOCITY
		else:
			# Keep firmly planted on the floor
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
	# Write to GameState so AI can read player data
	GameState.player_kei = current_speed / MAX_SPEED
	GameState.player_position = global_position.x
	
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

	# Because we protected is_sliding in physics, we can trust it completely here
	if is_sliding:
		play_anim("slide")
		return

	if not is_on_floor():
		play_anim("jump") 
		return

	# Ground locomotion
	if current_speed > 10:
		anim.speed_scale = current_speed / 400.0
		play_anim("run")
	else:
		anim.speed_scale = 1.0
		play_anim("idle")

# Safe animation swapper that respects track properties and blocks frame-restart looping
func play_anim(anim_name: String):
	if anim.current_animation == anim_name:
		return
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		anim.play("RESET")

# --- Input Mechanics ---

func _unhandled_input(event: InputEvent) -> void:
	if is_stumbling: return

	# Rhythm Tapping (A/D) - Kept here as events feel better for tapping
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

# --- Signals & Events ---

func _on_radar_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles") and warning_ui:
		warning_ui.show()
		
		# Safety check: Only change color IF the area actually has a "type" variable
		if "type" in area:
			warning_ui.modulate = Color.RED if area.type == 0 else Color.BLUE
		
		await get_tree().create_timer(0.5).timeout
		warning_ui.hide()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles"):
		trigger_momentum_crash()

func trigger_momentum_crash() -> void:
	if is_stumbling: return
	
	is_stumbling = true
	GameState.collision_event.emit("player", "HIGH_HURDLE")  # ← ADD THIS LINE
	current_speed *= 0.3
	
	if has_node("Camera2D2"):
		$Camera2D2.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	
	play_anim("stumble")
	
	await get_tree().create_timer(0.15).timeout
	if has_node("Camera2D2"):
		$Camera2D2.offset = Vector2.ZERO
	
	# Invulnerable for 1.5 seconds after stumble ends
	await get_tree().create_timer(0.35).timeout
	is_stumbling = false
	
	# Brief invulnerability window
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.75).timeout
		hitbox.set_deferred("monitoring", true)
