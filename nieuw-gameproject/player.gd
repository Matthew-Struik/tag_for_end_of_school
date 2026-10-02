extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const TAG_DISTANCE := 2.5

@onready var camera: Camera3D = $Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var camera_pitch := 0.0
var is_it := false
var game_started := false


func _ready() -> void:
	camera.current = is_multiplayer_authority()

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	update_color()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Mouse look
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

			camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
			camera_pitch = clamp(camera_pitch, -1.5, 1.5)

			camera.rotation.x = camera_pitch

	# Keyboard
	if event is InputEventKey:
		if event.pressed and not event.echo:

			# ESC = mouse on/off
			if event.keycode == KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

			# E = tag
			if event.keycode == KEY_E:
				try_tag()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement
	if game_started:
		var input_dir := Vector2.ZERO

		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1.0

		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1.0

		if Input.is_key_pressed(KEY_W):
			input_dir.y -= 1.0

		if Input.is_key_pressed(KEY_S):
			input_dir.y += 1.0

		input_dir = input_dir.normalized()

		var direction := (
			transform.basis *
			Vector3(input_dir.x, 0.0, input_dir.y)
		).normalized()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				SPEED * 8.0 * delta
			)

			velocity.z = move_toward(
				velocity.z,
				0.0,
				SPEED * 8.0 * delta
			)

		# Space = jump
		if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
			velocity.y = JUMP_VELOCITY

	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# Sync movement
	if game_started:
		sync_position.rpc(
			global_position,
			rotation.y
		)


@rpc("unreliable", "any_peer", "call_remote")
func sync_position(pos: Vector3, rot_y: float) -> void:
	if is_multiplayer_authority():
		return

	global_position = pos
	rotation.y = rot_y


# =====================================================
# GAME START
# =====================================================

func set_game_started(value: bool) -> void:
	game_started = value

	if not is_multiplayer_authority():
		return

	if value:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# =====================================================
# TAGGING
# =====================================================

func try_tag() -> void:
	if not game_started:
		return

	# Only red players can tag
	if not is_it:
		return

	var network_manager = get_parent()

	var closest_player_id := -1
	var closest_distance: float = TAG_DISTANCE

	for player in get_tree().get_nodes_in_group("players"):
		if player == self:
			continue

		if player.is_it:
			continue

		var distance: float = global_position.distance_to(
			player.global_position
		)

		if distance <= closest_distance:
			closest_distance = distance
			closest_player_id = player.get_multiplayer_authority()

	if closest_player_id != -1:
		network_manager.request_tag.rpc_id(
			1,
			get_multiplayer_authority(),
			closest_player_id
		)


# =====================================================
# IT / BLUE
# =====================================================

func set_it(value: bool) -> void:
	is_it = value
	update_color()


func update_color() -> void:
	var material := StandardMaterial3D.new()

	if is_it:
		# RED = IT / INFECTED
		material.albedo_color = Color(1.0, 0.0, 0.0)
	else:
		# BLUE = NOT IT
		material.albedo_color = Color(0.0, 0.2, 1.0)

	mesh.material_override = material
