extends Node2D
# Visible finish line. goal.gd adds one of these as a child of each Goal at
# runtime (the Goal's built-in Sprite2D is empty). The banner is centered on the
# racer's actual height in this lane, so it shows correctly in BOTH the player
# and opponent views — even though the two lanes sit at very different Y offsets.

const HALF_H := 200.0    # half-height of the checkered band
const BAND_W := 40.0     # band width
const COL_W  := 20.0
const ROW_H  := 25.0
const COLS   := 2

const DARK  := Color(0.10, 0.10, 0.10, 0.72)
const LIGHT := Color(0.96, 0.96, 0.96, 0.72)

var _t := 0.0
var _racer: Node2D = null

func _ready() -> void:
	z_index = 5          # draw above the floor and parallax background
	z_as_relative = false

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()       # animate the gentle wave

# The racer (player or AI) sharing this lane, so the banner can match its height.
func _get_racer() -> Node2D:
	if _racer != null and is_instance_valid(_racer):
		return _racer
	var lane := get_parent().get_parent()   # FinishLineVisual -> Goal -> lane
	for grp in ["player", "opponent"]:
		for n in get_tree().get_nodes_in_group(grp):
			if lane != null and lane.is_ancestor_of(n):
				_racer = n as Node2D
				return _racer
	return null

func _draw() -> void:
	# Vertical center of the banner, in local space, at the racer's height.
	var cy := 0.0
	var racer := _get_racer()
	if racer != null:
		cy = to_local(racer.global_position).y
	var left := -BAND_W / 2.0

	# Pole
	draw_rect(Rect2(left - 10.0, cy - HALF_H - 70.0, 8.0, (HALF_H * 2.0) + 70.0),
			Color(0.22, 0.22, 0.25, 1.0))

	# Checkered banner band with a gentle per-row wave.
	var rows := int((HALF_H * 2.0) / ROW_H)
	for row in rows:
		var y := cy - HALF_H + row * ROW_H
		var wave := sin(_t * 3.0 + row * 0.5) * 3.0
		for col in COLS:
			var x := left + col * COL_W + wave
			var c := DARK if ((row + col) % 2 == 0) else LIGHT
			draw_rect(Rect2(x, y, COL_W, ROW_H), c)

	# Bright marker line at the exact finish x.
	draw_rect(Rect2(-1.5, cy - HALF_H - 6.0, 3.0, (HALF_H * 2.0) + 12.0),
			Color(1.0, 0.85, 0.0, 0.9))

	# Small waving flag at the top of the pole.
	var fx := left - 2.0
	var fy := cy - HALF_H - 70.0
	for col in 3:
		for r2 in 2:
			var fw := sin(_t * 4.0 + col * 0.7) * 2.5
			var cc := DARK if ((col + r2) % 2 == 0) else LIGHT
			draw_rect(Rect2(fx + col * 16.0, fy + r2 * 14.0 + fw, 16.0, 14.0), cc)
