extends ParallaxBackground

# This controls how fast the background moves. 
# You can change this number in the Inspector later if you export it.
@export var scroll_speed: float = 100.0

func _process(delta: float) -> void:
	# Subtracting from the x axis moves it to the left. 
	# Use += if you want it to scroll to the right.
	scroll_offset.x -= scroll_speed * delta
