# game_state.gd
# Autoload Singleton — Centralized data store for all game state.
# All inter-module communication passes through this node exclusively.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ─────────────────────────────────────────
#  ENUMS
# ─────────────────────────────────────────
enum RacePhase {
	PRE_MATCH,
	COUNTDOWN,
	RACING,
	FINISHED
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

# ─────────────────────────────────────────
#  RACE STATE
# ─────────────────────────────────────────
var race_phase        : RacePhase  = RacePhase.PRE_MATCH
var difficulty        : Difficulty = Difficulty.MEDIUM
var match_timer       : float      = 60.0   # written by main.gd each frame
var race_elapsed_time : float      = 0.0    # written by main.gd each frame
var winner            : String     = ""     # "player" | "ai" | "tie" (lowercase)
var win_reason        : String     = ""     # "finish_line" | "time_up"

# ─────────────────────────────────────────
#  SHARED RACER DATA
# ─────────────────────────────────────────
var player_kei      : float  = 0.50
var ai_kei          : float  = 0.50
var player_position : float  = 0.0
var ai_position     : float  = 0.0
var finish_line_x   : float  = 0.0
var player_action   : String = "NONE"
var ai_action       : String = "NONE"

# ─────────────────────────────────────────
#  COLLISION FLAGS
# ─────────────────────────────────────────
var player_collision_type : String = "NONE"
var ai_collision_type     : String = "NONE"
var player_in_dense_zone  : bool   = false
var ai_in_dense_zone      : bool   = false

# ─────────────────────────────────────────
#  STUMBLE STATE
# ─────────────────────────────────────────
var player_stumble_timer : float = 0.0
var ai_stumble_timer     : float = 0.0
const STUMBLE_DURATION   : float = 0.5

# ─────────────────────────────────────────
#  KEI CONSTANTS (Table 3)
# ─────────────────────────────────────────
const KEI_FLOOR           : float = 0.10
const KEI_CEILING         : float = 1.00
const KEI_GAIN_PER_PRESS  : float = 0.06
const KEI_DECAY_PASSIVE   : float = 0.008
const KEI_DECAY_CONSERVE  : float = 0.003
const KEI_DECAY_STUMBLE   : float = 0.015
const KEI_PENALTY_OBSTACLE: float = 0.50
const KEI_PENALTY_SABOTAGE: float = 0.75

# ─────────────────────────────────────────
#  DIFFICULTY PARAMETERS (Table 4)
# ─────────────────────────────────────────
const DIFF_PARAMS: Dictionary = {
	Difficulty.EASY:   { "astar_n": 2, "astar_w": 1.5, "reaction_ms": 250, "jitter_ms": 40, "minimax_depth": 2 },
	Difficulty.MEDIUM: { "astar_n": 3, "astar_w": 1.2, "reaction_ms": 150, "jitter_ms": 20, "minimax_depth": 3 },
	Difficulty.HARD:   { "astar_n": 5, "astar_w": 1.0, "reaction_ms":  80, "jitter_ms":  8, "minimax_depth": 4 }
}

# ─────────────────────────────────────────
#  SIGNALS
# ─────────────────────────────────────────
signal phase_changed(new_phase: RacePhase)
signal race_finished(winner_name: String)
signal collision_event(racer: String, obstacle_type: String)
signal sabotage_triggered(by_racer: String)
signal frame_committed
# FIX: Suppressed "declared but never explicitly used" analyser warning.
# match_timer_updated IS emitted externally by main.gd each frame via
# GameState.match_timer_updated.emit(time_left). Godot's static analyser
# does not follow cross-file emit calls and flags this as unused.
@warning_ignore("unused_signal")
signal match_timer_updated(time_left: float)
signal match_reset

# ─────────────────────────────────────────
#  TRACK TOTALS
#  Set once by ObstacleManager.gd immediately after the static obstacle
#  map finishes loading for the chosen difficulty. Both totals are shared
#  between racers because they run on the same track layout.
# ─────────────────────────────────────────
var total_hurdles : int = 0   # total High Hurdles on the current track
var total_slides  : int = 0   # total Low Obstacles on the current track

# ─────────────────────────────────────────
#  PLAYER PERFORMANCE STATS
#  Populated during the race by PlayerInput.gd, CollisionSystem.gd,
#  and PhysicsMomentum.gd. Read by ResultsScreen at match end.
# ─────────────────────────────────────────
var player_hurdles_dodged : int   = 0   # High Hurdles cleared without collision
var player_slides_done    : int   = 0   # Low Obstacles passed without collision
var player_collisions     : int   = 0   # total obstacle collision events
var player_sabotages_used : int   = 0   # sabotage triggers successfully activated
var player_best_streak    : int   = 0   # longest valid alternating sprint streak
var player_distance       : float = 0.0 # metres travelled (x-position, per frame)

# ─────────────────────────────────────────
#  AI PERFORMANCE STATS
#  Populated during the race by AIController.gd, CollisionSystem.gd,
#  MinimaxEvaluator.gd, and PhysicsMomentum.gd.
# ─────────────────────────────────────────
var ai_hurdles_dodged      : int   = 0   # High Hurdles cleared without collision
var ai_slides_done         : int   = 0   # Low Obstacles passed without collision
var ai_collisions          : int   = 0   # total obstacle collision events
var ai_sabotages_activated : int   = 0   # times Minimax returned ACTIVATE
var ai_distance            : float = 0.0 # metres travelled (x-position, per frame)
var ai_sabotage_hits       : int   = 0   # AI-spawned sabotages that hit the player
										 # (tag spawned hazards with is_ai_spawn = true
										 # and increment here on player collision)

# ─────────────────────────────────────────
#  ALGORITHM DECISION COUNTERS
#  Each variable maps directly to one algorithm in the AI decision stack.
#  Incremented inside the algorithm's own script so the counter is always
#  accurate regardless of which code path is taken.
#
#  ai_astar_plans        → AStarPlanner.gd,      first line of plan()
#  ai_idastar_fallbacks  → IDAStarPlanner.gd,    first line of plan()
#  ai_greedy_count       → AIController.gd,      after _greedy_evade() returns JUMP|SLIDE
#  ai_minimax_activations→ MinimaxEvaluator.gd,  first line of decide()
# ─────────────────────────────────────────
var ai_astar_plans         : int = 0
var ai_idastar_fallbacks   : int = 0
var ai_greedy_count        : int = 0
var ai_minimax_activations : int = 0

# ─────────────────────────────────────────
#  INITIALISATION
# ─────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ─────────────────────────────────────────
#  FRAME PROCESS
#  Timer countdown is owned by main.gd which writes match_timer and
#  race_elapsed_time directly. GameState only ticks stumble timers here.
# ─────────────────────────────────────────
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	frame_committed.emit()
	# FIX: Stumble timers were set by apply_kei_penalty() but never decremented,
	# causing is_player/ai_stumbling() to return true permanently after the
	# first collision. Ticked here so they drain correctly every frame.
	if player_stumble_timer > 0.0:
		player_stumble_timer = maxf(player_stumble_timer - delta, 0.0)
	if ai_stumble_timer > 0.0:
		ai_stumble_timer = maxf(ai_stumble_timer - delta, 0.0)

# ─────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────
func get_difficulty_param(key: String) -> Variant:
	return DIFF_PARAMS[difficulty][key]

func is_racing() -> bool:
	return race_phase == RacePhase.RACING

func is_player_stumbling() -> bool:
	return player_stumble_timer > 0.0

func is_ai_stumbling() -> bool:
	return ai_stumble_timer > 0.0

func set_phase(new_phase: RacePhase) -> void:
	race_phase = new_phase
	emit_signal("phase_changed", new_phase)
	if new_phase == RacePhase.FINISHED:
		emit_signal("race_finished", winner)

func apply_kei_penalty(racer: String, obstacle_type: String) -> void:
	var multiplier: float = KEI_PENALTY_SABOTAGE if obstacle_type == "SABOTAGE" \
							else KEI_PENALTY_OBSTACLE
	if racer == "player":
		player_kei           = maxf(player_kei * (1.0 - multiplier), KEI_FLOOR)
		player_stumble_timer = STUMBLE_DURATION
		player_collisions   += 1
	else:
		ai_kei           = maxf(ai_kei * (1.0 - multiplier), KEI_FLOOR)
		ai_stumble_timer = STUMBLE_DURATION
		ai_collisions   += 1
	emit_signal("collision_event", racer, obstacle_type)
	if obstacle_type == "SABOTAGE":
		emit_signal("sabotage_triggered", racer)

func clear_collision_flags() -> void:
	player_collision_type = "NONE"
	ai_collision_type     = "NONE"

# ─────────────────────────────────────────
#  RESET
# ─────────────────────────────────────────
func reset_match() -> void:
	# ── Race state ──────────────────────────────────────────────────────────
	race_phase            = RacePhase.PRE_MATCH
	match_timer           = 60.0
	race_elapsed_time     = 0.0
	winner                = ""
	win_reason            = ""

	# ── Racer data ──────────────────────────────────────────────────────────
	player_kei            = 0.50
	ai_kei                = 0.50
	player_position       = 0.0
	ai_position           = 0.0
	finish_line_x         = 0.0
	player_action         = "NONE"
	ai_action             = "NONE"

	# ── Collision and stumble state ─────────────────────────────────────────
	player_stumble_timer  = 0.0
	ai_stumble_timer      = 0.0
	player_collision_type = "NONE"
	ai_collision_type     = "NONE"
	player_in_dense_zone  = false
	ai_in_dense_zone      = false

	# ── Track totals ────────────────────────────────────────────────────────
	total_hurdles = 0
	total_slides  = 0

	# ── Player performance stats ────────────────────────────────────────────
	player_hurdles_dodged = 0
	player_slides_done    = 0
	player_collisions     = 0
	player_sabotages_used = 0
	player_best_streak    = 0
	player_distance       = 0.0

	# ── AI performance stats ────────────────────────────────────────────────
	ai_hurdles_dodged      = 0
	ai_slides_done         = 0
	ai_collisions          = 0
	ai_sabotages_activated = 0
	ai_distance            = 0.0
	ai_sabotage_hits       = 0

	# ── Algorithm decision counters ─────────────────────────────────────────
	ai_astar_plans         = 0
	ai_idastar_fallbacks   = 0
	ai_greedy_count        = 0
	ai_minimax_activations = 0

	match_reset.emit()

func reset() -> void:
	reset_match()
