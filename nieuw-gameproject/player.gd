extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003

@onready var camera: Camera3D = $Camera3D

var camera_pitch := 0.0
var tagged := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Only the player controlling this character gets the camera.
	camera.current = is_multiplayer_authority()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

			camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
			camera_pitch = clamp(camera_pitch, -1.5, 1.5)

			camera.rotation.x = camera_pitch

	# ESC toggles mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var input_dir := Input.get_vector(
		"left",
		"right",
		"forword",
		"backwords"
	)

	var direction := (
		transform.basis *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Send our position to the other players
	send_position.rpc(global_position, rotation.y)


@rpc("unreliable", "any_peer", "call_remote")
func send_position(pos: Vector3, rot_y: float) -> void:
	if is_multiplayer_authority():
		return

	global_position = pos
	rotation.y = rot_y

const TAG_DISTANCE := 2.0
var is_it := false


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if Input.is_action_just_pressed("tag"):
		try_tag()

func try_tag() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if player == self:
			continue

		var distance := global_position.distance_to(
			player.global_position
		)

		if distance <= TAG_DISTANCE:
			tag_player.rpc(player.name)
			return

@rpc("any_peer", "call_local", "reliable")
func tag_player(player_name: String) -> void:
	var player = get_node_or_null("../" + player_name)

	if player == null:
		return

	player.is_it = true

	print(player_name, " is IT!")
