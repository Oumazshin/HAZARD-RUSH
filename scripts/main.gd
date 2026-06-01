extends Node2D

const EARTH_SPIKE_DIR : String = "res://assets/new/Earth_Spike/"

@onready var results_menu = get_node_or_null("ResultsMenu")
@onready var hud : CanvasLayer = get_node_or_null("HUD")

var results_shown : bool  = false
var time_left     : float = 60.0

func _ready() -> void:
	if results_menu:
		results_menu.hide()

	# 🧹 NUKE LEFT-OVER EDITOR LABELS (This destroys the floating "3")
	if hud:
		for child in hud.get_children():
			if child is Label or "Countdown" in child.name:
				child.queue_free()

	GameState.set_phase(GameState.RacePhase.PRE_MATCH)
	
	# Trigger your new, unified GameUI countdown
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui and game_ui.has_method("run_countdown"):
		game_ui.run_countdown()
		# Wait for the visual countdown to finish (3 seconds)
		await get_tree().create_timer(3.0).timeout
		
	GameState.set_phase(GameState.RacePhase.RACING)

func _process(delta: float) -> void:
	if GameState.is_racing():
		time_left -= delta
		if time_left <= 0.0 and not results_shown:
			time_left = 0.0
			_finish_race("time_up")
			
		GameState.match_timer = time_left
		
		# game_ui.gd listens to this signal to update its text
		if GameState.has_signal("match_timer_updated"):
			GameState.match_timer_updated.emit(time_left)

func _finish_race(reason: String) -> void:
	if results_shown: return
	results_shown = true
	GameState.win_reason = reason
	GameState.set_phase(GameState.RacePhase.FINISHED)
	
	if results_menu:
		results_menu.show()
