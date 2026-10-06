extends CharacterBody3D

const WALK_SPEED: float = 4.0
const RUN_SPEED: float = 7.5
const JUMP_VELOCITY: float = 5.5
const ARENA_HALF_SIZE: float = 54.0
const OBSTACLE_RADIUS: float = 4.0

var target_position: Vector3 = Vector3.ZERO
var direction_timer: float = 0.0
var jump_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var is_it: bool = false
var game_started: bool = false
var username_label: Label3D


func set_it(value: bool) -> void:
	is_it = value
	var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.15, 0.12) if value else Color(0.2, 0.45, 1.0)
		mesh_instance.material_override = material


func set_solo_game_started(value: bool) -> void:
	game_started = value

func _ready() -> void:
	username_label = Label3D.new()
	username_label.name = "UsernameLabel"
	username_label.position = Vector3(0.0, 1.35, 0.0)
	username_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	username_label.no_depth_test = true
	username_label.font_size = 48
	username_label.pixel_size = 0.006
	username_label.outline_size = 8
	username_label.text = "Bot"
	add_child(username_label)
	rng.randomize()
	_choose_target()

func _physics_process(delta: float) -> void:
	if has_meta("solo_bot"):
		if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
			return
		if not game_started:
			return
		_run_solo_bot(delta)
		return
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if not game_started:
		return
	_wander(delta)
	_sync_position.rpc(global_position)


func _run_solo_bot(delta: float) -> void:
	var player_node: Node = get_parent().get_node_or_null("Player_%s" % multiplayer.get_unique_id())
	if not player_node is CharacterBody3D:
		return
	var player: CharacterBody3D = player_node as CharacterBody3D
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var movement: Vector3 = to_player.normalized() if is_it else -to_player.normalized()
	if is_it and distance <= 2.0:
		get_parent().call("request_tag", int(get_meta("solo_tag_id")), player.get_multiplayer_authority())
	if is_it or distance < 13.0:
		velocity.x = movement.x * RUN_SPEED
		velocity.z = movement.z * RUN_SPEED
		jump_timer -= delta
		if jump_timer <= 0.0 and _obstacle_ahead(movement):
			velocity.y = JUMP_VELOCITY
			jump_timer = 1.0
		_apply_gravity(delta)
		move_and_slide()
		return
	_wander(delta)

func _wander(delta: float) -> void:
	direction_timer -= delta
	if direction_timer <= 0.0 or global_position.distance_to(target_position) < 1.2:
		_choose_target()
	var direction: Vector3 = target_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		velocity.x = direction.normalized().x * WALK_SPEED
		velocity.z = direction.normalized().z * WALK_SPEED
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _obstacle_ahead(direction: Vector3) -> bool:
	if direction.length_squared() < 0.01 or not is_on_floor():
		return false
	var ray_start: Vector3 = global_position + Vector3.UP * 0.5
	var ray_end: Vector3 = ray_start + direction.normalized() * 1.6
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _choose_target() -> void:
	direction_timer = rng.randf_range(2.0, 5.0)
	target_position = Vector3(rng.randf_range(-ARENA_HALF_SIZE + 6.0, ARENA_HALF_SIZE - 6.0), 0.0, rng.randf_range(-ARENA_HALF_SIZE + 6.0, ARENA_HALF_SIZE - 6.0))

@rpc("authority", "call_remote", "unreliable")
func _sync_position(npc_position: Vector3) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		global_position = npc_position

