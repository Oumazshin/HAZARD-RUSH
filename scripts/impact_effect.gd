# impact_effect.gd
# ─────────────────────────────────────────────────────────────────────────────
# One-shot visual hit effect.  Self-destructs after animation completes.
# Scene: scenes/ImpactEffect.tscn
#
# ── Usage ────────────────────────────────────────────────────────────────────
# Call from player.gd / opponent_ai.gd:
#   ImpactEffect.spawn_at(global_position, get_parent())
#
# ── Why load() not preload() ─────────────────────────────────────────────────
# ImpactEffect.tscn has THIS script attached to its root node.
# Using:  const SCENE = preload("res://scenes/ImpactEffect.tscn")
# …inside this file creates a circular dependency:
#   script → preloads scene → scene loads script → script → …
# Godot resolves preload() at COMPILE TIME, so the circle causes an
# immediate crash before the project opens.
# Using load() at RUNTIME breaks the circle: the scene file is only
# fetched when spawn_at() is actually called, after everything is compiled.
#
# ── Why (load(...) as PackedScene).instantiate() ─────────────────────────────
# load() returns Variant — GDScript cannot infer a type from Variant.
# Casting to PackedScene first makes .instantiate() return Node (typed),
# which resolves the "Cannot infer the type of 'effect' variable" error.
# ─────────────────────────────────────────────────────────────────────────────
class_name ImpactEffect
extends Node2D

const SHEET_PATH  : String  = "res://assets/Characters/impact_when_hit/spritesheet.png"
const ANIM_FPS    : float   = 14.0
const WORLD_SCALE : Vector2 = Vector2(2.5, 2.5)

@onready var _sprite : AnimatedSprite2D = $ImpactSprite

func _ready() -> void:
	scale = WORLD_SCALE
	_build_and_play()

func _build_and_play() -> void:
	if not ResourceLoader.exists(SHEET_PATH):
		push_error("[ImpactEffect] Spritesheet missing: '%s'" % SHEET_PATH)
		queue_free()
		return

	var sheet   : Texture2D = load(SHEET_PATH)
	var frame_h : int       = sheet.get_height()
	var fc      : int       = int(float(sheet.get_width()) / float(frame_h))

	if fc <= 0:
		push_error("[ImpactEffect] Could not detect frames.")
		queue_free()
		return

	var sf := SpriteFrames.new()
	sf.add_animation("hit")
	sf.set_animation_loop("hit", false)
	sf.set_animation_speed("hit", ANIM_FPS)

	for i in fc:
		var atlas    := AtlasTexture.new()
		atlas.atlas  =  sheet
		atlas.region =  Rect2(i * frame_h, 0, frame_h, frame_h)
		sf.add_frame("hit", atlas)

	_sprite.sprite_frames  = sf
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("hit")

# ── Static factory ────────────────────────────────────────────────────────────

## Spawn a hit effect at a world position.
## load() avoids circular dependency. Cast to PackedScene fixes Variant inference.
static func spawn_at(world_pos: Vector2, parent: Node) -> void:
	var effect : Node      = (load("res://scenes/ImpactEffect.tscn") as PackedScene).instantiate()
	parent.add_child(effect)
	effect.global_position = world_pos
