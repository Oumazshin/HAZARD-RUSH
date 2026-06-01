# background_images.gd
# ─────────────────────────────────────────────────────────────────────────────
# Drives the parallax background for MenuBackground.tscn.
#
# Improvements over original:
#  • Phase-aware speed  — background accelerates when a race is active.
#  • Smooth transitions — frame-rate independent exponential smoothing.
#  • Vertical bob       — scales cleanly with pause state to maintain harmony.
#  • Pause-graceful     — slows to a crawl during pause/results.
#  • Float-safe         — prevents time accumulation errors on long sessions.
# ─────────────────────────────────────────────────────────────────────────────
extends ParallaxBackground

# ── Scroll speed ──────────────────────────────────────────────────────────────
@export_group("Scroll Speed")
## Horizontal scroll speed (px/s) while on the menu or in any non-racing phase.
@export var menu_speed      : float = 55.0
## Horizontal scroll speed (px/s) while a race is actively running.
@export var racing_speed    : float = 140.0
## How quickly the speed transitions between the two targets (higher = snappier).
@export var transition_rate : float = 2.0
## Multiplier applied when the SceneTree is paused (0 = freeze, 1 = full speed).
@export_range(0.0, 1.0) var paused_speed_scale : float = 0.12

# ── Vertical bob ──────────────────────────────────────────────────────────────
@export_group("Vertical Bob")
## Enable or disable the sine-wave vertical drift entirely.
@export var bob_enabled   : bool  = true
## Maximum vertical displacement in pixels.
@export var bob_amplitude : float = 4.0
## Complete cycles per second.  0.3–0.5 is barely perceptible; above 1 is choppy.
@export var bob_frequency : float = 0.38

# ── Runtime ───────────────────────────────────────────────────────────────────
var _current_speed : float = 0.0
var _bob_time      : float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Ensure the background always processes — it lives outside the game
	# viewport and must keep rendering during pause menus and result screens.
	process_mode   = Node.PROCESS_MODE_ALWAYS
	_current_speed = menu_speed

func _process(delta: float) -> void:
	# ── Determine target state & time scale ────────────────────────────────
	var target : float = racing_speed if GameState.is_racing() else menu_speed
	var time_scale : float = 1.0

	# Slow to a crawl when paused rather than stopping dead.
	if get_tree().paused:
		target *= paused_speed_scale
		time_scale = paused_speed_scale

	# ── Smooth speed transition ────────────────────────────────────────────
	# Using exponential decay ensures the transition speed is identical
	# regardless of whether the game runs at 30, 60, or 144 FPS.
	_current_speed = lerpf(target, _current_speed, exp(-transition_rate * delta))

	# ── Horizontal scroll ──────────────────────────────────────────────────
	scroll_offset.x -= _current_speed * delta

	# ── Vertical bob ──────────────────────────────────────────────────────
	if bob_enabled and bob_frequency > 0.0:
		# Scale the bob time so the bobbing also slows down when paused
		_bob_time += delta * time_scale
		
		# Wrap the timer to prevent floating-point precision loss over time.
		# 1.0 / bob_frequency gives us the exact length of one full cycle in seconds.
		_bob_time = wrapf(_bob_time, 0.0, 1.0 / bob_frequency)
		
		scroll_offset.y = sin(_bob_time * TAU * bob_frequency) * bob_amplitude
