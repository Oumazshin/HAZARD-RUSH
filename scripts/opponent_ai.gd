extends CharacterBody2D

const MAX_SPEED: float = 600.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0

# --- Rhythm Tapping ---
var rhythm_timer: float = 0.0
var rhythm_interval: float = 0.15
var last_tap: int = 0
var current_speed: float = 0.0

# --- State ---
var is_sliding: bool = false
var is_stumbling: bool = false

# --- Greedy Reflex ---
var evasion_pending: bool = false
var obstacle_seen: String = ""
var reaction_delay: float = 0.15

# --- A* Planner ---
var planner: AStarPlanner = null
var plan_frame_counter: int = 0
var plan_interval: int = 15
var current_planned_action: String = "SPRINT_STEADY"

# --- IDA* Fallback Planner ---
var ida_planner: IDAStarPlanner = null

# --- Minimax Sabotage ---
var minimax: MinimaxEvaluator = null
var sabotage_cooldown: float = 0.0
var sabotage_cooldown_time: float = 8.0
var sabotage_check_interval: float = 3.0
var sabotage_check_timer: float = 0.0

# --- Sabotage System (the PLAYER's lane system — the AI attacks the player) ---
var sabotage_system: Node = null

# --- Finish Line ---
var _finish_line_x: float = -1.0

var sprite: Sprite2D
var anim: AnimationPlayer
var jump_raycast: RayCast2D
var slide_raycast: RayCast2D

func _ready() -> void:
	sprite = get_node_or_null("Sprite2D")
	anim = get_node_or_null("AnimationPlayer")
	jump_raycast = get_node_or_null("JumpRaycast")
	slide_raycast = get_node_or_null("SlideRaycast")

	# The AI attacks the PLAYER, so it drives the PLAYER lane's sabotage system,
	# which lives in a different SubViewport. Find it globally by its lane group.
	sabotage_system = get_tree().get_first_node_in_group("sabotage_system_player")

	# Difficulty parameters
	match GameState.difficulty:
		GameState.Difficulty.EASY:
			reaction_delay = 0.25
			rhythm_interval = 0.20
			sabotage_cooldown_time = 12.0
		GameState.Difficulty.MEDIUM:
			reaction_delay = 0.15
			rhythm_interval = 0.15
			sabotage_cooldown_time = 8.0
		GameState.Difficulty.HARD:
			reaction_delay = 0.08
			rhythm_interval = 0.10
			sabotage_cooldown_time = 5.0

	# Initialize A* planner
	planner = AStarPlanner.new()
	planner.setup(GameState.difficulty)

	# Initialize IDA* fallback planner
	ida_planner = IDAStarPlanner.new()
	ida_planner.setup(GameState.difficulty)

	# Initialize Minimax evaluator
	minimax = MinimaxEvaluator.new()
	minimax.setup(GameState.difficulty)

	# Find finish line X from the Goal node in the same scene
	await get_tree().process_frame
	var goal := get_parent().get_node_or_null("Goal")
	if goal:
		_finish_line_x = goal.global_position.x
		print("[OpponentAI] Finish line at X=", _finish_line_x)
	else:
		push_warning("[OpponentAI] Goal node not found in AILane.")

	# Whole tree is ready now — make sure we grabbed the player's sabotage system.
	if sabotage_system == null:
		sabotage_system = get_tree().get_first_node_in_group("sabotage_system_player")
	if sabotage_system == null:
		push_warning("[OpponentAI] Player SabotageSystem not found (group 'sabotage_system_player').")

func _physics_process(delta: float) -> void:
	if not GameState.is_racing():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 1. Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2. Rhythm tapping
	if not is_stumbling:
		rhythm_timer += delta
		if rhythm_timer >= rhythm_interval:
			rhythm_timer = 0.0
			last_tap = 1 - last_tap
			current_speed = min(current_speed + 100.0, MAX_SPEED)

	# 3. Speed decay
	if not is_stumbling:
		current_speed = max(current_speed - 60.0 * delta, 0.0)

	# 4. A* Planner every 15 frames
	plan_frame_counter += 1
	if plan_frame_counter >= plan_interval:
		plan_frame_counter = 0
		_run_astar_planner()

	# 5. Greedy Reflex — immediate evasion override
	if jump_raycast and slide_raycast:
		if is_on_floor() and not is_stumbling and not evasion_pending:
			if slide_raycast.is_colliding():
				_trigger_evasion("slide")
			elif jump_raycast.is_colliding():
				_trigger_evasion("jump")

	# 6. Minimax Sabotage (the AI decides whether to attack the player)
	sabotage_cooldown -= delta
	sabotage_check_timer -= delta
	if sabotage_check_timer <= 0.0:
		sabotage_check_timer = sabotage_check_interval
		_evaluate_sabotage()

	# 7. Apply movement
	if is_stumbling:
		velocity.x = 0.0
	elif is_sliding:
		velocity.x = current_speed * 0.8
	else:
		match current_planned_action:
			"SPRINT_AGGRESSIVE":
				current_speed = min(current_speed + 20.0 * delta, MAX_SPEED)
				velocity.x = current_speed
			"CONSERVE":
				current_speed = min(current_speed, MAX_SPEED * 0.6)
				velocity.x = current_speed
			_:
				velocity.x = current_speed

	move_and_slide()

	# 8. Animation
	if anim:
		_handle_animation()

	# 9. Write to GameState
	GameState.ai_kei = current_speed / MAX_SPEED
	GameState.ai_position = global_position.x

	# 10. Check finish line
	_check_finish_line()

# --- Finish Line Check ---
func _check_finish_line() -> void:
	if _finish_line_x < 0 or not GameState.is_racing():
		return
	if global_position.x >= _finish_line_x:
		_finish_line_x = -1.0
		GameState.winner = "AI"
		GameState.win_reason = "finish_line"
		print("[OpponentAI] Crossed the finish line!")
		GameState.set_phase(GameState.RacePhase.FINISHED)

# --- A* Planner with IDA* Fallback ---
func _run_astar_planner() -> void:
	var window := _get_obstacle_window()
	var ai_kei := current_speed / MAX_SPEED

	if GameState.difficulty == GameState.Difficulty.EASY:
		current_planned_action = ida_planner.plan(ai_kei, window)
	else:
		var astar_result := planner.plan(ai_kei, window)
		var astar_failed := (astar_result == "SPRINT_STEADY" and window.size() > 0)
		if astar_failed:
			current_planned_action = ida_planner.plan(ai_kei, window)
		else:
			current_planned_action = astar_result

# Only considers obstacles in the AI's OWN lane, so hazards spawned in the
# player's lane (including the player's sabotage) never confuse the AI planner.
func _get_obstacle_window() -> Array:
	var my_lane := get_parent()
	var obstacles = []
	for node in get_tree().get_nodes_in_group("hurdles"):
		if my_lane != null and not my_lane.is_ancestor_of(node):
			continue
		if node.global_position.x > global_position.x:
			obstacles.append({
				"position": node.global_position.x,
				"type": node.get("type") if "type" in node else 0
			})
	obstacles.sort_custom(func(a, b): return a["position"] < b["position"])
	return obstacles.slice(0, planner.lookahead_n)

# --- Minimax Sabotage ---
func _evaluate_sabotage() -> void:
	if sabotage_cooldown > 0.0:
		return
	# Safety net: resolve the player's sabotage system lazily if it wasn't ready at _ready().
	if sabotage_system == null or not is_instance_valid(sabotage_system):
		sabotage_system = get_tree().get_first_node_in_group("sabotage_system_player")
	var decision = minimax.decide(
		current_speed / MAX_SPEED,
		GameState.player_kei,
		_is_player_in_dense_zone()
	)
	if decision == "ACTIVATE":
		if sabotage_system:
			sabotage_system.trigger("ai")   # the AI is the attacker; victim = player
		sabotage_cooldown = sabotage_cooldown_time
		print("[OpponentAI] Sabotage launched at the player!")

func _is_player_in_dense_zone() -> bool:
	var count = 0
	for node in get_tree().get_nodes_in_group("hurdles"):
		if abs(node.global_position.x - GameState.player_position) < 300.0:
			count += 1
	return count >= 2

# --- Greedy Reflex ---
func _trigger_evasion(obstacle_type: String) -> void:
	evasion_pending = true
	obstacle_seen = obstacle_type
	await get_tree().create_timer(reaction_delay).timeout
	evasion_pending = false
	if is_stumbling:
		return
	if obstacle_seen == "slide" and is_on_floor():
		_enable_slide_shapes()
		is_sliding = true
		await get_tree().create_timer(1.0).timeout
		is_sliding = false
		_disable_slide_shapes()
	elif obstacle_seen == "jump" and is_on_floor():
		velocity.y = JUMP_VELOCITY

# --- Collision Shape Helpers ---
func _enable_slide_shapes() -> void:
	var stand_col = get_node_or_null("StandCollision")
	var slide_col = get_node_or_null("SlideCollision")
	var stand_hit = get_node_or_null("Hitbox/StandHitbox")
	var slide_hit = get_node_or_null("Hitbox/SlideHitbox")
	if stand_col: stand_col.disabled = true
	if slide_col: slide_col.disabled = false
	if stand_hit: stand_hit.disabled = true
	if slide_hit: slide_hit.disabled = false

func _disable_slide_shapes() -> void:
	var stand_col = get_node_or_null("StandCollision")
	var slide_col = get_node_or_null("SlideCollision")
	var stand_hit = get_node_or_null("Hitbox/StandHitbox")
	var slide_hit = get_node_or_null("Hitbox/SlideHitbox")
	if slide_col: slide_col.disabled = true
	if stand_col: stand_col.disabled = false
	if slide_hit: slide_hit.disabled = true
	if stand_hit: stand_hit.disabled = false

# --- Animation ---
func _handle_animation() -> void:
	if is_stumbling:
		anim.play("stumble")
	elif is_sliding:
		anim.play("slide")
	elif not is_on_floor():
		anim.play("jump")
	elif current_speed > 10:
		anim.play("run")
	else:
		anim.play("idle")

# --- Collision ---
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurdles") and not is_stumbling:
		var is_sabotage := area.has_meta("sabotage")
		_trigger_stumble(is_sabotage)

func _trigger_stumble(is_sabotage: bool = false) -> void:
	if is_stumbling:
		return
	is_stumbling = true
	is_sliding = false
	_disable_slide_shapes()
	current_speed *= 0.15 if is_sabotage else 0.3
	GameState.apply_kei_penalty("ai", "SABOTAGE" if is_sabotage else "HIGH_HURDLE")
	await get_tree().create_timer(0.5).timeout
	is_stumbling = false
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.75).timeout
		hitbox.set_deferred("monitoring", true)
