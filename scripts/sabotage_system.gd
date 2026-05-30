# sabotage_system.gd
#
# One instance lives in EACH racing lane:
#   PlayerLane  (game_world.tscn)  → hazards that hit the PLAYER
#   AILane      (ai_world.tscn)    → hazards that hit the AI
#
# Visual effects (earth spike / fire ball) now live in dedicated scenes:
#   scenes/EarthSpikeEffect.tscn   → open to edit the spike visuals
#   scenes/FireBallEffect.tscn     → open to edit the fireball visuals

extends Node2D

const SPIKE_SCENE        = preload("res://scenes/SpikeHurdle.tscn")
const SAW_SCENE          = preload("res://scenes/SawHurdle.tscn")
const EARTH_SPIKE_EFFECT = preload("res://scenes/EarthSpikeEffect.tscn")
const FIRE_BALL_EFFECT   = preload("res://scenes/FireBallEffect.tscn")

const FALLBACK_GOAL_X: float = 12613.0
const HAZARD_LAYER:    int   = 7   # bits 1+2+3 — detected by player (mask 1) AND AI (mask 2 / raycast 6)

# ── Lane & Spawn Settings ─────────────────────────────────────────────────────
@export_group("Lane & Spawn")
## "player" or "ai". Auto-detected from ancestor lane node name if left blank.
@export var lane_id: String = ""
## How far ahead of the target racer to spawn the hazard (px).
@export var spawn_lead: float = 400.0
## Auto-despawn the hazard after this many seconds.
@export var hazard_lifetime: float = 10.0
## A gap between existing hurdles must be at least this wide to be usable.
@export var min_gap_size: float = 400.0
## Clear buffer required on EACH side of the chosen spawn point.
@export var spawn_margin: float = 200.0
## Never spawn within this many px of the finish line.
@export var finish_margin: float = 400.0

func _ready() -> void:
	if lane_id == "":
		lane_id = _detect_lane_id()
	add_to_group("sabotage_system")
	add_to_group("sabotage_system_" + lane_id)
	print("[Sabotage] Ready — lane: '%s'" % lane_id)

func _detect_lane_id() -> String:
	var n: Node = self
	while n != null:
		if String(n.name) == "PlayerLane": return "player"
		if String(n.name) == "AILane":     return "ai"
		n = n.get_parent()
	return "player"

func _victim_position() -> float:
	return GameState.ai_position if lane_id == "ai" else GameState.player_position

# ── Public API ────────────────────────────────────────────────────────────────

## Spawn one hazard ahead of this lane's racer.
## attacker — informational only ("player" or "ai"); drives the audio cue.
func trigger(attacker: String = "") -> void:
	var hurdle_type := randi() % 2   # 0 = SpikeHurdle (JUMP), 1 = SawHurdle (SLIDE)
	var scene       := SPIKE_SCENE if hurdle_type == 0 else SAW_SCENE

	var spawn_x := _find_best_spawn_x()
	if spawn_x < 0.0:
		print("[Sabotage:%s] No safe slot — skipped." % lane_id)
		return
	var spawn_y := _get_y_for_type(hurdle_type)

	var hazard := scene.instantiate()
	get_parent().add_child(hazard)
	hazard.global_position = Vector2(spawn_x, spawn_y)
	hazard.add_to_group("hurdles")
	hazard.collision_layer = HAZARD_LAYER
	hazard.set_meta("sabotage", true)

	# Attach the visual effect scene (EarthSpikeEffect or FireBallEffect).
	# All visual properties (scale, modulate, speed_scale, offset) are
	# edited directly inside those scenes — open them in Godot to adjust.
	var effect_scene := EARTH_SPIKE_EFFECT if hurdle_type == 0 else FIRE_BALL_EFFECT
	var effect := effect_scene.instantiate()
	hazard.add_child(effect)
	effect.apply_to_hazard(hazard)

	GameState.sabotage_triggered.emit(attacker if attacker != "" else "ai")
	print("[Sabotage:%s] Spawned %s at X=%.0f (attacker=%s)" % [
		lane_id,
		"Spike(JUMP)" if hurdle_type == 0 else "Saw(SLIDE)",
		spawn_x, attacker])

	await get_tree().create_timer(hazard_lifetime).timeout
	if is_instance_valid(hazard):
		hazard.queue_free()

# ── Spawn placement ───────────────────────────────────────────────────────────

func _goal_x() -> float:
	var lane := get_parent()
	if lane:
		var goal := lane.get_node_or_null("Goal")
		if goal and goal is Node2D:
			return (goal as Node2D).global_position.x
	return FALLBACK_GOAL_X

func _get_y_for_type(hurdle_type: int) -> float:
	var want := "Spike" if hurdle_type == 0 else "Saw"
	var lane := get_parent()
	for node in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and lane.is_ancestor_of(node) and String(node.name).begins_with(want):
			return node.global_position.y
	for node in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and lane.is_ancestor_of(node):
			return node.global_position.y
	return 390.0 if hurdle_type == 0 else 265.0

func _find_best_spawn_x() -> float:
	var lane      := get_parent()
	var racer_x   := _victim_position()
	var finish_x  := _goal_x() - finish_margin
	var natural_x := racer_x + spawn_lead

	var xs: Array = []
	for h in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and lane.is_ancestor_of(h):
			var hx: float = h.global_position.x
			if hx > racer_x:
				xs.append(hx)
	xs.sort()

	var walls: Array = [racer_x]
	for x in xs:
		walls.append(x)
	walls.append(finish_x)

	var best_x    := -1.0
	var best_dist := INF
	for i in range(walls.size() - 1):
		var a: float = walls[i]
		var b: float = walls[i + 1]
		if b - a < min_gap_size:
			continue
		var place_x := maxf(a + spawn_margin, natural_x)
		if place_x > b - spawn_margin:
			continue
		var dist: float = absf(place_x - natural_x)
		if dist < best_dist:
			best_dist = dist
			best_x = place_x
	return best_x
