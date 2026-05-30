extends Node

# ─────────────────────────────────────────
#  ENUMS
# ─────────────────────────────────────────
enum RacePhase {
	PRE_MATCH,    # Phase 1: map loaded, KEI = 0.50, awaiting countdown
	COUNTDOWN,    # Phase 2: inputs accepted, no movement, launch KEI builds
	RACING,       # Phase 3 & 4: core loop active
	FINISHED      # Phase 5: result screen
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

# ─────────────────────────────────────────
#  RACE STATE
# ─────────────────────────────────────────
var race_phase: RacePhase = RacePhase.PRE_MATCH
var difficulty: Difficulty = Difficulty.MEDIUM
var match_timer: float = 60.0       # counts DOWN from 60s
var winner: String = ""             # "player", "ai", or "tie"
var win_reason: String = ""         # "finish_line", "time_up", "kei_tiebreak"

# ─────────────────────────────────────────
#  SHARED RACER DATA
# ─────────────────────────────────────────
var player_kei: float = 0.50        # normalized [0.10, 1.00]
var ai_kei: float = 0.50
var player_position: float = 0.0   # track distance in meters [0, 110]
var ai_position: float = 0.0
var player_action: String = "NONE"  # last committed action this frame
var ai_action: String = "NONE"

# ─────────────────────────────────────────
#  COLLISION FLAGS (cleared each frame by Physics module)
# ─────────────────────────────────────────
var player_collision_type: String = "NONE"  # "HIGH_HURDLE", "LOW_OBSTACLE", "SABOTAGE", "NONE"
var ai_collision_type: String = "NONE"
var player_in_dense_zone: bool = false
var ai_in_dense_zone: bool = false

# ─────────────────────────────────────────
#  STUMBLE STATE
# ─────────────────────────────────────────
var player_stumble_timer: float = 0.0
var ai_stumble_timer: float = 0.0
const STUMBLE_DURATION: float = 0.5

# ─────────────────────────────────────────
#  KEI CONSTANTS (Table 3)
# ─────────────────────────────────────────
const KEI_FLOOR: float = 0.10
const KEI_CEILING: float = 1.00
const KEI_GAIN_PER_PRESS: float = 0.06
const KEI_DECAY_PASSIVE: float = 0.008
const KEI_DECAY_CONSERVE: float = 0.003
const KEI_DECAY_STUMBLE: float = 0.015
const KEI_PENALTY_OBSTACLE: float = 0.50   # 50% of current KEI
const KEI_PENALTY_SABOTAGE: float = 0.75   # 75% of current KEI

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
signal frame_committed  # broadcast at end of each frame update

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
	# This is what actually broadcasts the win to the rest of the game
	if new_phase == RacePhase.FINISHED:
		emit_signal("race_finished", winner)

func apply_kei_penalty(racer: String, obstacle_type: String) -> void:
	var multiplier: float = KEI_PENALTY_SABOTAGE if obstacle_type == "SABOTAGE" \
							else KEI_PENALTY_OBSTACLE
	if racer == "player":
		player_kei = maxf(player_kei * (1.0 - multiplier), KEI_FLOOR)
		player_stumble_timer = STUMBLE_DURATION
	else:
		ai_kei = maxf(ai_kei * (1.0 - multiplier), KEI_FLOOR)
		ai_stumble_timer = STUMBLE_DURATION
	emit_signal("collision_event", racer, obstacle_type)

func clear_collision_flags() -> void:
	player_collision_type = "NONE"
	ai_collision_type = "NONE"

func reset() -> void:
	race_phase = RacePhase.PRE_MATCH
	match_timer = 60.0
	winner = ""
	win_reason = ""
	player_kei = 0.50
	ai_kei = 0.50
	player_position = 0.0
	ai_position = 0.0
	player_action = "NONE"
	ai_action = "NONE"
	player_stumble_timer = 0.0
	ai_stumble_timer = 0.0
	clear_collision_flags()
