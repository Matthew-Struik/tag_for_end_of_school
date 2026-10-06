extends Node

const PORT := 7777
const MAX_PLAYERS := 30

const NORMAL_MODE := 0
const INFECTION_MODE := 1
const GUN_MODE := 2

const GUN_RANGE := 40.0

const SECRET_CODE := "1267"

@export var player_scene: PackedScene
@export var npc_scene: PackedScene
@export var minimum_tag_players: int = 2

var players: Dictionary = {}
var infected_players: Dictionary = {}

var game_mode: int = NORMAL_MODE
var game_started: bool = false
var it_player_id: int = -1
var tag_cooldown_until: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)


# =========================================================
# HOST
# =========================================================

func leave_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	tag_cooldown_until.clear()
	infected_players.clear()
	game_started = false
	it_player_id = -1

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


func is_gun_mode() -> bool:
	return game_mode == GUN_MODE


## Host-only: turns the match into a Gun Game if the typed code matches.
func apply_code(code: String) -> bool:

	if not multiplayer.is_server():
		return false

	if game_started:
		return false

	if code.strip_edges() != SECRET_CODE:
		return false

	game_mode = GUN_MODE

	print("FUN MODE activated!")

	set_game_mode.rpc(game_mode)

	return true


# =========================================================
# START GAME
# =========================================================

func start_game() -> void:

	if not multiplayer.is_server():
		return

	if game_started:
		return

	if players.size() < minimum_tag_players:
		if players.size() == 1 and multiplayer.is_server():
			_spawn_solo_bot()
		else:
			print("Need a player to start a tag round!")
			return

	game_started = true

	infected_players.clear()
	it_player_id = -1

	var ids: Array = players.keys()

	var first_id: int = int(ids[rng.randi_range(0, ids.size() - 1)])
	if _has_solo_bot():
		first_id = multiplayer.get_unique_id()

	it_player_id = first_id


	# =====================================================
	# NORMAL MODE
	# =====================================================

	if game_mode == NORMAL_MODE or game_mode == GUN_MODE:
		for id in ids:
			if players[id].has_meta("solo_bot"):
				players[id].set_it(id == first_id)
			else:
				set_player_it.rpc(id, id == first_id)


	# =====================================================
	# INFECTION MODE
	# =====================================================

	elif game_mode == INFECTION_MODE:

		infected_players[first_id] = true

		for id in ids:
			if players[id].has_meta("solo_bot"):
				players[id].set_it(id == first_id)
			else:
				set_player_it.rpc(id, id == first_id)


	start_game_for_everyone.rpc()

	print("GAME STARTED")


func _has_solo_bot() -> bool:
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node.has_meta("solo_bot"):
			return true
	return false


func _spawn_solo_bot() -> void:
	if npc_scene == null:
		push_error("Cannot start solo: NPC scene is not assigned.")
		return
	var npc_id: int = int(Time.get_ticks_msec())
	var bot: Node3D = npc_scene.instantiate() as Node3D
	if bot == null:
		return
	bot.name = "SoloBot_%s" % npc_id
	add_child(bot)
	bot.global_position = Vector3(58.0, 1.5, 0.0)
	bot.set_meta("solo_bot", true)
	bot.set_meta("solo_tag_id", npc_id)
	bot.add_to_group("players")
	if bot.get_node_or_null("UsernameLabel") is Label3D:
		(bot.get_node("UsernameLabel") as Label3D).text = "Bot"
	# Player ids for this match include the host player and a reserved bot id.
	var host_id: int = multiplayer.get_unique_id()
	var host_player: Node = players.get(host_id)
	if host_player == null:
		return
	# Keep bot separate from network players but register its tag state for solo.
	players[npc_id] = bot


@rpc("authority", "call_local", "reliable")
func start_game_for_everyone() -> void:

	game_started = true

	for player in players.values():

		if player.has_meta("solo_bot") and player.has_method("set_solo_game_started"):
			player.set_solo_game_started(true)
		elif player.has_method("set_game_started"):
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
			var existing_player: Node = players[existing_id]
			var existing_name: String = "Player %s" % existing_id
			if existing_player.has_method("get_display_username"):
				existing_name = str(existing_player.call("get_display_username"))
			set_player_username.rpc_id(id, int(existing_id), existing_name)



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
	# Clients choose their own local display name; inform the server and other peers.
	var requested_name: String = ""
	if not multiplayer.is_server() and id == multiplayer.get_unique_id():
		var local_lobby: Node = get_tree().current_scene.get_node_or_null("NetworkManager/CanvasLayer")
		if local_lobby != null:
			requested_name = str(local_lobby.get_meta("profile_username", "Player %s" % id))

	if players.has(id):
		if not requested_name.is_empty():
			players[id].call("set_display_username", requested_name)
			register_player_username.rpc_id(1, id, requested_name)
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

	# Place players evenly around a ring in the open area, clear of the
	# central platform, cover walls and pillars.
	var angle: float = TAU * float(spawn_number) / 20.0
	var spawn_radius: float = 52.0

	player.global_position = Vector3(
		cos(angle) * spawn_radius,
		1.5,
		sin(angle) * spawn_radius
	)

	players[id] = player
	var profile_username: String = "Player %s" % id
	var lobby: Node = get_tree().current_scene.get_node_or_null("NetworkManager/CanvasLayer")
	if id == multiplayer.get_unique_id() and lobby != null:
		profile_username = str(lobby.get_meta("profile_username", profile_username))
	elif not requested_name.is_empty():
		profile_username = requested_name
	if player.has_method("set_display_username"):
		player.call("set_display_username", profile_username)
	player.call("set_display_username", profile_username)
	if not multiplayer.is_server() and id == multiplayer.get_unique_id():
		register_player_username.rpc_id(1, id, profile_username)
	if multiplayer.is_server():
		for existing_id: Variant in players.keys():
			if int(existing_id) == id:
				continue
			var existing_player: Node = players[existing_id]
			var existing_name: String = "Player %s" % existing_id
			if existing_player.has_method("get_display_username"):
				existing_name = str(existing_player.call("get_display_username"))
			set_player_username.rpc_id(id, int(existing_id), existing_name)

	print("Spawned Player ", id)


@rpc("any_peer", "reliable")
func register_player_username(player_id: int, username: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != player_id or not players.has(player_id):
		return
	set_player_username(player_id, username)
	for peer_id: int in multiplayer.get_peers():
		if peer_id != sender_id:
			set_player_username.rpc_id(peer_id, player_id, username)


@rpc("any_peer", "call_remote", "reliable")
func set_player_username(player_id: int, username: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	if players.has(player_id) and players[player_id].has_method("set_display_username"):
		players[player_id].call("set_display_username", username)


# =========================================================
# NPC SPAWNING (host only)
# =========================================================

func spawn_npc() -> void:
	if not multiplayer.is_server() or npc_scene == null:
		return
	var npc_id: int = randi()
	spawn_npc_for_everyone.rpc(npc_id, Vector3(rng.randf_range(-54.0, 54.0), 1.5, rng.randf_range(-54.0, 54.0)))

@rpc("authority", "call_local", "reliable")
func spawn_npc_for_everyone(npc_id: int, spawn_position: Vector3) -> void:
	var node_name: String = "NPC_%s" % npc_id
	if has_node(node_name):
		return
	var npc: Node3D = npc_scene.instantiate() as Node3D
	if npc == null:
		return
	npc.name = node_name
	add_child(npc)
	npc.global_position = spawn_position
	npc.set_multiplayer_authority(1)

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

	# Validate remote requests against their actual sender; direct server-local requests
	# use sender ID 0 when the host itself tags.
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != requester_id:
		return
	if sender_id == 0 and not multiplayer.is_server():
		return

	if not players.has(requester_id):
		return

	if not players.has(target_id):
		return

	if requester_id == target_id:
		return

	var cooldown_left: float = float(tag_cooldown_until.get(requester_id, 0.0)) - Time.get_ticks_msec() / 1000.0
	if cooldown_left > 0.0:
		return

	var requester: CharacterBody3D = players[requester_id] as CharacterBody3D
	var target: CharacterBody3D = players[target_id] as CharacterBody3D

	var distance: float = requester.global_position.distance_to(target.global_position)
	var max_distance: float = 8.0
	if game_mode == GUN_MODE:
		max_distance = GUN_RANGE

	if distance > max_distance:
		print("Tag rejected: distance %.2f > %.2f" % [distance, max_distance])
		return

	print("Tag request accepted: %d -> %d (%.2f units)" % [requester_id, target_id, distance])

	# =====================================================
	# NORMAL MODE
	# =====================================================

	if game_mode == GUN_MODE:
		if not requester.is_it:
			return
		var upgraded_index: int = mini(requester.weapon_index + 1, GunCatalog.get_weapon_count() - 1)
		set_weapon_index.rpc(requester_id, upgraded_index)
		set_player_it.rpc(requester_id, false)
		set_player_it.rpc(target_id, true)
		it_player_id = target_id
		tag_cooldown_until[target_id] = Time.get_ticks_msec() / 1000.0 + 5.0
		print("Fun Mode: Player ", requester_id, " unlocked ", GunCatalog.get_weapon(upgraded_index)["name"])
		return

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
		tag_cooldown_until[target_id] = Time.get_ticks_msec() / 1000.0 + 5.0

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
		tag_cooldown_until[target_id] = Time.get_ticks_msec() / 1000.0 + 5.0

		print(
			"Infected Player ",
			target_id
		)

		# Everyone infected?
		if infected_players.size() >= players.size():

			game_over.rpc()


@rpc("authority", "call_local", "reliable")
func set_weapon_index(player_id: int, weapon_index: int) -> void:
	if not players.has(player_id):
		return
	var player: Node = players[player_id]
	if player.has_method("set_weapon_index"):
		player.set_weapon_index(weapon_index)


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
	if players[player_id].has_meta("solo_bot"):
		players[player_id].set_it(value)
		return

	var player: Node = players[player_id]

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

	print("Round Over")
