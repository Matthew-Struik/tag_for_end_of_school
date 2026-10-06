extends CanvasLayer

## Counts down a 3-minute timer for every round. It starts automatically
## when the match starts and ends the round when time runs out.

const ROUND_TIME := 180.0  # 3 minutes

@export var network_manager_path: NodePath

@onready var time_label: Label = $TimeLabel
@onready var message_label: Label = $MessageLabel
@onready var players_label: Label = $PlayersLabel

var network_manager: Node
var time_left := ROUND_TIME
var running := false
var _was_started := false


func _ready() -> void:
	network_manager = get_node_or_null(network_manager_path)
	message_label.visible = false
	time_left = ROUND_TIME
	_update_label()


func _process(delta: float) -> void:
	if network_manager == null:
		return

	_update_player_count()

	var started: bool = network_manager.get("game_started")

	# A new round begins when the match starts.
	if started and not _was_started:
		_start_round()
	elif not started and _was_started:
		_stop_round()

	_was_started = started

	if not running:
		return

	time_left -= delta

	if time_left <= 0.0:
		time_left = 0.0
		_end_round()

	_update_label()


func _start_round() -> void:
	time_left = ROUND_TIME
	running = true
	message_label.visible = false
	_update_label()


func _stop_round() -> void:
	running = false


func _end_round() -> void:
	running = false
	message_label.text = "Ronde voorbij!"
	message_label.visible = true

	# Only the host ends the round for everyone (uses the existing flow).
	if multiplayer.is_server():
		network_manager.call("game_over")


func _update_label() -> void:
	var total: int = int(ceil(time_left))
	var minutes: int = int(total / 60.0)
	var seconds: int = total % 60
	time_label.text = "%d:%02d" % [minutes, seconds]


func _update_player_count() -> void:
	var players: Variant = network_manager.get("players")
	var count: int = 0

	if players is Dictionary:
		count = players.size()

	players_label.text = "Spelers: %d" % count