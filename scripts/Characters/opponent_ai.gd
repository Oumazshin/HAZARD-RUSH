extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
#  AI CONTROLLER (Orchestrator)
# ─────────────────────────────────────────────────────────────────────────────

# --- Movement constants (INCREASED SPEED & MOMENTUM) ---
const MAX_SPEED    : float = 800.0   # Increased from 600
const JUMP_VELOCITY: float = -500.0  # Increased to match speed
const GRAVITY      : float = 1200.0  # Increased for snappier jumps

# --- KEI-aligned decay constants (Scaled for 800 Max Speed) ---
const SPEED_DECAY_PER_SEC  : float = 384.0   
const STUMBLE_DECAY_PER_SEC: float = 720.0   
const KEI_FLOOR_SPEED      : float = 80.0    

const GREEDY_WINDOW_FAR : float = 0.40
const GREEDY_WINDOW_NEAR: float = 0.15

var rhythm_timer   : float = 0.0
var rhythm_interval: float = 0.15
var last_tap       : int   = 0
var current_speed  : float = 0.0

var is_sliding   : bool = false
var is_stumbling : bool = false

var _shield_active    : bool = false
var _high_jump_pending: bool = false

var evasion_pending: bool   = false
var obstacle_seen  : String = ""
var reaction_delay : float  = 0.15

var planner              : AStarPlanner = null
var plan_frame_counter   : int          = 0
var plan_interval        : int          = 15
var current_planned_action: String      = "SPRINT_STEADY"

var ida_planner: IDAStarPlanner = null

var minimax               : MinimaxEvaluator = null
var sabotage_cooldown     : float            = 0.0
var sabotage_cooldown_time: float            = 8.0
var _sabotage_charges     : int              = 0

var sabotage_system: Node = null

var sprite       : Sprite2D
var anim         : AnimationPlayer
var jump_raycast : RayCast2D   
var slide_raycast: RayCast2D

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("opponent_ai")

	sprite        = get_node_or_null("Sprite2D")
	anim          = get_node_or_null("AnimationPlayer")
	jump_raycast  = get_node_or_null("JumpRaycast")
	slide_raycast = get_node_or_null("SlideRaycast")

	sabotage_system = get_tree().get_first_node_in_group("sabotage_system_player")

	match GameState.difficulty:
		GameState.Difficulty.EASY:
			reaction_delay         = 0.25
			rhythm_interval        = 0.20
			sabotage_cooldown_time = 12.0
		GameState.Difficulty.MEDIUM:
			reaction_delay         = 0.15
			rhythm_interval        = 0.15
			sabotage_cooldown_time = 8.0
		GameState.Difficulty.HARD:
			reaction_delay         = 0.08
			rhythm_interval        = 0.10
			sabotage_cooldown_time = 5.0

	planner     = AStarPlanner.new();     planner.setup(GameState.difficulty)
	ida_planner = IDAStarPlanner.new();   ida_planner.setup(GameState.difficulty)
	minimax     = MinimaxEvaluator.new(); minimax.setup(GameState.difficulty)

	await get_tree().process_frame

	var goal := get_parent().get_node_or_null("Goal")
	if goal:
		GameState.finish_line_x = goal.global_position.x

	if sabotage_system == null:
		sabotage_system = get_tree().get_first_node_in_group("sabotage_system_player")

	if sabotage_system != null and sabotage_system.has_signal("trigger_window_active"):
		sabotage_system.trigger_window_active.connect(_on_trigger_window_active)

func _physics_process(delta: float) -> void:
	if not GameState.is_racing():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if not is_stumbling:
		rhythm_timer += delta
		if rhythm_timer >= rhythm_interval:
			rhythm_timer  = 0.0
			last_tap      = 1 - last_tap
			# Adjusted AI speed gain per tap to account for new MAX_SPEED
			current_speed = min(current_speed + 150.0, MAX_SPEED) 

	if not is_stumbling:
		current_speed -= SPEED_DECAY_PER_SEC * delta
	else:
		current_speed -= STUMBLE_DECAY_PER_SEC * delta
	current_speed = max(KEI_FLOOR_SPEED, current_speed)

	plan_frame_counter += 1
	if plan_frame_counter >= plan_interval:
		plan_frame_counter = 0
		_run_astar_planner()

	if not is_stumbling and not evasion_pending and current_speed > 10.0:
		_check_greedy_reflex()

	sabotage_cooldown -= delta

	if is_stumbling:
		velocity.x = 0.0
	elif is_sliding:
		velocity.x = current_speed * 0.8
	else:
		match current_planned_action:
			"SPRINT_AGGRESSIVE":
				current_speed = min(current_speed + 30.0 * delta, MAX_SPEED)
				velocity.x    = current_speed
			"CONSERVE":
				current_speed = min(current_speed, MAX_SPEED * 0.6)
				velocity.x    = current_speed
			_:
				velocity.x = current_speed

	move_and_slide()

	if anim:
		_handle_animation()

	GameState.ai_kei      = current_speed / MAX_SPEED
	GameState.ai_position = global_position.x
	_check_finish_line()

func _check_finish_line() -> void:
	if not GameState.is_racing(): return
	if global_position.x >= GameState.finish_line_x:
		GameState.winner     = "ai"
		GameState.win_reason = "finish_line"
		GameState.set_phase(GameState.RacePhase.FINISHED)

func _run_astar_planner() -> void:
	var window := _get_obstacle_window()
	var ai_kei := GameState.ai_kei

	if GameState.difficulty == GameState.Difficulty.EASY:
		current_planned_action = ida_planner.plan(ai_kei, window)
		return

	var result : String = planner.plan(ai_kei, window)
	if result.is_empty():
		current_planned_action = ida_planner.plan(ai_kei, window)
	else:
		current_planned_action = result

func _get_obstacle_window() -> Array:
	var my_lane   := get_parent()
	var obstacles := []
	for node in get_tree().get_nodes_in_group("hurdles"):
		if my_lane != null and not my_lane.is_ancestor_of(node): continue
		if node.global_position.x > global_position.x:
			obstacles.append({
				"position": node.global_position.x,
				"type":     node.get("type") if "type" in node else 0
			})
	obstacles.sort_custom(func(a, b): return a["position"] < b["position"])
	return obstacles.slice(0, planner.lookahead_n)

func _on_trigger_window_active() -> void:
	var can_fire := _sabotage_charges > 0 or sabotage_cooldown <= 0.0
	if not can_fire: return

	var snapshot : Dictionary = {
		"ai_kei"                : GameState.ai_kei,
		"player_kei"            : GameState.player_kei,
		"sabotage_window_active": true,
		"player_in_dense_zone"  : _is_player_in_dense_zone(),
	}
	var depth    : int    = int(GameState.get_difficulty_param("minimax_depth"))
	var decision : String = minimax.decide(snapshot, depth, true)

	if decision == "ACTIVATE":
		if _sabotage_charges > 0:
			_sabotage_charges -= 1
		else:
			sabotage_cooldown = sabotage_cooldown_time
		if sabotage_system and is_instance_valid(sabotage_system):
			sabotage_system.trigger("ai")

func _is_player_in_dense_zone() -> bool:
	var count := 0
	for node in get_tree().get_nodes_in_group("hurdles"):
		if abs(node.global_position.x - GameState.player_position) < 300.0:
			count += 1
	return count >= 2

func _check_greedy_reflex() -> void:
	var my_lane    := get_parent()
	var nearest_dx : float = INF
	var is_saw     : bool  = false

	for h in get_tree().get_nodes_in_group("hurdles"):
		if my_lane != null and not my_lane.is_ancestor_of(h): continue
		var dx : float = h.global_position.x - global_position.x
		if dx > 0.0 and dx < nearest_dx:
			nearest_dx = dx
			is_saw     = String(h.name).begins_with("Saw")

	if nearest_dx == INF or current_speed <= 0.0:
		return

	var ttc : float = nearest_dx / current_speed
	if ttc <= GREEDY_WINDOW_FAR and ttc >= GREEDY_WINDOW_NEAR:
		_trigger_evasion("slide" if is_saw else "jump")

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
		ui.show_powerup(false, effect, value)

	match effect:
		0: 
			current_speed = min(current_speed + MAX_SPEED * 0.30, MAX_SPEED)
			_play_powerup_vfx(Color(0.35, 1.0, 0.35)) # Green Apple
		1: 
			_apply_debuff_to_player("slow", 0.25, value)
		2: 
			_shield_active = true
			_play_powerup_vfx(Color(0.3, 0.85, 1.0)) # Cyan Shield
		3: 
			_apply_ghost_mode(value)
		4: 
			_play_powerup_vfx(Color(1.0, 0.85, 0.2)) # Gold Melon
		5: 
			sabotage_cooldown = 0.0; _sabotage_charges += 1
			_play_powerup_vfx(Color(1.0, 0.55, 0.15)) # Orange
		6:
			_high_jump_pending = true
			get_tree().create_timer(value).timeout.connect(func() -> void: _high_jump_pending = false)
			_play_powerup_vfx(Color(1.0, 0.5, 0.9)) # Pink Pineapple
		7: 
			_apply_debuff_to_player("freeze", 0.0, value)

func _apply_ghost_mode(duration: float) -> void:
	var hitbox := get_node_or_null("Hitbox")
	if hitbox: hitbox.set_deferred("monitoring", false)
	modulate = Color(1.0, 1.0, 1.0, 0.45) # Transparent ghost
	await get_tree().create_timer(duration).timeout
	if hitbox and is_instance_valid(hitbox): hitbox.set_deferred("monitoring", true)
	modulate = Color.WHITE

func _apply_debuff_to_player(debuff_type: String, factor: float, duration: float) -> void:
	for pc in get_tree().get_nodes_in_group("player_character"):
		if pc.has_method("apply_debuff"):
			pc.apply_debuff(debuff_type, factor, duration)

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

func _trigger_evasion(obstacle_type: String) -> void:
	evasion_pending = true
	obstacle_seen   = obstacle_type
	await get_tree().create_timer(reaction_delay).timeout
	evasion_pending = false
	if is_stumbling: return
	if obstacle_seen == "slide" and is_on_floor():
		_enable_slide_shapes()
		is_sliding = true
		await get_tree().create_timer(1.0).timeout
		is_sliding = false
		_disable_slide_shapes()
	elif obstacle_seen == "jump" and is_on_floor():
		var effective_jump := JUMP_VELOCITY * 2.0 if _high_jump_pending else JUMP_VELOCITY
		velocity.y          = effective_jump
		if _high_jump_pending: _high_jump_pending = false

func _enable_slide_shapes() -> void:
	var sc  := get_node_or_null("StandCollision");     if sc:  sc.disabled  = true
	var sl  := get_node_or_null("SlideCollision");     if sl:  sl.disabled  = false
	var sh  := get_node_or_null("Hitbox/StandHitbox"); if sh:  sh.disabled = true
	var slh := get_node_or_null("Hitbox/SlideHitbox"); if slh: slh.disabled = false

func _disable_slide_shapes() -> void:
	var sc  := get_node_or_null("StandCollision");     if sc:  sc.disabled  = false
	var sl  := get_node_or_null("SlideCollision");     if sl:  sl.disabled  = true
	var sh  := get_node_or_null("Hitbox/StandHitbox"); if sh:  sh.disabled = false
	var slh := get_node_or_null("Hitbox/SlideHitbox"); if slh: slh.disabled = true

func _handle_animation() -> void:
	if is_stumbling:         anim.play("stumble")
	elif is_sliding:         anim.play("slide")
	elif not is_on_floor():  anim.play("jump")
	elif current_speed > 10: 
		anim.speed_scale = current_speed / 500.0 # Adjusted scale for new speed
		anim.play("run")
	else:                    
		anim.speed_scale = 1.0
		anim.play("idle")

# ─────────────────────────────────────────────────────────────────────────────
#  Collision and hit (WITH EXTENDED INVULNERABILITY)
# ─────────────────────────────────────────────────────────────────────────────

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles") and not is_stumbling:
		_trigger_stumble(area.has_meta("sabotage"))

func _trigger_stumble(is_sabotage: bool = false) -> void:
	ImpactEffect.spawn_at(global_position, get_parent())

	if _shield_active:
		_shield_active = false
		return

	if is_stumbling: return
	is_stumbling = true
	is_sliding   = false
	_disable_slide_shapes()

	GameState.apply_kei_penalty("ai", "SABOTAGE" if is_sabotage else "HIGH_HURDLE")
	current_speed = GameState.ai_kei * MAX_SPEED

	await get_tree().create_timer(GameState.STUMBLE_DURATION).timeout
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
