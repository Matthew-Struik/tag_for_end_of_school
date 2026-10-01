extends Node

const PORT := 7777
const MAX_PLAYERS := 20

@export var player_scene: PackedScene

var players := {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)


# HOST GAME
func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()

	var error := peer.create_server(PORT, MAX_PLAYERS)

	if error != OK:
		print("Could not start server: ", error)
		return

	multiplayer.multiplayer_peer = peer

	print("Server started!")

	# Spawn host
	_spawn_player(multiplayer.get_unique_id())


# JOIN GAME
func join_game(ip_address: String) -> void:
	var peer := ENetMultiplayerPeer.new()

	var error := peer.create_client(ip_address, PORT)

	if error != OK:
		print("Could not connect: ", error)
		return

	multiplayer.multiplayer_peer = peer

	print("Connecting to ", ip_address)


# WHEN A PLAYER CONNECTS
func _player_connected(id: int) -> void:
	print("Player connected: ", id)

	if multiplayer.is_server():

		# Spawn the new player for everyone
		spawn_player.rpc(id)

		# Tell the new player about players
		# that are already in the game
		for existing_id in players:
			spawn_player.rpc_id(id, existing_id)


# WHEN A PLAYER LEAVES
func _player_disconnected(id: int) -> void:
	print("Player disconnected: ", id)

	if players.has(id):
		players[id].queue_free()
		players.erase(id)


# SPAWN PLAYER
@rpc("authority", "call_local", "reliable")
func spawn_player(id: int) -> void:
	_spawn_player(id)


func _spawn_player(id: int) -> void:

	# Don't spawn the same player twice
	if players.has(id):
		return

	var player = player_scene.instantiate()

	player.name = "Player_" + str(id)

	add_child(player)

	# Give this player their multiplayer authority
	player.set_multiplayer_authority(id)

	# Put the player in the "players" group
	player.add_to_group("players")

	# Give players different starting positions
	player.global_position = Vector3(
		(id % 5) * 3.0,
		1.0,
		(id % 5) * 3.0
	)

	# Save the player
	players[id] = player

	print("Spawned player ", id)
