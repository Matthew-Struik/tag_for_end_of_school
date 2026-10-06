extends CanvasLayer

@onready var network_manager = get_parent()

@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton
@onready var start_button: Button = $StartButton
@onready var ip_input: LineEdit = $IPInput
@onready var game_mode: OptionButton = $GameMode
@onready var status_label: Label = $Label
@onready var code_input: LineEdit = $CodeInput
@onready var code_button: Button = $CodeButton


func _ready() -> void:
	var account_gate_scene: PackedScene = load("res://account_gate.tscn") as PackedScene
	if account_gate_scene != null:
		var account_gate: CanvasLayer = account_gate_scene.instantiate() as CanvasLayer
		get_tree().current_scene.call_deferred("add_child", account_gate)

	# Game modes
	game_mode.clear()

	game_mode.add_item("Normal Mode")
	game_mode.add_item("Infection Mode")

	game_mode.select(0)

	# Start hidden until host
	start_button.visible = false
	code_input.visible = false
	code_button.visible = false
	code_input.secret = false
	code_input.max_length = 4
	code_input.placeholder_text = "Enter the code for Fun Mode"

	# Connections
	host_button.pressed.connect(host_game)
	join_button.pressed.connect(join_game)
	start_button.pressed.connect(start_game)
	code_button.pressed.connect(_use_code)
	code_input.text_submitted.connect(_on_code_submitted)

	game_mode.item_selected.connect(
		game_mode_changed
	)


# =========================================================
# HOST
# =========================================================

func host_game() -> void:

	network_manager.host_game()

	host_button.disabled = true
	join_button.disabled = true
	ip_input.editable = false

	game_mode.visible = true
	game_mode.disabled = false

	start_button.visible = true
	code_input.visible = true
	code_button.visible = true

	status_label.text = (
		"Lobby! Choose a mode and press START."
	)


# =========================================================
# JOIN
# =========================================================

func join_game() -> void:

	var ip: String = ip_input.text.strip_edges()

	if ip.is_empty():

		status_label.text = (
			"Enter an IP address!"
		)

		return


	network_manager.join_game(ip)

	host_button.disabled = true
	join_button.disabled = true
	ip_input.editable = false

	# Clients cannot choose mode.
	game_mode.disabled = true

	start_button.visible = false
	code_input.visible = false
	code_button.visible = false

	status_label.text = (
		"Waiting for host..."
	)


# =========================================================
# GAME MODE
# =========================================================

func game_mode_changed(index: int) -> void:

	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return


	if index == 0:

		network_manager.set_selected_game_mode(
			network_manager.NORMAL_MODE
		)

		status_label.text = (
			"Normal Mode selected!"
		)

	else:

		network_manager.set_selected_game_mode(
			network_manager.INFECTION_MODE
		)

		status_label.text = (
			"Infection Mode selected!"
		)


# =========================================================
# START
# =========================================================

func start_game() -> void:

	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return

	network_manager.start_game()


# =========================================================
# GAME OVER
# =========================================================

func game_over() -> void:

	status_label.text = (
		"EVERYONE IS INFECTED!"
	)

	game_mode.disabled = true

	start_button.visible = true


# =========================================================
# VISIBILITY
# =========================================================

func _process(_delta: float) -> void:
	# Hide the lobby text and buttons while a match is running so the
	# gameplay view stays clean. They reappear when the round ends.
	visible = not network_manager.game_started


# =========================================================
# SECRET CODE (host only)
# =========================================================

func _use_code() -> void:
	_try_code(code_input.text)


func _on_code_submitted(text: String) -> void:
	_try_code(text)


func _try_code(code: String) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return

	if network_manager.apply_code(code):
		status_label.text = "Fun Mode activated!"
		code_input.editable = false
	else:
		status_label.text = "Verkeerde code."

