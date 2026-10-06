extends CharacterBody3D

const SPEED := 5.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const TAG_DISTANCE := 8.0
const GUN_RANGE := 40.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN_PER_SECOND := 32.0
const STAMINA_RECOVERY_PER_SECOND := 22.0
const GUN_CATALOG = preload("res://guns.gd")

@onready var camera: Camera3D = $Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var camera_visual: MeshInstance3D = get_node_or_null("CameraVisual") as MeshInstance3D

var camera_pitch := 0.0
var is_it := false
var game_started := false

var gun_pivot: Node3D
var muzzle: MeshInstance3D
var gun_cooldown := 0.0
var muzzle_time := 0.0
var stamina: float = MAX_STAMINA
var sprint_exhausted: bool = false
var stamina_bar: ProgressBar
var weapon_index: int = 0
var weapon_label: Label
var weapon_hud: CanvasLayer
var shooting: bool = false
var gun_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var username_label: Label3D
var display_username: String = "Player"
var third_person: bool = false
var third_person_camera: Camera3D


func _ready() -> void:
	gun_rng.randomize()
	camera.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		camera.position = Vector3(0.0, 0.7, 0.0)
		camera_pitch = -0.12
		camera.rotation = Vector3(camera_pitch, 0.0, 0.0)
		_build_third_person_camera()

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	update_color()
	if camera_visual != null:
		camera_visual.visible = false
	mesh.visible = not is_multiplayer_authority()
	_build_username_label()
	_build_stamina_bar()
	_build_gun()
	_update_gun()
	if is_multiplayer_authority() and OS.has_feature("mobile"):
		_build_mobile_controls()


func _build_third_person_camera() -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = "ThirdPersonPivot"
	pivot.position = Vector3(0.0, 0.65, 0.0)
	add_child(pivot)
	var spring_arm: SpringArm3D = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 4.0
	pivot.add_child(spring_arm)
	third_person_camera = Camera3D.new()
	third_person_camera.name = "ThirdPersonCamera"
	third_person_camera.current = false
	spring_arm.add_child(third_person_camera)
	pivot.rotation.x = camera_pitch


func _toggle_camera_view() -> void:
	third_person = not third_person
	camera.current = not third_person
	if third_person_camera != null:
		third_person_camera.current = third_person
	mesh.visible = third_person
	if camera_visual != null:
		camera_visual.visible = third_person


func get_display_username() -> String:
	return display_username


func set_display_username(username: String) -> void:
	display_username = username
	if username_label != null:
		username_label.text = username


func _build_username_label() -> void:
	username_label = Label3D.new()
	username_label.name = "UsernameLabel"
	username_label.position = Vector3(0.0, 1.35, 0.0)
	username_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	username_label.no_depth_test = true
	username_label.font_size = 48
	username_label.pixel_size = 0.006
	username_label.outline_size = 8
	username_label.modulate = Color(1.0, 1.0, 1.0)
	username_label.text = display_username
	add_child(username_label)


func _build_mobile_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MobileControls"
	layer.layer = 10
	add_child(layer)
	_add_touch_button(layer, "◀", "left", Vector2(32, -104), Vector2(72, 72))
	_add_touch_button(layer, "▶", "right", Vector2(188, -104), Vector2(72, 72))
	_add_touch_button(layer, "▲", "forword", Vector2(110, -180), Vector2(72, 72))
	_add_touch_button(layer, "▼", "backwords", Vector2(110, -104), Vector2(72, 72))
	_add_touch_button(layer, "JUMP", "jump", Vector2(-190, -110), Vector2(100, 78))
	_add_touch_button(layer, "TAG", "tag", Vector2(-190, -204), Vector2(100, 78))


func _add_touch_button(layer: CanvasLayer, caption: String, action: String, offset: Vector2, size: Vector2) -> void:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size = size
	button.anchor_left = 0.0 if offset.x >= 0.0 else 1.0
	button.anchor_right = button.anchor_left
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = offset.x
	button.offset_right = offset.x + size.x
	button.offset_top = offset.y
	button.offset_bottom = offset.y + size.y
	button.modulate = Color(1.0, 1.0, 1.0, 0.72)
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	layer.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		_toggle_camera_view()
		get_viewport().set_input_as_handled()
		return

	# Mouse look on PC and drag-to-look on touchscreens.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative)
	elif event is InputEventScreenDrag:
		# Reserve the left side of the screen for movement controls.
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.35:
			_apply_look(event.relative)

	# Left mouse = shoot (Gun Game only)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.pressed:
				shooting = true
				fire()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			shooting = false


func _apply_look(relative: Vector2) -> void:
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	camera_pitch -= relative.y * MOUSE_SENSITIVITY
	camera_pitch = clamp(camera_pitch, -0.55, 0.55)
	camera.rotation.x = camera_pitch
	var pivot: Node3D = get_node_or_null("ThirdPersonPivot") as Node3D
	if pivot != null:
		pivot.rotation.x = camera_pitch



func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_multiplayer_authority():
		return
	if game_started and Input.is_action_just_pressed("tag"):
		try_tag()

	_update_gun()

	if gun_cooldown > 0.0:
		gun_cooldown -= delta

	if shooting and game_started and is_it and _in_gun_mode():
		fire()

	if muzzle_time > 0.0:
		muzzle_time -= delta

		if muzzle_time <= 0.0 and muzzle != null:
			muzzle.visible = false

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement
	if game_started:
		var input_dir: Vector2 = Input.get_vector("left", "right", "forword", "backwords")

		# Sprint drains stamina to zero; once exhausted, running stays disabled
		# until the stamina bar has fully recovered.
		var current_speed: float = SPEED
		var is_moving: bool = input_dir.length_squared() > 0.0
		var wants_to_sprint: bool = Input.is_key_pressed(KEY_SHIFT) and is_moving
		var sprinting: bool = wants_to_sprint and not sprint_exhausted and stamina > 0.0

		if sprinting:
			current_speed = SPRINT_SPEED
			stamina = maxf(0.0, stamina - STAMINA_DRAIN_PER_SECOND * delta)
			if stamina <= 0.0:
				sprint_exhausted = true
		else:
			stamina = minf(MAX_STAMINA, stamina + STAMINA_RECOVERY_PER_SECOND * delta)
			if stamina >= MAX_STAMINA:
				sprint_exhausted = false
		_update_stamina_bar()

		var direction := (
			transform.basis *
			Vector3(input_dir.x, 0.0, input_dir.y)
		).normalized()

		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
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
		if Input.is_action_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	else:
		velocity.x = 0.0
		velocity.z = 0.0
		stamina = minf(MAX_STAMINA, stamina + STAMINA_RECOVERY_PER_SECOND * delta)
		_update_stamina_bar()

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
# STAMINA HUD
# =====================================================

func _build_stamina_bar() -> void:
	if not is_multiplayer_authority():
		return
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "StaminaHUD"
	hud_layer.layer = 6
	weapon_hud = hud_layer
	add_child(hud_layer)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = MAX_STAMINA
	stamina_bar.value = stamina
	stamina_bar.show_percentage = false
	var stamina_fill: StyleBoxFlat = StyleBoxFlat.new()
	stamina_fill.bg_color = Color(0.15, 0.85, 0.25)
	stamina_fill.corner_radius_top_left = 5
	stamina_fill.corner_radius_top_right = 5
	stamina_fill.corner_radius_bottom_left = 5
	stamina_fill.corner_radius_bottom_right = 5
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	var stamina_background: StyleBoxFlat = StyleBoxFlat.new()
	stamina_background.bg_color = Color(0.08, 0.1, 0.12, 0.9)
	stamina_background.corner_radius_top_left = 5
	stamina_background.corner_radius_top_right = 5
	stamina_background.corner_radius_bottom_left = 5
	stamina_background.corner_radius_bottom_right = 5
	stamina_bar.add_theme_stylebox_override("background", stamina_background)
	stamina_bar.anchor_left = 0.0
	stamina_bar.anchor_right = 0.0
	stamina_bar.anchor_top = 1.0
	stamina_bar.anchor_bottom = 1.0
	stamina_bar.offset_left = 24.0
	stamina_bar.offset_right = 324.0
	stamina_bar.offset_top = -45.0
	stamina_bar.offset_bottom = -25.0
	hud_layer.add_child(stamina_bar)
	var label: Label = Label.new()
	label.name = "StaminaLabel"
	label.text = "STAMINA — SHIFT"
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 0.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 24.0
	label.offset_right = 324.0
	label.offset_top = -70.0
	label.offset_bottom = -48.0
	hud_layer.add_child(label)


func _update_stamina_bar() -> void:
	if stamina_bar != null:
		stamina_bar.value = stamina


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
		print("Tag ignored: round is not running")
		return

	# Only red players can tag
	if not is_it:
		print("Tag ignored: only the tagger can tag")
		return

	var network_manager = get_parent()

	var closest_player_id: int = -1
	var closest_distance: float = TAG_DISTANCE

	for player: Node in get_tree().get_nodes_in_group("players"):
		if player == self or player.get("is_it") == true:
			continue
		if not player is CharacterBody3D:
			continue
		var other_player: CharacterBody3D = player as CharacterBody3D
		var distance: float = global_position.distance_to(other_player.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			if other_player.has_meta("solo_bot"):
				closest_player_id = int(other_player.get_meta("solo_tag_id"))
			else:
				closest_player_id = other_player.get_multiplayer_authority()

	if closest_player_id < 0:
		print("Tag failed: no other survivor is within %.1f m. Play with a second player, or use Escape > Spawn NPC to add a target." % TAG_DISTANCE)
		return

	var local_player_id: int = get_multiplayer_authority()
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		network_manager.request_tag(local_player_id, closest_player_id)
	else:
		network_manager.request_tag.rpc_id(1, local_player_id, closest_player_id)


# =====================================================
# IT / BLUE
# =====================================================

func set_weapon_index(value: int) -> void:
	weapon_index = clampi(value, 0, GUN_CATALOG.get_weapon_count() - 1)
	_update_weapon_model()
	_update_weapon_label()


func set_it(value: bool) -> void:
	is_it = value
	update_color()
	_update_gun()


func update_color() -> void:
	var material := StandardMaterial3D.new()

	if is_it:
		# RED = IT / INFECTED
		material.albedo_color = Color(1.0, 0.0, 0.0)
	else:
		# BLUE = NOT IT
		material.albedo_color = Color(0.0, 0.2, 1.0)

	mesh.material_override = material


# =====================================================
# GUN GAME
# =====================================================

func _in_gun_mode() -> bool:
	var network_manager = get_parent()

	if network_manager == null:
		return false

	return network_manager.is_gun_mode()


func _build_gun() -> void:
	gun_pivot = Node3D.new()
	gun_pivot.name = "Gun"
	camera.add_child(gun_pivot)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body.name = "GunBody"
	body_mesh.size = Vector3(0.12, 0.12, 0.6)
	body.mesh = body_mesh

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.12, 0.12, 0.14)
	body_material.metallic = 0.7
	body_material.roughness = 0.3
	body.material_override = body_material

	body.position = Vector3(0.28, -0.22, -0.5)
	gun_pivot.add_child(body)

	muzzle = MeshInstance3D.new()
	var muzzle_mesh := SphereMesh.new()
	muzzle_mesh.radius = 0.09
	muzzle_mesh.height = 0.18
	muzzle.mesh = muzzle_mesh

	var muzzle_material := StandardMaterial3D.new()
	muzzle_material.albedo_color = Color(1.0, 0.85, 0.3)
	muzzle_material.emission_enabled = true
	muzzle_material.emission = Color(1.0, 0.7, 0.2)
	muzzle_material.emission_energy_multiplier = 4.0
	muzzle.material_override = muzzle_material

	muzzle.position = Vector3(0.28, -0.22, -0.85)
	muzzle.visible = false
	gun_pivot.add_child(muzzle)

	gun_pivot.visible = false
	weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.anchor_left = 1.0
	weapon_label.anchor_right = 1.0
	weapon_label.anchor_top = 1.0
	weapon_label.anchor_bottom = 1.0
	weapon_label.offset_left = -240.0
	weapon_label.offset_right = -24.0
	weapon_label.offset_top = -100.0
	weapon_label.offset_bottom = -68.0
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_font_size_override("font_size", 22)
	weapon_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	weapon_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	weapon_label.add_theme_constant_override("outline_size", 4)
	if weapon_hud != null:
		weapon_hud.add_child(weapon_label)
	weapon_label.visible = false
	_update_weapon_label()


func _update_weapon_model() -> void:
	if gun_pivot == null:
		return
	var body: MeshInstance3D = gun_pivot.get_node_or_null("GunBody")
	if body == null:
		return
	var weapon: Dictionary = GUN_CATALOG.get_weapon(weapon_index)
	var gun_mesh: BoxMesh = body.mesh as BoxMesh
	if gun_mesh != null:
		gun_mesh.size = weapon["size"]
	body.position = Vector3(0.28, -0.22, -0.5)
	if muzzle != null:
		muzzle.position = Vector3(0.28, -0.22, -0.5 - float(weapon["size"].z) * 0.5)


func _update_weapon_label() -> void:
	if weapon_label == null:
		return
	var weapon: Dictionary = GUN_CATALOG.get_weapon(weapon_index)
	weapon_label.text = "Weapon: %s" % weapon["name"]
	weapon_label.visible = is_multiplayer_authority() and _in_gun_mode()


func _update_gun() -> void:
	if gun_pivot == null:
		return

	var gun_mode: bool = is_multiplayer_authority() and _in_gun_mode()
	gun_pivot.visible = gun_mode and is_it
	if stamina_bar != null:
		stamina_bar.visible = is_multiplayer_authority() and game_started
	if weapon_label != null:
		weapon_label.visible = gun_mode


func fire() -> void:
	if not game_started or not is_it:
		return

	if not _in_gun_mode():
		return

	if gun_cooldown > 0.0:
		return

	var weapon: Dictionary = GUN_CATALOG.get_weapon(weapon_index)
	gun_cooldown = float(weapon["cooldown"])

	if muzzle != null:
		muzzle.visible = true
		muzzle_time = 0.05

	var pellet_count: int = int(weapon["pellets"])
	var spread: float = float(weapon["spread"])
	for _pellet_index in pellet_count:
		var direction: Vector3 = -camera.global_transform.basis.z
		direction += camera.global_transform.basis.x * gun_rng.randf_range(-spread, spread)
		direction += camera.global_transform.basis.y * gun_rng.randf_range(-spread, spread)
		direction = direction.normalized()
		var from: Vector3 = camera.global_position
		var to: Vector3 = from + direction * GUN_RANGE
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var hit: Variant = result.get("collider")
		if hit == null or not (hit is Node3D):
			continue
		if hit == self or not hit.is_in_group("players") or hit.is_it:
			continue
		var network_manager: Node = get_parent()
		network_manager.request_tag.rpc_id(1, get_multiplayer_authority(), hit.get_multiplayer_authority())
