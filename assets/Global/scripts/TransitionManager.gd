# ==============================================================================
# TransitionManager.gd
# Autoload Singleton — Scene Transition Controller
# Project   : HAZARD-RUSH
# Godot Ver : 4.6.3
#
# HOW TO REGISTER:
#   Project > Project Settings > Autoload
#   Path : res://assets/Global/scenes/TransitionLayer.tscn
#   Name : TransitionManager
#
# SHADER CONTRACT (transition.gdshader):
#   uniform vec4  base_color        → overlay color (default: black)
#   uniform vec2  node_resolution   → must match live viewport size
#   uniform float factor [0..1]     → 0.0 = fully transparent, 1.0 = fully opaque
#   uniform float width             → edge softness band
#   uniform sampler2D gradient_texture → defines wipe direction/shape
#   uniform bool  gradient_fixed    → if true, uses aspect-corrected UV for gradient
#   uniform sampler2D shape_texture → pattern applied to the wipe edge
#   uniform float shape_tiling      → how many times shape texture tiles
#   uniform float shape_rotation    → shape texture rotation in degrees
#   uniform vec2  shape_scroll      → animated scroll speed of shape texture
#   uniform float shape_feathering  → smoothness of the shaped edge [0..1]
#   uniform float shape_treshold    → shape cutoff threshold [0..2]
# ==============================================================================

extends CanvasLayer

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------

## Emitted when the overlay has fully covered the screen (end of fade_out).
signal fade_out_completed

## Emitted when the overlay has fully cleared (end of fade_in).
signal fade_in_completed

## Emitted when a full transition_to() cycle completes (both halves done).
signal transition_completed

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

const SHADER_PATH     : String = "res://assets/Global/shaders/transition.gdshader"
const DEFAULT_DURATION: float  = 0.5

# ------------------------------------------------------------------------------
# Node Reference
# (The ColorRect was created in TransitionLayer.tscn by the MCP tool)
# ------------------------------------------------------------------------------

@onready var _color_rect: ColorRect = $ColorRect

# ------------------------------------------------------------------------------
# Private Variables
# ------------------------------------------------------------------------------

var _shader_material : ShaderMaterial = null
var _tween           : Tween          = null
var _is_transitioning: bool           = false

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	# Render above all other CanvasLayers in every scene.
	layer = 100

	# The overlay must NEVER block player input.
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ensure the ColorRect fills the entire screen.
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Build ShaderMaterial and push all required uniform values.
	_setup_shader_material()

	# Sync node_resolution to the current viewport immediately.
	_update_node_resolution()

	# Connect to viewport resize so node_resolution stays accurate
	# throughout the game (important for aspect-ratio correction in the shader).
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Start fully transparent — the game is visible when it launches.
	# factor = 0.0 → overlay is invisible.
	_set_factor(0.0)


# ==============================================================================
# PRIVATE — SETUP
# ==============================================================================

## Loads transition.gdshader, wraps it in a ShaderMaterial, assigns it to the
## ColorRect, and sets EVERY required uniform to a safe default value.
func _setup_shader_material() -> void:
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		push_error(
			("[TransitionManager] Shader not found at '%s'. " +
			"Verify the file exists and the path is correct.") % SHADER_PATH
		)
		return

	_shader_material        = ShaderMaterial.new()
	_shader_material.shader = shader
	_color_rect.material    = _shader_material

	# ── Scalar / Vector uniforms ──────────────────────────────────────────────
	_shader_material.set_shader_parameter("base_color",       Color(0.0, 0.0, 0.0, 1.0))
	_shader_material.set_shader_parameter("factor",           0.0)
	_shader_material.set_shader_parameter("width",            0.4)
	_shader_material.set_shader_parameter("gradient_fixed",   false)
	_shader_material.set_shader_parameter("shape_tiling",     32.0)
	_shader_material.set_shader_parameter("shape_rotation",   0.0)
	_shader_material.set_shader_parameter("shape_scroll",     Vector2(0.0, 0.0))
	_shader_material.set_shader_parameter("shape_feathering", 0.0)
	_shader_material.set_shader_parameter("shape_treshold",   1.0)

	# ── Gradient texture (defines wipe direction) ─────────────────────────────
	# Default: a horizontal left-to-right gradient (black → white).
	# This produces a left-to-right wipe transition.
	# Swap this texture in the ShaderMaterial Inspector for other wipe styles
	# (e.g. radial, diagonal, top-to-bottom).
	_shader_material.set_shader_parameter("gradient_texture", _make_gradient_texture())

	# ── Shape texture (adds detail to the wipe edge) ──────────────────────────
	# Default: solid black → produces a clean, hard-edged wipe with no pattern.
	# Replace with a noise or pattern texture for a stylized dissolve edge.
	_shader_material.set_shader_parameter("shape_texture", _make_default_shape_texture())


## Creates a horizontal linear gradient texture (black left → white right).
## This is the default gradient that drives a left-to-right wipe.
func _make_gradient_texture() -> GradientTexture2D:
	var gradient       := Gradient.new()
	gradient.colors    =  [Color(0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0)]
	gradient.offsets   =  [0.0, 1.0]

	var tex            := GradientTexture2D.new()
	tex.gradient       =  gradient
	tex.width          =  256
	tex.height         =  256
	tex.fill           =  GradientTexture2D.FILL_LINEAR
	tex.fill_from      =  Vector2(0.0, 0.5)   # Horizontal: left-center
	tex.fill_to        =  Vector2(1.0, 0.5)   # Horizontal: right-center
	return tex


## Creates a 4×4 solid-black ImageTexture.
## With this texture, shape_value = 1.0 at every pixel, which makes the shader
## perform a pure gradient wipe with no shaped edge decoration.
func _make_default_shape_texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	return ImageTexture.create_from_image(img)


# ==============================================================================
# PRIVATE — SHADER PARAMETER HELPERS
# ==============================================================================

## Writes the 'factor' parameter to the ShaderMaterial.
##   factor = 0.0  →  overlay fully transparent  (game is visible)
##   factor = 1.0  →  overlay fully opaque       (screen is covered / black)
func _set_factor(value: float) -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("factor", value)


## Reads the current 'factor' value from the ShaderMaterial.
func _get_factor() -> float:
	if _shader_material == null:
		return 0.0
	return _shader_material.get_shader_parameter("factor")


## Pushes the current viewport dimensions to the 'node_resolution' uniform.
## This uniform drives the aspect-ratio correction in the shader's fragment().
## Must be called on _ready() and again whenever the window is resized.
func _update_node_resolution() -> void:
	if _shader_material == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_shader_material.set_shader_parameter("node_resolution", vp_size)


## Kills any currently-running Tween to prevent animation conflicts.
func _kill_active_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# ==============================================================================
# PRIVATE — SIGNAL CALLBACKS
# ==============================================================================

## Called by Godot whenever the viewport is resized.
## Keeps node_resolution in sync for correct aspect-ratio wipes.
func _on_viewport_size_changed() -> void:
	_update_node_resolution()


# ==============================================================================
# PUBLIC API
# ==============================================================================

## Returns true while any transition animation is actively playing.
## Use this to block player input or UI interactions during a transition.
##
## Example:
##   if not TransitionManager.is_transitioning():
##       TransitionManager.transition_to("res://scene.tscn")
func is_transitioning() -> bool:
	return _is_transitioning


# ── fade_out() ─────────────────────────────────────────────────────────────────

## Animates the overlay from TRANSPARENT → OPAQUE (factor: 0.0 → 1.0).
## The screen appears to fade to black. Awaitable.
##
## Call this BEFORE changing the scene. The game is invisible when it resolves.
##
## Parameters:
##   duration  Seconds for the fade animation to complete. Default = 0.5.
##
## Example:
##   await TransitionManager.fade_out()
##   get_tree().change_scene_to_file("res://assets/Scenes/GameScene.tscn")
func fade_out(duration: float = DEFAULT_DURATION) -> void:
	_is_transitioning = true
	_kill_active_tween()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_set_factor, 0.0, 1.0, duration)

	await _tween.finished
	_is_transitioning = false
	fade_out_completed.emit()


# ── fade_in() ──────────────────────────────────────────────────────────────────

## Animates the overlay from OPAQUE → TRANSPARENT (factor: 1.0 → 0.0).
## The screen appears to fade in from black. Awaitable.
##
## Call this AFTER the new scene has loaded. Snaps to opaque first to
## prevent any 1-frame flicker if called out of sequence.
##
## Parameters:
##   duration  Seconds for the fade animation to complete. Default = 0.5.
##
## Example:
##   get_tree().change_scene_to_file("res://assets/Scenes/MainMenu.tscn")
##   await TransitionManager.fade_in()
func fade_in(duration: float = DEFAULT_DURATION) -> void:
	_is_transitioning = true
	_kill_active_tween()

	# Snap to fully opaque before animating, so fade_in() is always safe to
	# call even if a prior fade_out() was skipped or interrupted.
	_set_factor(1.0)

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_set_factor, 1.0, 0.0, duration)

	await _tween.finished
	_is_transitioning = false
	fade_in_completed.emit()


# ── transition_to() ────────────────────────────────────────────────────────────

## Full transition cycle: fade_out → change_scene → yield one frame → fade_in.
## This is the recommended one-call method for most scene changes in the game.
##
## Parameters:
##   scene_path   Full res:// path to the target .tscn file.
##   duration     Seconds for EACH half of the transition. Default = 0.5.
##
## Behavior on scene-change error:
##   Prints an error and fades back in so the game is never stuck on black.
##
## Example:
##   TransitionManager.transition_to("res://assets/Scenes/MainMenu.tscn")
##   TransitionManager.transition_to("res://assets/Scenes/GameScene.tscn", 0.8)
func transition_to(scene_path: String, duration: float = DEFAULT_DURATION) -> void:
	if _is_transitioning:
		push_warning(
			("[TransitionManager] transition_to('%s') was called while a " +
			"transition is already in progress. Request ignored.") % scene_path
		)
		return

	await fade_out(duration)

	var err: int = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error(
			("[TransitionManager] change_scene_to_file('%s') failed " +
			"(Error code: %d). Fading back in to recover.") % [scene_path, err]
		)
		await fade_in(duration)
		return

	# Wait exactly one process frame so the new scene's _ready() can run
	# before the fade-in begins. Prevents a 1-frame visual artifact.
	await get_tree().process_frame

	await fade_in(duration)
	transition_completed.emit()


# ── Instant Cuts ───────────────────────────────────────────────────────────────

## Instantly covers the screen with no animation (factor snaps to 1.0).
## Use for hard-cut game-overs, crash events, or preloaded scene swaps.
func cut_to_black() -> void:
	_kill_active_tween()
	_set_factor(1.0)
	_is_transitioning = false


## Instantly clears the overlay with no animation (factor snaps to 0.0).
## Use after a cut_to_black() once the new scene is ready.
func cut_to_clear() -> void:
	_kill_active_tween()
	_set_factor(0.0)
	_is_transitioning = false


# ── Runtime Customisation ──────────────────────────────────────────────────────

## Changes the overlay color at runtime. Default is black (Color(0,0,0,1)).
## Call before a transition to change the color for that specific transition.
##
## Example:
##   TransitionManager.set_overlay_color(Color(1, 0, 0, 1))  # Red flash
##   TransitionManager.transition_to("res://assets/Scenes/BossLevel.tscn")
func set_overlay_color(color: Color) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("base_color", color)


## Replaces the gradient texture used to define the wipe direction.
## Supply any Texture2D — a GradientTexture2D, ImageTexture, or loaded .png.
##
## Wipe direction is encoded by the gradient:
##   • Horizontal (default) : black(left) → white(right)  = left-to-right wipe
##   • Vertical             : black(top)  → white(bottom) = top-to-bottom wipe
##   • Radial               : use GradientTexture2D with FILL_RADIAL
func set_gradient_texture(texture: Texture2D) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("gradient_texture", texture)


## Replaces the shape texture used to decorate the wipe edge.
## Use a noise or hand-drawn texture for a dissolve or organic-edge wipe.
## Use a solid black texture (default) for a clean sharp edge.
func set_shape_texture(texture: Texture2D) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("shape_texture", texture)
