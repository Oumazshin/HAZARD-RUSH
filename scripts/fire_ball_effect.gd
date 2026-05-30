# fire_ball_effect.gd
# @tool means this script runs inside the Godot EDITOR too, so you can:
#   • See the animation play when you open FireBallEffect.tscn.
#   • Adjust scale, position, modulate, speed_scale in the Inspector or 2D view.

@tool
extends AnimatedSprite2D

const FIRE_BALL_DIR := "res://assets/traps_and_sabotage/fire_ball hurdle/"

## Hides the hazard's built-in Sprite2D or AnimatedSprite2D when applied,
## so only this effect is visible.
@export var hide_original_sprite: bool = true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_frames()

func _build_frames() -> void:
	if not ResourceLoader.exists(FIRE_BALL_DIR + "001.png"):
		push_warning("[FireBallEffect] Frames missing at: %s" % FIRE_BALL_DIR)
		return
	var sf := SpriteFrames.new()
	sf.add_animation("anim")
	for i in range(1, 11):   # 10 frames: 001 → 010
		sf.add_frame("anim", load(FIRE_BALL_DIR + "%03d.png" % i))
	sf.set_animation_loop("anim", true)
	# Speed is intentionally 1.0 here — control the actual FPS via the
	# "Speed Scale" property on this node in the Inspector.
	sf.set_animation_speed("anim", 1.0)
	sprite_frames = sf
	play("anim")

## Called by SabotageSystem after adding this node as a child of the hazard.
## Position, scale, and modulate are already encoded in the scene — no need
## to pass them here; just open FireBallEffect.tscn and edit them visually.
func apply_to_hazard(hazard: Node) -> void:
	if hide_original_sprite:
		var orig := hazard.get_node_or_null("Sprite2D")
		if orig == null:
			orig = hazard.get_node_or_null("AnimatedSprite2D")
		if orig:
			orig.hide()
