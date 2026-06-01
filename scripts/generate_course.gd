# generate_course.gd
# ─────────────────────────────────────────────────────────────────────────────
# EditorScript — run once from the Godot editor to rebuild the hurdle layout
# in all three lane scenes simultaneously.
#
# HOW TO RUN:
#   1. Copy this file to  HAZARD-RUSH/scripts/generate_course.gd
#   2. Open Godot editor (do NOT run the game first)
#   3. In the top menu: Script → Run
#   4. Check the Output panel — it prints a summary when done.
#
# WHAT IT DOES:
#   • Reads the Y position of existing Spike/Saw hurdles (keeps visual consistency).
#   • Removes every child whose name starts with "Spike" or "Saw".
#   • Adds 47 new hurdles at designed X positions (same layout in all three lanes).
#   • Saves each scene.
#
# COURSE DESIGN  (0 = SpikeHurdle — player JUMPS  |  1 = SawHurdle — player SLIDES)
# ─────────────────────────────────────────────────────────────────────────────
# Sec 1  Warm-up          X  300 – 1 300   4 spikes, 300 px gaps
#        Tests: Greedy Reflex, basic A* lookahead.
#
# Sec 2  Alternating      X 1 600 – 2 950  Spike / Saw / Spike / Saw / Spike
#        Tests: A* mode-switching (JUMP → SLIDE → JUMP …), plan interval.
#
# Sec 3  Consecutive pairs X 3 200 – 5 400  spike pair, saw pair, spike triple, saw pair
#        Tests: IDA* fallback when A* returns SPRINT_STEADY on short windows.
#
# Sec 4  Dense mixed zone  X 5 700 – 8 900  160–180 px gaps, alternating types
#        Tests: Full algorithm depth — Minimax sabotage window fires here.
#
# Sec 5  Endgame pressure  X 9 100 – 11 500 Tricky sub-sequences: double-saw trick,
#        saw-saw-spike, tight triple → stress-tests all three planners together.
# ─────────────────────────────────────────────────────────────────────────────
@tool
extends EditorScript

# ── Scene targets ─────────────────────────────────────────────────────────────
const SCENES := [
	{ "path": "res://scenes/game_world.tscn", "lane": "PlayerLane" },
	{ "path": "res://scenes/ai_world.tscn",   "lane": "AILane"     },
	{ "path": "res://scenes/ai_lane.tscn",    "lane": "AILane"     },
]

# ── Hurdle scene resources ────────────────────────────────────────────────────
const SPIKE_SCENE := "res://scenes/SpikeHurdle.tscn"
const SAW_SCENE   := "res://scenes/SawHurdle.tscn"

# ── Fallback Y positions (overridden by reading existing hurdles in _run) ─────
const SPIKE_Y_FALLBACK : float = 390.0
const SAW_Y_FALLBACK   : float = 265.0

# ── Course layout  [X, type]  (0 = spike / jump,  1 = saw / slide) ────────────
const COURSE : Array = [
	# ── Section 1: Warm-up ────────────────────────────────────────────────────
	#    Four evenly spaced spikes. Player & AI calibrate jump rhythm.
	[  300, 0 ], [  600, 0 ], [  950, 0 ], [ 1300, 0 ],

	# ── Section 2: Alternating intro ─────────────────────────────────────────
	#    Classic spike/saw alternation with ~350 px gaps.
	#    Forces the A* planner to flip between SPRINT and CONSERVE modes.
	[ 1600, 1 ], [ 1950, 0 ], [ 2300, 1 ], [ 2650, 0 ], [ 2950, 1 ],

	# ── Section 3: Consecutive pairs & a triple ───────────────────────────────
	#    Same-type obstacles placed 180 px apart stress-test IDA* lookahead.
	#    The triple at 4100–4460 is the first real planning challenge.
	[ 3200, 0 ], [ 3380, 0 ],   # spike pair
	[ 3700, 1 ], [ 3880, 1 ],   # saw pair
	[ 4100, 0 ], [ 4280, 0 ], [ 4460, 0 ],  # spike triple
	[ 4780, 1 ], [ 4960, 1 ],   # saw pair closer-in
	[ 5200, 0 ], [ 5400, 1 ],   # mixed close pair — first true combo

	# ── Section 4: Dense mixed zone ───────────────────────────────────────────
	#    160–180 px gaps, strict alternation.
	#    Dense zone definition (≥2 hurdles within 300 px) fires Minimax sabotage.
	[ 5700, 0 ], [ 5870, 1 ], [ 6040, 0 ], [ 6210, 1 ],
	[ 6380, 0 ], [ 6550, 1 ], [ 6720, 0 ],
	[ 6900, 0 ], [ 7070, 1 ],              # double spike → immediate saw
	[ 7250, 0 ], [ 7420, 1 ], [ 7590, 0 ], [ 7760, 1 ],
	[ 7930, 0 ], [ 8100, 1 ], [ 8270, 0 ], [ 8440, 1 ],
	[ 8610, 0 ], [ 8780, 0 ], [ 8960, 1 ], # spike-spike-saw trick

	# ── Section 5: Endgame pressure ───────────────────────────────────────────
	#    Sub-sequence traps:  double-saw,  saw-spike-saw,  saw-saw-spike-spike.
	#    Tests whether A*/IDA* can look far enough ahead to avoid penalty chains.
	[  9160, 1 ], [  9340, 0 ], [  9510, 1 ], [  9680, 1 ],  # double-saw trap
	[  9880, 0 ], [ 10060, 1 ], [ 10240, 0 ],                 # saw-spike-saw
	[ 10420, 1 ], [ 10590, 1 ], [ 10770, 0 ], [ 10940, 0 ],  # double-saw → double-spike
	[ 11150, 1 ], [ 11330, 0 ],                               # final alternating pair
]

# ─────────────────────────────────────────────────────────────────────────────

func _run() -> void:
	var spike_packed : PackedScene = load(SPIKE_SCENE)
	var saw_packed   : PackedScene = load(SAW_SCENE)

	if spike_packed == null:
		push_error("[CourseGen] Cannot load SpikeHurdle.tscn — check path.")
		return
	if saw_packed == null:
		push_error("[CourseGen] Cannot load SawHurdle.tscn — check path.")
		return

	for entry in SCENES:
		_rebuild_scene(entry["path"], entry["lane"], spike_packed, saw_packed)

	print("[CourseGen] ✓ All three scenes rebuilt with %d hurdles each." % COURSE.size())

# ─────────────────────────────────────────────────────────────────────────────

func _rebuild_scene(
	scene_path  : String,
	lane_name   : String,
	spike_packed: PackedScene,
	saw_packed  : PackedScene
) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[CourseGen] Cannot load scene: %s" % scene_path)
		return

	var root := packed.instantiate()
	var lane := _find_node(root, lane_name)
	if lane == null:
		push_error("[CourseGen] Lane node '%s' not found in %s" % [lane_name, scene_path])
		root.queue_free()
		return

	# ── Read Y references BEFORE removing existing hurdles ───────────────────
	var spike_y : float = _read_y(lane, "Spike", SPIKE_Y_FALLBACK)
	var saw_y   : float = _read_y(lane, "Saw",   SAW_Y_FALLBACK)
	print("[CourseGen] %s  spike_y=%.1f  saw_y=%.1f" % [
		scene_path.get_file(), spike_y, saw_y
	])

	# ── Remove old Spike* / Saw* children ────────────────────────────────────
	var removed := 0
	for child in lane.get_children():
		if child.name.begins_with("Spike") or child.name.begins_with("Saw"):
			lane.remove_child(child)
			child.queue_free()
			removed += 1
	print("[CourseGen]   Removed %d old hurdles." % removed)

	# ── Add new course layout ─────────────────────────────────────────────────
	var spike_n := 0
	var saw_n   := 0
	for entry in COURSE:
		var x    : int  = entry[0]
		var type : int  = entry[1]
		var node : Node2D
		if type == 0:
			node          = spike_packed.instantiate() as Node2D
			spike_n      += 1
			node.name     = "SpikeHurdle%d" % spike_n
			node.position = Vector2(float(x), spike_y)
		else:
			node          = saw_packed.instantiate() as Node2D
			saw_n        += 1
			node.name     = "SawHurdle%d" % saw_n
			node.position = Vector2(float(x), saw_y)
		lane.add_child(node)
		node.owner = root   # required for the node to persist in the saved scene

	# ── Save ─────────────────────────────────────────────────────────────────
	var new_packed := PackedScene.new()
	new_packed.pack(root)
	var err := ResourceSaver.save(new_packed, scene_path)
	root.queue_free()

	if err != OK:
		push_error("[CourseGen] Save failed for %s (code %d)" % [scene_path, err])
	else:
		print("[CourseGen]   Saved %s — %d spikes, %d saws." % [
			scene_path.get_file(), spike_n, saw_n
		])

# ─────────────────────────────────────────────────────────────────────────────

## Recursively search for the first node whose name matches target_name.
func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result := _find_node(child, target_name)
		if result != null:
			return result
	return null

## Return the Y coordinate of the first child whose name starts with prefix.
## Falls back to default_y if none is found (e.g. scene has no hurdles yet).
func _read_y(lane: Node, prefix: String, default_y: float) -> float:
	for child in lane.get_children():
		if child.name.begins_with(prefix) and child is Node2D:
			return (child as Node2D).position.y
	return default_y
