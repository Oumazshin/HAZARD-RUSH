# earth_spike_effect.gd
# @tool means this script runs inside the Godot EDITOR too, so you can:
#   • See the animation play when you open EarthSpikeEffect.tscn.
#   • Adjust scale, position, modulate, speed_scale in the Inspector or 2D view.
#   • Toggle ping_pong and see the frame count change live.

@tool
extends AnimatedSprite2D

const EARTH_SPIKE_DIR := "res://assets/traps_and_sabotage/earth_spike Hurdle/"

## Play frames 1→9 then reverse 8→1 for a pulsing rise effect.
## Disable to play only the forward sequence (9 frames).
@export var ping_pong: bool = true:
	set(v):
		ping_pong = v
		_build_frames()   # rebuild immediately so the editor preview updates

## Hides the hazard's built-in Sprite2D or AnimatedSprite2D when applied,
## so only this effect is visible.
@export var hide_original_sprite: bool = true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_frames()

func _build_frames() -> void:
	if not ResourceLoader.exists(EARTH_SPIKE_DIR + "001.png"):
		push_warning("[EarthSpikeEffect] Frames missing at: %s" % EARTH_SPIKE_DIR)
		return
	var sf := SpriteFrames.new()
	sf.add_animation("anim")
	# Forward pass: frames 001 → 009
	for i in range(1, 10):
		sf.add_frame("anim", load(EARTH_SPIKE_DIR + "%03d.png" % i))
	# Reverse pass: frames 008 → 001  (creates the pulsing rise illusion)
	if ping_pong:
		for i in range(8, 0, -1):
			sf.add_frame("anim", load(EARTH_SPIKE_DIR + "%03d.png" % i))
	sf.set_animation_loop("anim", true)
	# Speed is intentionally 1.0 here — control the actual FPS via the
	# "Speed Scale" property on this node in the Inspector.
	sf.set_animation_speed("anim", 1.0)
	sprite_frames = sf
	play("anim")

## Called by SabotageSystem after adding this node as a child of the hazard.
## Hides the hazard's original sprite if hide_original_sprite is enabled.
## Position, scale, and modulate are already encoded in the scene — no need
## to pass them here; just open EarthSpikeEffect.tscn and edit them visually.
func apply_to_hazard(hazard: Node) -> void:
	if hide_original_sprite:
		var orig := hazard.get_node_or_null("Sprite2D")
		if orig == null:
			orig = hazard.get_node_or_null("AnimatedSprite2D")
		if orig:
			orig.hide()
