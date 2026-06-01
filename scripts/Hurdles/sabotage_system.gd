# sabotage_system.gd
# ─────────────────────────────────────────────────────────────────────────────
# One instance lives in EACH racing lane:
#   PlayerLane  (game_world.tscn)  → hazards that hit the PLAYER
#   AILane      (ai_world.tscn)    → hazards that hit the AI
#
# ── What this revision adds (Audit fix A-1) ──────────────────────────────────
# signal trigger_window_active
#   Emitted periodically by the PLAYER-lane system when:
#     • The race is active (RACING phase)
#     • The start-of-race lockout has expired
#     • The window check interval has elapsed
#   opponent_ai.gd connects to this signal on the sabotage_system_player group
#   and runs Minimax.decide() each time it fires — no more periodic timer in AI.
#
# ── Previous fixes (unchanged) ───────────────────────────────────────────────
# FIX (earth spike): only EarthSpikeEffect.tscn spawned — no SpikeHurdle dupe.
# FIX (fireball Y):  _get_y_for_type(1 if is_high else 0) — HIGH → Saw Y.
# FIX (warning Y):   warn_y derived from spawn_y, not a swapped separate calc.
# FIX (WarningNode): replaced by WarningIndicator.tscn + spritesheet.
# ─────────────────────────────────────────────────────────────────────────────

extends Node2D

# ── Preloads ──────────────────────────────────────────────────────────────────
# SPIKE_SCENE removed — EarthSpikeEffect is the single earth-spike spawn.
const EARTH_SPIKE_EFFECT  = preload("res://scenes/Hurdles/EarthSpikeEffect.tscn")
const FIREBALL_PROJECTILE = preload("res://scenes/Hurdles/FireballProjectile.tscn")
const WARNING_INDICATOR   = preload("res://scenes/Hurdles/WarningIndicator.tscn")

# ── NEW: Trigger zone signal ──────────────────────────────────────────────────
## Emitted every TRIGGER_ZONE_INTERVAL seconds when the race is live and
## the sabotage lockout has expired.  opponent_ai.gd connects to this on the
## sabotage_system_player instance so Minimax runs only at valid windows.
signal trigger_window_active

## How often (seconds) to emit trigger_window_active.
## Matches the design spec: sabotage windows are periodic opportunities,
## not continuous — Minimax adds zero overhead outside these moments.
const TRIGGER_ZONE_INTERVAL : float = 3.0

# ── Warning spritesheet config ────────────────────────────────────────────────
# Set WARN_FRAME_COUNT to 0 to auto-detect from texture dimensions.
const WARN_FRAME_COUNT : int      = 0
const WARN_FRAME_SIZE  : Vector2i = Vector2i(64, 64)

const FALLBACK_GOAL_X : float = 12613.0
const HAZARD_LAYER    : int   = 7

# ── Exports ───────────────────────────────────────────────────────────────────
@export_group("Lane & Spawn")
@export var lane_id:         String = ""
@export var spawn_lead:      float  = 400.0
@export var hazard_lifetime: float  = 12.0
@export var min_gap_size:    float  = 400.0
@export var spawn_margin:    float  = 200.0
@export var finish_margin:   float  = 400.0

@export_group("Timing")
@export var lockout_duration: float = 5.0
@export var warn_duration:    float = 1.2

@export_group("Fireball")
@export var fireball_screen_edge_offset: float = 960.0

# ── Runtime state ─────────────────────────────────────────────────────────────
var _race_started         : bool  = false
var _race_lockout         : float = 0.0
var _extra_charges        : int   = 0
var _trigger_zone_timer   : float = 0.0   # counts up toward TRIGGER_ZONE_INTERVAL

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if lane_id == "":
		lane_id = _detect_lane_id()
	add_to_group("sabotage_system")
	add_to_group("sabotage_system_" + lane_id)
	print("[Sabotage] Ready — lane: '%s'" % lane_id)

func _physics_process(delta: float) -> void:
	match GameState.race_phase:
		GameState.RacePhase.RACING:
			if not _race_started:
				_race_started       = true
				_race_lockout       = lockout_duration
				_trigger_zone_timer = 0.0
				print("[Sabotage:%s] Race started — locked out for %.1fs" % [lane_id, lockout_duration])
			elif _race_lockout > 0.0:
				_race_lockout = max(0.0, _race_lockout - delta)
			else:
				# ── Emit trigger window signal (audit fix A-1) ─────────────
				# Only the PLAYER-lane system emits this; opponent_ai.gd
				# listens here to know when to run its Minimax evaluator.
				_trigger_zone_timer += delta
				if _trigger_zone_timer >= TRIGGER_ZONE_INTERVAL:
					_trigger_zone_timer = 0.0
					emit_signal("trigger_window_active")

		GameState.RacePhase.PRE_MATCH, GameState.RacePhase.COUNTDOWN:
			_race_started       = false
			_race_lockout       = 0.0
			_trigger_zone_timer = 0.0

# ── Public API ────────────────────────────────────────────────────────────────

func is_locked_out() -> bool:
	return _race_lockout > 0.0

func get_lockout_remaining() -> float:
	return _race_lockout

func get_charges() -> int:
	return _extra_charges

func add_charge(n: int = 1) -> void:
	_extra_charges += n
	print("[Sabotage:%s] +%d charge(s). Total: %d" % [lane_id, n, _extra_charges])

func consume_charge() -> bool:
	if _extra_charges <= 0: return false
	_extra_charges -= 1
	return true

# ── Main trigger flow ─────────────────────────────────────────────────────────

func trigger(attacker: String = "") -> void:
	if not GameState.is_racing():
		return
	if _race_lockout > 0.0:
		print("[Sabotage:%s] Locked out (%.1fs left)." % [lane_id, _race_lockout])
		return

	# 0 = Earth Spike  (player must JUMP — spawns at Spike / ground Y)
	# 1 = Fireball     (is_high=true  → player must SLIDE, at Saw / elevated Y)
	#                  (is_high=false → player must JUMP,  at Spike / ground Y)
	var hurdle_type := randi() % 2
	var is_high     := randi() % 2 == 0

	# ── Determine spawn Y ─────────────────────────────────────────────────────
	var spawn_y: float
	if hurdle_type == 0:
		spawn_y = _get_y_for_type(0)                   # Earth Spike → ground Y
	else:
		spawn_y = _get_y_for_type(1 if is_high else 0) # Fireball: high→Saw Y, low→Spike Y

	# ── Warning indicator ─────────────────────────────────────────────────────
	var warn_x := _victim_position() \
		+ (spawn_lead if hurdle_type == 0 else fireball_screen_edge_offset)
	var warn_y := spawn_y - 60.0   # 60 px above the hazard spawn point

	var warning := WARNING_INDICATOR.instantiate()
	get_parent().add_child(warning)
	warning.global_position = Vector2(warn_x, warn_y)
	warning.setup(WARN_FRAME_COUNT, WARN_FRAME_SIZE)

	GameState.sabotage_triggered.emit(attacker if attacker != "" else "ai")
	print("[Sabotage:%s] ⚠ Warning — %s incoming at Y=%.0f" % [
		lane_id,
		"EarthSpike" if hurdle_type == 0 else ("Fireball-HIGH" if is_high else "Fireball-LOW"),
		spawn_y
	])

	await get_tree().create_timer(warn_duration).timeout
	if is_instance_valid(warning):
		warning.queue_free()

	if not GameState.is_racing():
		return

	# ── Spawn hazard ──────────────────────────────────────────────────────────
	var hazard_node: Node = null

	if hurdle_type == 0:
		# Earth Spike: ONE spawn — EarthSpikeEffect handles both visual AND collision.
		var sx := _find_best_spawn_x()
		if sx < 0.0:
			print("[Sabotage:%s] No safe spawn slot — skipped." % lane_id)
			return
		hazard_node = _spawn_earth_spike(Vector2(sx, spawn_y))
	else:
		# Fireball: spawns at right of screen, moves left.
		var sx := _victim_position() + fireball_screen_edge_offset
		# FIXED: Pass the !is_high flag to _spawn_fireball so it knows to bottom-anchor
		hazard_node = _spawn_fireball(Vector2(sx, spawn_y), not is_high)

	if hazard_node == null:
		return

	print("[Sabotage:%s] ✓ Spawned %s at (%.0f, %.0f)" % [
		lane_id,
		"EarthSpike" if hurdle_type == 0 else ("Fireball-HIGH" if is_high else "Fireball-LOW"),
		hazard_node.global_position.x,
		hazard_node.global_position.y
	])

	await get_tree().create_timer(hazard_lifetime).timeout
	if is_instance_valid(hazard_node):
		hazard_node.queue_free()

# ── Spawn helpers ─────────────────────────────────────────────────────────────

## Spawns ONE EarthSpikeEffect — it owns BOTH animation AND collision.
## SpikeHurdle.tscn is NOT spawned alongside it.
func _spawn_earth_spike(spawn_pos: Vector2) -> Node:
	var hazard := EARTH_SPIKE_EFFECT.instantiate()
	get_parent().add_child(hazard)
	hazard.global_position = spawn_pos
	hazard.add_to_group("hurdles")
	hazard.set_meta("sabotage", true)
	return hazard

## Spawns a fireball projectile that moves left at MOVE_SPEED px/s.
func _spawn_fireball(spawn_pos: Vector2, is_low: bool) -> Node:
	var projectile := FIREBALL_PROJECTILE.instantiate()
	# FIXED: Set the flag BEFORE it is added to the scene tree
	projectile.is_low_spawn = is_low 
	get_parent().add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.set_meta("sabotage", true)
	return projectile

# ── Lane / geometry helpers ───────────────────────────────────────────────────

func _detect_lane_id() -> String:
	var n: Node = self
	while n != null:
		if String(n.name) == "PlayerLane": return "player"
		if String(n.name) == "AILane":     return "ai"
		n = n.get_parent()
	return "player"

func _victim_position() -> float:
	return GameState.ai_position if lane_id == "ai" else GameState.player_position

func _goal_x() -> float:
	var lane := get_parent()
	if lane:
		var goal := lane.get_node_or_null("Goal")
		if goal and goal is Node2D:
			return (goal as Node2D).global_position.x
	return FALLBACK_GOAL_X

## Returns world Y of the nearest SpikeHurdle (type 0) or SawHurdle (type 1)
## in this lane. Sabotage spawns are excluded (names don't start with Spike/Saw).
func _get_y_for_type(hurdle_type: int) -> float:
	var want := "Spike" if hurdle_type == 0 else "Saw"
	var lane  := get_parent()
	for node in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and lane.is_ancestor_of(node) \
		and String(node.name).begins_with(want):
			return node.global_position.y
	# Second pass — any hurdle in this lane (fallback if no named match)
	for node in get_tree().get_nodes_in_group("hurdles"):
		if lane != null and lane.is_ancestor_of(node):
			return node.global_position.y
	return 390.0 if hurdle_type == 0 else 265.0   # absolute Y fallbacks

## Finds the best X gap for an earth spike between existing hurdles.
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
		if b - a < min_gap_size: continue
		var place_x := maxf(a + spawn_margin, natural_x)
		if place_x > b - spawn_margin: continue
		var dist: float = absf(place_x - natural_x)
		if dist < best_dist:
			best_dist = dist
			best_x    = place_x
	return best_x
