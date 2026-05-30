extends Node
# AudioManager (autoload singleton)
# Plays sound effects for the race. Wired to GameState signals so that
# collisions, sabotage, and the finish are automatic; jump / slide / countdown
# are triggered directly by the player and main scripts via play_sfx().

const SFX_PATHS := {
	"jump":      "res://assets/audio/jump.wav",
	"slide":     "res://assets/audio/slide.wav",
	"collision": "res://assets/audio/collision.wav",
	"sabotage":  "res://assets/audio/sabotage.wav",
	"beep":      "res://assets/audio/beep.wav",
	"go":        "res://assets/audio/go.wav",
	"finish":    "res://assets/audio/finish.wav",
}

const POOL_SIZE := 8        # how many sounds can overlap at once
const MASTER_DB := 0.0      # overall volume trim (dB)

const MUSIC_PATH := "res://assets/audio/music.wav"
const MUSIC_DB   := -10.0   # music sits behind SFX; tweak to taste

var _streams: Dictionary = {}          # name -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing while tree is paused (results screen)

	# Pre-load every sound once.
	for key in SFX_PATHS.keys():
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			push_warning("[AudioManager] Missing sound: " + path)

	# Build a small pool of players so overlapping cues don't cut each other off.
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = MASTER_DB
		add_child(p)
		_players.append(p)

	# Hook into the shared game state. These fire automatically during the race.
	if not GameState.collision_event.is_connected(_on_collision):
		GameState.collision_event.connect(_on_collision)
	if not GameState.sabotage_triggered.is_connected(_on_sabotage):
		GameState.sabotage_triggered.connect(_on_sabotage)
	if not GameState.race_finished.is_connected(_on_race_finished):
		GameState.race_finished.connect(_on_race_finished)
	# Music setup (separate from the SFX pool so it can loop independently).
	_setup_music()
	if not GameState.phase_changed.is_connected(_on_music_phase_changed):
		GameState.phase_changed.connect(_on_music_phase_changed)

# Public: play a one-shot sound by key (see SFX_PATHS). Optional volume trim in dB.
func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if not _streams.has(key):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key]
	p.volume_db = MASTER_DB + volume_db
	p.play()

# ── Signal handlers ────────────────────────────────────────────────────────
func _on_collision(_racer: String, obstacle_type: String) -> void:
	# A sabotage hit reads as a heavier impact; everything else is a normal crash.
	if obstacle_type == "SABOTAGE":
		play_sfx("collision", 2.0)
	else:
		play_sfx("collision")

func _on_sabotage(_by_racer: String) -> void:
	play_sfx("sabotage")

func _on_race_finished(_winner: String) -> void:
	play_sfx("finish", 1.0)

# ── Music ───────────────────────────────────────────────────────────────────
func _setup_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		push_warning("[AudioManager] Music not found: " + MUSIC_PATH)
		return
	var stream := load(MUSIC_PATH) as AudioStreamWAV
	if stream == null:
		push_warning("[AudioManager] Could not load music as AudioStreamWAV.")
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD   # seamless loop
	_music_player = AudioStreamPlayer.new()
	_music_player.stream    = stream
	_music_player.volume_db = MUSIC_DB
	_music_player.bus       = "Master"
	add_child(_music_player)
	print("[AudioManager] Music player ready.")

func _on_music_phase_changed(phase) -> void:
	if _music_player == null:
		return
	# if/elif avoids the enum-vs-int type mismatch that can silently break match arms.
	if phase == GameState.RacePhase.RACING:
		_music_player.volume_db = MUSIC_DB
		_music_player.play()
		print("[AudioManager] Music started.")
	elif phase == GameState.RacePhase.FINISHED:
		# Fade out over 1.5 s while the finish fanfare plays.
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -60.0, 1.5)
		tw.tween_callback(_music_player.stop)
	elif phase == GameState.RacePhase.PRE_MATCH:
		# Back to menu — stop cleanly and reset volume for the next race.
		_music_player.stop()
		_music_player.volume_db = MUSIC_DB
