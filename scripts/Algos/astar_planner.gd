class_name AStarPlanner

# --- Action Constants ---
const SPRINT_AGGRESSIVE = "SPRINT_AGGRESSIVE"
const SPRINT_STEADY = "SPRINT_STEADY"
const CONSERVE = "CONSERVE"
const JUMP = "JUMP"
const SLIDE = "SLIDE"

# --- KEI costs per action (from GDD Table 6) ---
const ACTION_COSTS = {
	"SPRINT_AGGRESSIVE": 0.06,
	"SPRINT_STEADY": 0.03,
	"CONSERVE": 0.00,
	"JUMP": 0.04,
	"SLIDE": 0.03
}

# --- Difficulty parameters ---
var lookahead_n: int = 3
var heuristic_weight: float = 1.2

func setup(difficulty: int) -> void:
	match difficulty:
		0: # EASY — shallow lookahead, suboptimal heuristic
			lookahead_n = 2
			heuristic_weight = 1.5
		1: # MEDIUM
			lookahead_n = 3
			heuristic_weight = 1.2
		2: # HARD — full lookahead, cost-optimal A*
			lookahead_n = 5
			heuristic_weight = 1.0

# --- Main planning function ---
# Returns the best first action to take given current state and obstacle window
func plan(ai_kei: float, window: Array) -> String:
	if window.is_empty():
		return SPRINT_AGGRESSIVE if ai_kei > 0.5 else SPRINT_STEADY

	var start = {
		"kei": ai_kei,
		"obs_idx": 0,
		"g": 0.0,
		"actions": []
	}
	start["h"] = _heuristic(start, window)
	start["f"] = start["g"] + heuristic_weight * start["h"]

	var frontier = [start]
	var reached = {}
	var iterations = 0

	while frontier.size() > 0 and iterations < 300:
		iterations += 1

		# Always expand lowest f node
		frontier.sort_custom(func(a, b): return a["f"] < b["f"])
		var node = frontier.pop_front()

		# Goal reached — return first action in sequence
		if _is_goal(node, window):
			if node["actions"].size() > 0:
				return node["actions"][0]
			return SPRINT_STEADY

		# Skip if already found better path to this state
		var key = str(node["obs_idx"]) + "_" + str(snapped(node["kei"], 0.05))
		if reached.has(key) and reached[key] <= node["g"]:
			continue
		reached[key] = node["g"]

		# Expand all valid actions
		for action in _get_actions(node, window):
			var ns = _apply_action(node, action, window)
			var g2 = node["g"] + ACTION_COSTS[action]
			var h2 = _heuristic(ns, window)
			ns["g"] = g2
			ns["h"] = h2
			ns["f"] = g2 + heuristic_weight * h2
			ns["actions"] = node["actions"] + [action]
			frontier.append(ns)

	# Fallback if no solution found
	return SPRINT_STEADY

# --- Admissible heuristic H(n) ---
# Sum of minimum evasion costs for remaining obstacles
# Never overestimates — guarantees cost-optimality (GDD Section IV.A)
func _heuristic(state: Dictionary, window: Array) -> float:
	var cost = 0.0
	for i in range(state["obs_idx"], window.size()):
		cost += 0.04 if window[i]["type"] == 0 else 0.03
	return cost

func _is_goal(state: Dictionary, window: Array) -> bool:
	return state["obs_idx"] >= window.size()

func _get_actions(state: Dictionary, window: Array) -> Array:
	if state["obs_idx"] >= window.size():
		return [SPRINT_AGGRESSIVE] if state["kei"] > 0.5 else [SPRINT_STEADY]
	var obs = window[state["obs_idx"]]
	if obs["type"] == 0: # HIGH hurdle — must jump
		return [JUMP, SPRINT_STEADY, CONSERVE]
	else: # LOW obstacle — must slide
		return [SLIDE, SPRINT_STEADY, CONSERVE]

func _apply_action(state: Dictionary, action: String, window: Array) -> Dictionary:
	var ns = state.duplicate()
	ns["kei"] = max(0.1, state["kei"] - ACTION_COSTS[action])

	# If action correctly handles the next obstacle, advance window index
	if state["obs_idx"] < window.size():
		var obs = window[state["obs_idx"]]
		if (action == JUMP and obs["type"] == 0) or \
		   (action == SLIDE and obs["type"] == 1):
			ns["obs_idx"] = state["obs_idx"] + 1

	return ns
