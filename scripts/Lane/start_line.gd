# start_line.gd
# ─────────────────────────────────────────────────────────────────────────────
# Animated start line decoration.
# Add scenes/StartLine.tscn directly to the Lane node (PlayerLane / AILane)
# in game_world.tscn and ai_world.tscn, NOT under Player or Camera2D.
# Position it at the race start X (typically X = 0).
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

const SPRITE_PATH : String  = "res://assets/environment/Decorations/Start Line (Moving) (64x64).png"
const FRAME_H     : int     = 64   # each frame is 64 × 64 px
const ANIM_FPS    : float   = 8.0
const WORLD_SCALE : Vector2 = Vector2(3.0, 3.0)

@onready var _sprite : AnimatedSprite2D = $StartSprite

func _ready() -> void:
	scale = WORLD_SCALE
	_build_animation()
	# Push this node and its children behind other standard assets
	z_index = -10

func _build_animation() -> void:
	if not ResourceLoader.exists(SPRITE_PATH):
		push_error("[StartLine] Texture missing: '%s'" % SPRITE_PATH)
		return

	var sheet : Texture2D = load(SPRITE_PATH)
	var fc    : int       = int(float(sheet.get_width()) / float(FRAME_H))

	if fc <= 0:
		push_warning("[StartLine] Could not detect frame count from texture.")
		return

	var sf := SpriteFrames.new()
	sf.add_animation("move")
	sf.set_animation_loop("move", true)
	sf.set_animation_speed("move", ANIM_FPS)

	for i in fc:
		var atlas    := AtlasTexture.new()
		atlas.atlas  =  sheet
		atlas.region =  Rect2(i * FRAME_H, 0, FRAME_H, FRAME_H)
		sf.add_frame("move", atlas)

	_sprite.sprite_frames  = sf
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play("move")
	print("[StartLine] Ready — %d frames." % fc)
