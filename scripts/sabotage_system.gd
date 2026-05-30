# sabotage_system.gd
# Node inside PlayerLane in game_world.tscn

extends Node

# SpikeHurdle = HIGH (type 0) → player must JUMP
# SawHurdle   = LOW  (type 1) → player must SLIDE
const SPIKE_SCENE = preload("res://scenes/SpikeHurdle.tscn")
const SAW_SCENE   = preload("res://scenes/SawHurdle.tscn")

const SPAWN_LEAD     : float = 400.0
const HAZARD_LIFETIME: float = 10.0

func trigger() -> void:
	# Randomly pick HIGH (spike) or LOW (saw)
	var hurdle_type := randi() % 2  # 0 = HIGH/Spike, 1 = LOW/Saw
	var scene       := SPIKE_SCENE if hurdle_type == 0 else SAW_SCENE

	var spawn_x := GameState.player_position + SPAWN_LEAD
	# Get Y from an existing hurdle of the SAME type so it aligns perfectly
	var spawn_y := _get_y_for_type(hurdle_type)

	var hazard := scene.instantiate()
	hazard.global_position = Vector2(spawn_x, spawn_y)
	hazard.add_to_group("hurdles")
	get_parent().add_child(hazard)

	print("[Sabotage] Spawned ", "Spike(HIGH)" if hurdle_type == 0 else "Saw(LOW)",
		  " at X=", spawn_x, " Y=", spawn_y)

	await get_tree().create_timer(HAZARD_LIFETIME).timeout
	if is_instance_valid(hazard):
		hazard.queue_free()

# Finds an existing hurdle of the same type and returns its Y position
func _get_y_for_type(hurdle_type: int) -> float:
	# First pass: find a hurdle with the exact same type
	for node in get_tree().get_nodes_in_group("hurdles"):
		if "type" in node and node.type == hurdle_type:
			return node.global_position.y

	# Second pass: fall back to any hurdle's Y
	for node in get_tree().get_nodes_in_group("hurdles"):
		return node.global_position.y

	# Last resort: use AI's own Y
	return get_parent().get_node_or_null("Player").global_position.y if get_parent().has_node("Player") else 0.0
