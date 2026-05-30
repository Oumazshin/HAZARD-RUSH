# idastar_planner.gd
# res://scripts/idastar_planner.gd
#
# IDA* (Iterative-Deepening A*) — Memory-Bounded Fallback Planner
# Activated when: Easy difficulty (N=2) OR A* returns FAILURE
#
# Identical output contract to AStarPlanner.plan() — returns a String action.
# Uses O(N) stack memory instead of O(b^N) frontier hash table.
# Reference: Russell & Norvig (2021) p.111, GDD Section IV.B

class_name IDAStarPlanner

# Same action costs as AStarPlanner (GDD Table 6)
const ACTION_COSTS: Dictionary = {
	"SPRINT_AGGRESSIVE": 0.06,
	"SPRINT_STEADY":     0.03,
	"CONSERVE":          0.00,
	"JUMP":              0.04,
	"SLIDE":             0.03
}

var lookahead_n: int = 3

func setup(difficulty: int) -> void:
	match difficulty:
		0: lookahead_n = 2  # Easy
		1: lookahead_n = 3  # Medium
		2: lookahead_n = 5  # Hard

# ── Public API — same signature as AStarPlanner.plan() ───────────────────────
func plan(ai_kei: float, window: Array) -> String:
	if window.is_empty():
		return "SPRINT_AGGRESSIVE" if ai_kei > 0.5 else "SPRINT_STEADY"

	var start := {"kei": ai_kei, "obs_idx": 0}

	# First threshold = h-value of the start node (GDD pseudocode)
	var cutoff: float = _heuristic(start, window)

	# Iterative deepening loop — raise threshold each pass
	for _pass in range(20):  # safety cap
		var result := _dls(start, [], 0.0, cutoff, window)

		if result[0] != null:
			# Solution found — return first action in the sequence
			var seq: Array = result[0]
			return seq[0] if seq.size() > 0 else "SPRINT_STEADY"

		var new_cutoff: float = result[1]
		if new_cutoff == INF:
			break  # No solution exists in this space
		cutoff = new_cutoff

	return "SPRINT_STEADY"  # Final fallback

# ── DLS — Depth-Limited Search bounded by f-cost threshold ───────────────────
# Returns [action_sequence_or_null, min_f_that_exceeded_cutoff]
func _dls(state: Dictionary, actions: Array, g: float,
		  cutoff: float, window: Array) -> Array:

	var f := g + _heuristic(state, window)

	if f > cutoff:
		return [null, f]  # Over threshold — report f for next cutoff

	if _is_goal(state, window):
		return [actions, f]  # Solution found

	var min_t: float = INF

	for action in _get_actions(state, window):
		var ns     := _apply_action(state, action, window)
		var g2: float = g + ACTION_COSTS[action]
		var result := _dls(ns, actions + [action], g2, cutoff, window)

		if result[0] != null:
			return result  # Propagate solution up

		if result[1] < min_t:
			min_t = result[1]

	return [null, min_t]

# ── Helpers — identical to AStarPlanner for consistent output ─────────────────
func _heuristic(state: Dictionary, window: Array) -> float:
	var cost := 0.0
	for i in range(state["obs_idx"], window.size()):
		cost += 0.04 if window[i]["type"] == 0 else 0.03
	return cost

func _is_goal(state: Dictionary, window: Array) -> bool:
	return state["obs_idx"] >= window.size()

func _get_actions(state: Dictionary, window: Array) -> Array:
	if state["obs_idx"] >= window.size():
		return ["SPRINT_AGGRESSIVE"] if state["kei"] > 0.5 else ["SPRINT_STEADY"]
	var obs: Dictionary = window[state["obs_idx"]]
	return ["JUMP", "SPRINT_STEADY", "CONSERVE"] if obs["type"] == 0 \
		else ["SLIDE", "SPRINT_STEADY", "CONSERVE"]

func _apply_action(state: Dictionary, action: String, window: Array) -> Dictionary:
	var ns := state.duplicate()
	ns["kei"] = max(0.1, state["kei"] - ACTION_COSTS[action])
	if state["obs_idx"] < window.size():
		var obs: Dictionary = window[state["obs_idx"]]
		if (action == "JUMP"  and obs["type"] == 0) or \
		   (action == "SLIDE" and obs["type"] == 1):
			ns["obs_idx"] = state["obs_idx"] + 1
	return ns
