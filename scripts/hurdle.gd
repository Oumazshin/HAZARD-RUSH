@tool
extends Area2D

# 0 = HIGH (Requires Jump), 1 = LOW (Requires Slide)
@export_enum("HIGH", "LOW") var type: int = 0:
	set(value):
		type = value
		_update_visuals()

func _ready() -> void:
	add_to_group("hurdles")
	_update_visuals()
	# Ensure the signal is connected (or do it in the editor)
	body_entered.connect(_on_body_entered)

func _update_visuals() -> void:
	# Using 'is_inside_tree' makes sure it doesn't crash when running the game
	if is_inside_tree():
		modulate = Color.RED if type == 0 else Color.BLUE

# This detects when the Player's PhysicsBody enters the hazard
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("trigger_momentum_crash"):
		body.trigger_momentum_crash()
		print("Player hit a hurdle of type: ", "HIGH" if type == 0 else "LOW")
	elif body.has_method("_trigger_stumble"):
		body._trigger_stumble()
		print("AI hit a hurdle of type: ", "HIGH" if type == 0 else "LOW")
