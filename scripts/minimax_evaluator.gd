class_name MinimaxEvaluator

# Depth limit scales with difficulty (GDD Table 4)
var depth_limit: int = 3

func setup(difficulty: int) -> void:
	match difficulty:
		0: depth_limit = 2  # Easy
		1: depth_limit = 3  # Medium
		2: depth_limit = 4  # Hard

# --- Main decision function ---
# Returns "ACTIVATE" or "PASS"
func decide(ai_kei: float, player_kei: float, player_in_dense: bool) -> String:
	var state = {
		"ai_kei": ai_kei,
		"player_kei": player_kei,
		"player_in_dense": player_in_dense
	}
	var result = _max_value(state, -INF, INF, 0)
	return result[1]

# --- MAX node: AI chooses ACTIVATE or PASS ---
func _max_value(state: Dictionary, alpha: float, beta: float, depth: int) -> Array:
	if depth >= depth_limit:
		return [_eval(state), "PASS"]

	var v = -INF
	var best_move = "PASS"

	for action in ["ACTIVATE", "PASS"]:
		var ns = _apply_action(state, action)
		var result = _min_value(ns, alpha, beta, depth + 1)
		if result[0] > v:
			v = result[0]
			best_move = action
		alpha = max(alpha, v)
		if v >= beta:  # Beta cutoff — prune remaining
			return [v, best_move]

	return [v, best_move]

# --- MIN node: Player responds with SPRINT_THROUGH, CONSERVE, or EVADE ---
func _min_value(state: Dictionary, alpha: float, beta: float, depth: int) -> Array:
	if depth >= depth_limit:
		return [_eval(state), "SPRINT_THROUGH"]

	var v = INF
	var best_move = "SPRINT_THROUGH"

	for action in ["SPRINT_THROUGH", "CONSERVE", "EVADE"]:
		var ns = _apply_action(state, action)
		var result = _max_value(ns, alpha, beta, depth + 1)
		if result[0] < v:
			v = result[0]
			best_move = action
		beta = min(beta, v)
		if v <= alpha:  # Alpha cutoff — prune remaining
			return [v, best_move]

	return [v, best_move]

# --- Weighted linear evaluation function (GDD Section IV.C) ---
# EVAL = CLAMP( 0.40*kei_adv + 0.35*vuln + dense, -1.0, +1.0 )
func _eval(state: Dictionary) -> float:
	var kei_adv = state["ai_kei"] - state["player_kei"]
	var vuln = state["player_kei"]
	var dense = 0.30 if state["player_in_dense"] else 0.0
	return clamp((0.40 * kei_adv) + (0.35 * vuln) + dense, -1.0, 1.0)

# --- Simulate outcome of each action ---
func _apply_action(state: Dictionary, action: String) -> Dictionary:
	var ns = state.duplicate()
	match action:
		"ACTIVATE":
			# Sabotage costs AI a little KEI, hurts player a lot
			ns["ai_kei"] = max(0.1, state["ai_kei"] - 0.04)
			ns["player_kei"] = max(0.1, state["player_kei"] * 0.25)
		"PASS":
			pass
		"SPRINT_THROUGH":
			# Player gets hit — big KEI loss
			ns["player_kei"] = max(0.1, state["player_kei"] * 0.50)
		"CONSERVE":
			# Player slows down to prepare — moderate KEI loss
			ns["player_kei"] = max(0.1, state["player_kei"] * 0.80)
		"EVADE":
			# Player dodges perfectly — no KEI loss
			pass
	return ns
