extends Node

const PORT := 7777
const MAX_PLAYERS := 20

const NORMAL_MODE := 0
const INFECTION_MODE := 1

@export var player_scene: PackedScene

var players: Dictionary = {}
var infected_players: Dictionary = {}

var game_mode: int = NORMAL_MODE
var game_started := false
var it_player_id := -1

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()

	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)


# =========================================================
# HOST
# =========================================================

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()

	var error := peer.create_server(PORT, MAX_PLAYERS)

	if error != OK:
		print("Could not start server. Error: ", error)
		return

	multiplayer.multiplayer_peer = peer

	print("SERVER STARTED")
	print("IP: 127.0.0.1")

	_spawn_player(multiplayer.get_unique_id())


# =========================================================
# JOIN
# =========================================================

func join_game(ip: String) -> void:

	if ip.is_empty():
		print("IP is empty!")
		return

	var peer := ENetMultiplayerPeer.new()

	var error := peer.create_client(ip, PORT)

	if error != OK:
		print("Could not connect. Error: ", error)
		return

	multiplayer.multiplayer_peer = peer

	print("Connecting to ", ip)


# =========================================================
# GAME MODE
# =========================================================

func set_selected_game_mode(mode: int) -> void:

	if not multiplayer.is_server():
		return

	if game_started:
		return

	if mode != NORMAL_MODE and mode != INFECTION_MODE:
		return

	game_mode = mode

	print("Game mode changed to: ", game_mode)

	set_game_mode.rpc(game_mode)


@rpc("authority", "call_local", "reliable")
func set_game_mode(mode: int) -> void:

	game_mode = mode


# =========================================================
# START GAME
# =========================================================

func start_game() -> void:

	if not multiplayer.is_server():
		return

	if game_started:
		return

	if players.size() < 1:
		print("Need at least one player!")
		return

	game_started = true

	infected_players.clear()
	it_player_id = -1

	var ids: Array = players.keys()

	var first_id: int = ids[
		rng.randi_range(0, ids.size() - 1)
	]

	it_player_id = first_id


	# =====================================================
	# NORMAL MODE
	# =====================================================

	if game_mode == NORMAL_MODE:

		for id in ids:

			if id == first_id:
				set_player_it.rpc(id, true)
			else:
				set_player_it.rpc(id, false)


	# =====================================================
	# INFECTION MODE
	# =====================================================

	elif game_mode == INFECTION_MODE:

		infected_players[first_id] = true

		for id in ids:

			if id == first_id:
				set_player_it.rpc(id, true)
			else:
				set_player_it.rpc(id, false)


	start_game_for_everyone.rpc()

	print("GAME STARTED")


@rpc("authority", "call_local", "reliable")
func start_game_for_everyone() -> void:

	game_started = true

	for player in players.values():

		if player.has_method("set_game_started"):
			player.set_game_started(true)
		else:
			print(
				"ERROR: ",
				player.name,
				" does not have set_game_started()"
			)


# =========================================================
# PLAYER CONNECTED
# =========================================================

func _player_connected(id: int) -> void:

	print("Player connected: ", id)

	if game_started:

		multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	spawn_player.rpc(id)

	set_game_mode.rpc_id(id, game_mode)

	for existing_id in players.keys():

		if existing_id != id:
			spawn_player.rpc_id(id, existing_id)


# =========================================================
# PLAYER DISCONNECTED
# =========================================================

func _player_disconnected(id: int) -> void:

	print("Player disconnected: ", id)

	if players.has(id):

		if is_instance_valid(players[id]):
			players[id].queue_free()

		players.erase(id)

	infected_players.erase(id)

	if id == it_player_id:
		it_player_id = -1


# =========================================================
# SPAWN PLAYER
# =========================================================

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int) -> void:

	_spawn_player(id)


func _spawn_player(id: int) -> void:

	if players.has(id):
		return

	if player_scene == null:

		print("ERROR: Player Scene is NOT assigned!")
		return


	var player = player_scene.instantiate()

	player.name = "Player_" + str(id)

	# IMPORTANT:
	# Player.tscn root must have Player.gd.
	player.set_multiplayer_authority(id)

	add_child(player)

	player.add_to_group("players")


	# =====================================================
	# SPAWN POSITION
	# =====================================================

	var spawn_number: int = abs(id) % 20

	# X position
	var spawn_x: float = (
		float(spawn_number % 5) * 6.0 - 12.0
	)

	# IMPORTANT:
	# Use 5.0 instead of 5 to avoid integer division warning.
	var spawn_z: float = (
		float(spawn_number) / 5.0 * 6.0 - 12.0
	)

	player.global_position = Vector3(
		spawn_x,
		1.0,
		spawn_z
	)

	players[id] = player

	print("Spawned Player ", id)


# =========================================================
# TAGGING
# =========================================================

@rpc("any_peer", "reliable")
func request_tag(
	requester_id: int,
	target_id: int
) -> void:

	if not multiplayer.is_server():
		return

	if not game_started:
		return

	# Make sure the request really came from that player.
	if multiplayer.get_remote_sender_id() != requester_id:
		return

	if not players.has(requester_id):
		return

	if not players.has(target_id):
		return

	if requester_id == target_id:
		return


	var requester: CharacterBody3D = players[requester_id]
	var target: CharacterBody3D = players[target_id]

	var distance: float = (
		requester.global_position.distance_to(
			target.global_position
		)
	)

	if distance > 2.5:
		return


	# =====================================================
	# NORMAL MODE
	# =====================================================

	if game_mode == NORMAL_MODE:

		if not requester.is_it:
			return

		# Old IT becomes blue.
		set_player_it.rpc(
			requester_id,
			false
		)

		# New IT becomes red.
		set_player_it.rpc(
			target_id,
			true
		)

		it_player_id = target_id

		print(
			"Normal Mode: Player ",
			target_id,
			" is IT!"
		)

		return


	# =====================================================
	# INFECTION MODE
	# =====================================================

	if game_mode == INFECTION_MODE:

		# Requester must be infected.
		if not infected_players.has(requester_id):
			return

		# Already infected.
		if infected_players.has(target_id):
			return

		# Infect target.
		infected_players[target_id] = true

		set_player_it.rpc(
			target_id,
			true
		)

		print(
			"Infected Player ",
			target_id
		)

		# Everyone infected?
		if infected_players.size() >= players.size():

			game_over.rpc()


# =========================================================
# PLAYER IT / BLUE
# =========================================================

@rpc("authority", "call_local", "reliable")
func set_player_it(
	player_id: int,
	value: bool
) -> void:

	if not players.has(player_id):
		return

	var player = players[player_id]

	if player.has_method("set_it"):

		player.set_it(value)

	else:

		print(
			"ERROR: Player.gd is not attached to ",
			player.name
		)


# =========================================================
# GAME OVER
# =========================================================

@rpc("authority", "call_local", "reliable")
func game_over() -> void:

	game_started = false

	for player in players.values():

		if player.has_method("set_game_started"):
			player.set_game_started(false)

	print("Infection Game Over")
