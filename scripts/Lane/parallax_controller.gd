extends ParallaxBackground

const SPEEDS: Array[float] = [0.05, 0.15, 0.30, 0.55]

func _ready() -> void:
	await get_tree().process_frame
	_setup_layers()

func _setup_layers() -> void:
	var screen_w: float = float(get_window().size.x)
	var screen_h: float = float(get_window().size.y) / 2.0

	# Renamed "layer" to "p_layer" to avoid shadowing CanvasLayer's property
	for i in range(get_child_count()):
		var p_layer := get_child(i)
		if not p_layer is ParallaxLayer:
			continue

		var speed: float = SPEEDS[i] if i < SPEEDS.size() else 0.1 * float(i + 1)
		p_layer.motion_scale = Vector2(speed, 0.0)

		var sprite: Sprite2D = null
		for child in p_layer.get_children():
			if child is Sprite2D and child.texture != null:
				sprite = child as Sprite2D
				break

		if sprite == null:
			continue

		var tex_w: float = float(sprite.texture.get_width())
		var tex_h: float = float(sprite.texture.get_height())
		var scale_f: float = screen_h / tex_h
		sprite.scale    = Vector2(scale_f, scale_f)
		sprite.centered = false
		sprite.position = Vector2.ZERO

		var tile_w: float = tex_w * scale_f

		for child in p_layer.get_children():
			if child != sprite:
				child.queue_free()

		var copies: int = ceili(screen_w / tile_w) + 2
		for c in range(1, copies):
			var copy: Sprite2D = sprite.duplicate() as Sprite2D
			copy.position = Vector2(tile_w * float(c), 0.0)
			p_layer.add_child(copy)

		p_layer.motion_mirroring = Vector2(tile_w * float(copies), 0.0)
