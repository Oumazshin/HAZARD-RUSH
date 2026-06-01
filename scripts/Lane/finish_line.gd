# finish_line.gd
# ─────────────────────────────────────────────────────────────────────────────
# Animated finish line decoration (flag + trophy).
# Add scenes/FinishLine.tscn directly to the Lane node in game_world.tscn
# and ai_world.tscn at the goal X position (use goal.tscn's X as reference).
# NOT a child of Player or Camera2D.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

const FLAG_PATH   : String  = "res://assets/environment/Decorations/Finish line flag (Flag Idle)(64x64).png"
const TROPHY_PATH : String  = "res://assets/environment/Decorations/Finish Line Trophy (Pressed) (64x64).png"
const FRAME_H     : int     = 64
const FLAG_FPS    : float   = 8.0
const TROPHY_FPS  : float   = 6.0
const WORLD_SCALE : Vector2 = Vector2(3.0, 3.0)

@onready var _flag_sprite   : AnimatedSprite2D = $FlagSprite
@onready var _trophy_sprite : AnimatedSprite2D = $TrophySprite

func _ready() -> void:
	scale = WORLD_SCALE
	
	# Push this node and its children behind other standard assets
	z_index = -10
	
	# Safeguard: Check if the nodes were successfully found before moving them
	if _flag_sprite == null or _trophy_sprite == null:
		push_error("[FinishLine] Error: Cannot find FlagSprite or TrophySprite. Check node names in FinishLine.tscn.")
		return
	
	# The flag stays exactly at the parent's position
	_flag_sprite.position = Vector2(0, 0)
	
	# Push the trophy far past the finish line flag
	_trophy_sprite.position = Vector2(150, 0)
	
	_build_animation(_flag_sprite,   FLAG_PATH,   "idle", FLAG_FPS)
	_build_animation(_trophy_sprite, TROPHY_PATH, "idle", TROPHY_FPS)

## Shared helper — loads a horizontal spritesheet and plays it on a given sprite.
func _build_animation(
	sprite    : AnimatedSprite2D,
	path      : String,
	anim_name : String,
	fps       : float
) -> void:
	if sprite == null:
		push_error("[FinishLine] Sprite node is null when loading '%s'." % path)
		return
	if not ResourceLoader.exists(path):
		push_warning("[FinishLine] Texture missing: '%s'" % path)
		return

	var sheet : Texture2D = load(path)
	var fc    : int       = int(float(sheet.get_width()) / float(FRAME_H))

	if fc <= 0:
		push_warning("[FinishLine] No frames detected in '%s'." % path)
		return

	var sf := SpriteFrames.new()
	sf.add_animation(anim_name)
	sf.set_animation_loop(anim_name, true)
	sf.set_animation_speed(anim_name, fps)

	for i in fc:
		var atlas    := AtlasTexture.new()
		atlas.atlas  =  sheet
		atlas.region =  Rect2(i * FRAME_H, 0, FRAME_H, FRAME_H)
		sf.add_frame(anim_name, atlas)

	sprite.sprite_frames  = sf
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play(anim_name)
	print("[FinishLine] '%s' ready — %d frames." % [path.get_file(), fc])
