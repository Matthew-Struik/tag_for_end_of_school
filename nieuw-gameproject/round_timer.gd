extends CanvasLayer

const ROUND_TIME: float = 180.0

@export var network_manager_path: NodePath

@onready var time_label: Label = $TimeLabel
@onready var message_label: Label = $MessageLabel
@onready var players_label: Label = $PlayersLabel
@onready var role_label: Label = get_node_or_null("RoleLabel") as Label
@onready var crosshair: Control = get_node_or_null("Crosshair") as Control
@onready var gun_hint: Label = get_node_or_null("GunHint") as Label
@onready var mode_hint: Label = get_node_or_null("ModeHint") as Label

var network_manager: Node
var time_left: float = ROUND_TIME
var running: bool = false
var _was_started: bool = false

func _ready() -> void:
	network_manager = get_node_or_null(network_manager_path)
	message_label.visible = false
	_update_label()

func _process(delta: float) -> void:
	if network_manager == null:
		return
	_update_player_count()
	var started: bool = bool(network_manager.get("game_started"))
	var gun_mode: bool = bool(network_manager.call("is_gun_mode"))
	if role_label != null:
		_update_role_label(started)
	if crosshair != null:
		crosshair.visible = started and gun_mode
	if gun_hint != null:
		gun_hint.visible = started and gun_mode
	if mode_hint != null:
		mode_hint.visible = started and not gun_mode
		if mode_hint.visible:
			mode_hint.text = "TAG MODE — press E near another player to tag"
	if started and not _was_started:
		_start_round()
	elif not started and _was_started:
		running = false
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

func _end_round() -> void:
	running = false
	message_label.text = "Ronde voorbij!"
	message_label.visible = true
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		network_manager.call("game_over")

func _update_label() -> void:
	var total: int = int(ceil(time_left))
	time_label.text = "%d:%02d" % [int(total / 60.0), total % 60]

func _update_player_count() -> void:
	var players_value: Variant = network_manager.get("players")
	var count: int = players_value.size() if players_value is Dictionary else 0
	players_label.text = "Spelers: %d" % count

func _update_role_label(started: bool) -> void:
	role_label.visible = started
	if not started:
		return
	var players_value: Variant = network_manager.get("players")
	if not players_value is Dictionary:
		role_label.text = ""
		return
	for player_value: Variant in players_value.values():
		if player_value is Node and player_value.is_multiplayer_authority():
			var is_tagger: bool = bool(player_value.get("is_it"))
			role_label.text = "TAGGER" if is_tagger else "SURVIVOR"
			role_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2) if is_tagger else Color(0.35, 0.65, 1.0))
			return
	role_label.text = ""
