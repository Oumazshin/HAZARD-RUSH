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
var match_timer       : float      = 60.0
var race_elapsed_time : float      = 0.0
var winner            : String     = ""     # "player" | "ai" | "tie"  (always lowercase)
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
signal match_timer_updated(time_left: float)
signal match_reset

# ─────────────────────────────────────────
#  INITIALISATION
#  Autoloads are children of the root node which has PROCESS_MODE_ALWAYS,
#  so _process() fires even when get_tree().paused = true.
#  The guard below suppresses game-logic ticks during a pause.
# ─────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # explicit — never inherited away

# ─────────────────────────────────────────
#  FRAME PROCESS
# ─────────────────────────────────────────
func _process(delta: float) -> void:
	if get_tree().paused:
		return

	frame_committed.emit()

	if race_phase == RacePhase.RACING:
		# ── Match countdown ───────────────────────────────────────────────
		match_timer       -= delta
		race_elapsed_time += delta
		match_timer_updated.emit(maxf(match_timer, 0.0))
		if match_timer <= 0.0:
			match_timer = 0.0
			_resolve_time_up()

	# ── Stumble timers ────────────────────────────────────────────────────
	# BUG FIX: These were set by apply_kei_penalty() but never decremented,
	# causing is_player_stumbling() / is_ai_stumbling() to return true
	# permanently after the first collision within a match.
	# Ticked outside the RACING guard so they drain correctly even near
	# phase transitions (e.g. collision fires on the finish-line frame).
	if player_stumble_timer > 0.0:
		player_stumble_timer = maxf(player_stumble_timer - delta, 0.0)
	if ai_stumble_timer > 0.0:
		ai_stumble_timer = maxf(ai_stumble_timer - delta, 0.0)

# ─────────────────────────────────────────
#  MATCH RESOLUTION — Time-Up
# ─────────────────────────────────────────
func _resolve_time_up() -> void:
	if player_kei > ai_kei:
		winner = "player"
	elif ai_kei > player_kei:
		winner = "ai"
	else:
		if player_position > ai_position:
			winner = "player"
		elif ai_position > player_position:
			winner = "ai"
		else:
			winner = "tie"
	win_reason = "time_up"
	set_phase(RacePhase.FINISHED)

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
	else:
		ai_kei           = maxf(ai_kei * (1.0 - multiplier), KEI_FLOOR)
		ai_stumble_timer = STUMBLE_DURATION
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
	race_phase            = RacePhase.PRE_MATCH
	match_timer           = 60.0
	race_elapsed_time     = 0.0
	winner                = ""
	win_reason            = ""
	player_kei            = 0.50
	ai_kei                = 0.50
	player_position       = 0.0
	ai_position           = 0.0
	finish_line_x         = 0.0
	player_action         = "NONE"
	ai_action             = "NONE"
	player_stumble_timer  = 0.0
	ai_stumble_timer      = 0.0
	player_collision_type = "NONE"
	ai_collision_type     = "NONE"
	player_in_dense_zone  = false
	ai_in_dense_zone      = false
	match_reset.emit()

func reset() -> void:
	reset_match()
