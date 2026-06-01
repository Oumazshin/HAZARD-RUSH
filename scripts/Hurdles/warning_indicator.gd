# warning_indicator.gd
# ─────────────────────────────────────────────────────────────────────────────
# Animated warning indicator that plays the spritesheet at:
#   res://assets/environment/Hurdles/warning_incoming_hurdle/spritesheet.png
#
# Placed: scenes/WarningIndicator.tscn  →  attach to root Node2D
#
# ── Spawn-type alignment ─────────────────────────────────────────────────────
# The warning must appear at the SAME VISUAL HEIGHT as the incoming hazard so
# the player can read where to dodge.  Two cases, matching hazard anchor logic:
#
#   is_low_spawn = false  (HIGH)
#     global_position.y = SawHurdle Y (spawn_y from sabotage_system)
#     Sprite centred at global_position.y → matches HIGH fireball centre.
#
#   is_low_spawn = true   (LOW)
#     global_position.y = SpikeHurdle Y / floor Y (spawn_y)
#     Sprite bottom-anchored at global_position.y → matches LOW fireball and
#     earth spike, whose sprite bottoms also sit at spawn_y.
#
#     Bottom-anchor derivation (root scale = 2, sprite scale = 1):
#       sprite world centre  = spawn_y + local_y × 2
#       sprite world bottom  = sprite world centre + (fh × 2 / 2) = spawn_y + local_y × 2 + fh
#       For bottom at spawn_y:  local_y = -fh / 2.0
#         world centre  = spawn_y + (-fh/2) × 2 = spawn_y − fh
#         world bottom  = spawn_y − fh + fh = spawn_y  ✓
#
# ── Critical ordering ────────────────────────────────────────────────────────
# Set is_low_spawn BEFORE get_parent().add_child(warning) in sabotage_system.gd.
# add_child triggers _ready(), which calls _build_animation(), which calls
# _apply_alignment() — so the correct anchor is applied on the very first frame.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

const SHEET_PATH  : String  = "res://assets/environment/Hurdles/warning_incoming_hurdle/spritesheet.png"
const ANIM_FPS    : float   = 8.0
const WORLD_SCALE : Vector2 = Vector2(2.0, 2.0)

@onready var _sprite : AnimatedSprite2D = $WarningSprite

# ── Spawn configuration ───────────────────────────────────────────────────────
## Set by sabotage_system.gd BEFORE add_child() — mirrors the pattern used by
## fireball_projectile.gd and earth_spike_effect.gd.
## false = HIGH hazard  →  sprite centred at global_position.y
## true  = LOW  hazard  →  sprite bottom-anchored at global_position.y (floor)
@export var is_low_spawn : bool = false

# ── Frame layout config ───────────────────────────────────────────────────────
## Total frames in the sheet (0 = auto-detect from texture dimensions).
@export var frame_count : int     = 0
## Pixel size of one frame — used only when frame_count > 0.
@export var frame_size  : Vector2i = Vector2i(64, 64)

# ── Internal ──────────────────────────────────────────────────────────────────
var _built_frame_h : int = 0   # frame height measured during _build_animation()

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	scale = WORLD_SCALE
	_build_animation()

# ── Public API ────────────────────────────────────────────────────────────────

## Called by sabotage_system.gd AFTER add_child() to configure the spritesheet.
## is_low_spawn is already set before add_child(), so this only handles
## frame_count and frame_size overrides.
func setup(fc: int = 0, fsize: Vector2i = Vector2i(64, 64)) -> void:
	frame_count = fc
	frame_size  = fsize
	if is_inside_tree():
		_build_animation()

# ── Animation + alignment ─────────────────────────────────────────────────────

func _build_animation() -> void:
	if _sprite == null:
		push_error("[WarningIndicator] $WarningSprite not found. "
				 + "Check WarningIndicator.tscn has an AnimatedSprite2D named 'WarningSprite'.")
		return

	if not ResourceLoader.exists(SHEET_PATH):
		push_error("[WarningIndicator] Spritesheet missing: %s" % SHEET_PATH)
		return

	var sheet : Texture2D = load(SHEET_PATH)

	# ── Frame layout detection ────────────────────────────────────────────────
	var fh : int
	var fc : int

	if frame_count <= 0:
		# Auto-detect: assume square frames packed horizontally.
		fh = sheet.get_height()
		fc = int(float(sheet.get_width()) / float(fh))
		if fc <= 0:
			push_warning("[WarningIndicator] Auto-detect failed (%dx%d). Defaulting to 4 frames."
					   % [sheet.get_width(), sheet.get_height()])
			fc = 4
	else:
		fc = frame_count
		fh = frame_size.y

	var fw : int = int(float(sheet.get_width()) / float(fc))
	_built_frame_h = fh   # save for _apply_alignment()

	# ── Build SpriteFrames ────────────────────────────────────────────────────
	var sf := SpriteFrames.new()
	sf.add_animation("warn")
	sf.set_animation_loop("warn", true)
	sf.set_animation_speed("warn", ANIM_FPS)

	for i in fc:
		var atlas        := AtlasTexture.new()
		atlas.atlas      =  sheet
		atlas.region     =  Rect2(i * fw, 0, fw, fh)
		sf.add_frame("warn", atlas)

	_sprite.sprite_frames  = sf
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play("warn")

	# ── Vertical alignment ────────────────────────────────────────────────────
	# Must be called AFTER _built_frame_h is set.
	_apply_alignment()

	print("[WarningIndicator] %s — %d frames (%d×%d px)  sprite_y=%.1f" % [
		"LOW (bottom-anchor)" if is_low_spawn else "HIGH (centred)",
		fc, fw, fh,
		_sprite.position.y
	])

## Positions the warning sprite so its visual height matches the incoming hazard.
func _apply_alignment() -> void:
	if _sprite == null or _built_frame_h <= 0:
		return

	if is_low_spawn:
		# ── LOW: bottom-anchor ────────────────────────────────────────────────
		# global_position.y = spawn_y = floor reference (SpikeHurdle Y).
		# Shift sprite up so its BOTTOM edge sits at global_position.y.
		# This matches earth_spike_effect.gd and the LOW fireball anchor logic.
		#   local_y = -(frame_h / 2.0)
		#   world sprite bottom = spawn_y + local_y × WORLD_SCALE.y + frame_h
		#                       = spawn_y  ✓
		_sprite.position.y = -float(_built_frame_h) / 2.0
	else:
		# ── HIGH: centre ──────────────────────────────────────────────────────
		# global_position.y = spawn_y = SawHurdle Y (elevated).
		# Centre the sprite at global_position.y — matches the HIGH fireball.
		_sprite.position.y = 0.0
