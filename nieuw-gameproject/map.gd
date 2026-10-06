extends Node3D## Procedurally builds a bright, colourful tag arena with a castle, ramps, cover, trees and jump pads.


const FLOOR_TEXTURE := "res://assets/generated/arena_floor.png"
const WALL_TEXTURE := "res://assets/generated/stone_wall.png"
const CRATE_TEXTURE := "res://assets/generated/wood_crate.png"

const ARENA_SIZE := 128.0
const JUMP_PAD_FORCE := 12.0

const C_BLUE := Color(0.20, 0.45, 0.95)
const C_RED := Color(0.92, 0.24, 0.24)
const C_YELLOW := Color(0.98, 0.82, 0.18)
const C_GREEN := Color(0.22, 0.78, 0.35)
const C_PURPLE := Color(0.62, 0.32, 0.92)
const C_ORANGE := Color(0.98, 0.55, 0.12)
const C_PINK := Color(0.98, 0.45, 0.72)
const C_CYAN := Color(0.20, 0.85, 0.90)
const C_BROWN := Color(0.45, 0.28, 0.14)

var mat_floor: StandardMaterial3D
var mat_wall: StandardMaterial3D
var mat_crate: StandardMaterial3D
var mat_blue: StandardMaterial3D
var mat_red: StandardMaterial3D
var mat_yellow: StandardMaterial3D
var mat_green: StandardMaterial3D
var mat_purple: StandardMaterial3D
var mat_orange: StandardMaterial3D
var mat_pink: StandardMaterial3D
var mat_cyan: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_leaf: StandardMaterial3D
var mat_jump: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_arena()


func _make_materials() -> void:
	mat_floor = StandardMaterial3D.new()
	mat_floor.albedo_texture = load(FLOOR_TEXTURE)
	mat_floor.uv1_scale = Vector3(32, 32, 1)
	mat_floor.roughness = 0.95

	mat_wall = StandardMaterial3D.new()
	mat_wall.albedo_texture = load(WALL_TEXTURE)
	mat_wall.uv1_scale = Vector3(12, 2, 1)
	mat_wall.roughness = 0.9

	mat_crate = StandardMaterial3D.new()
	mat_crate.albedo_texture = load(CRATE_TEXTURE)
	mat_crate.roughness = 0.8

	mat_blue = _solid(C_BLUE)
	mat_red = _solid(C_RED)
	mat_yellow = _solid(C_YELLOW)
	mat_green = _solid(C_GREEN)
	mat_purple = _solid(C_PURPLE)
	mat_orange = _solid(C_ORANGE)
	mat_pink = _solid(C_PINK)
	mat_cyan = _solid(C_CYAN)
	mat_wood = _solid(C_BROWN, 0.85)
	mat_leaf = _solid(Color(0.16, 0.62, 0.28), 0.9)

	mat_jump = _solid(Color(1.0, 0.9, 0.15))
	mat_jump.emission_enabled = true
	mat_jump.emission = Color(1.0, 0.85, 0.2)
	mat_jump.emission_energy_multiplier = 1.6


func _solid(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _build_arena() -> void:
	var half := ARENA_SIZE * 0.5

	# --- Ground ---------------------------------------------------------
	_add_box("Floor", Vector3(0, -0.5, 0), Vector3(ARENA_SIZE, 1, ARENA_SIZE), Vector3.ZERO, mat_floor)

	# --- Perimeter walls -------------------------------------------------
	_add_box("WallNorth", Vector3(0, 3, -half), Vector3(ARENA_SIZE + 2, 6, 1), Vector3.ZERO, mat_wall)
	_add_box("WallSouth", Vector3(0, 3, half), Vector3(ARENA_SIZE + 2, 6, 1), Vector3.ZERO, mat_wall)
	_add_box("WallWest", Vector3(-half, 3, 0), Vector3(1, 6, ARENA_SIZE + 2), Vector3.ZERO, mat_wall)
	_add_box("WallEast", Vector3(half, 3, 0), Vector3(1, 6, ARENA_SIZE + 2), Vector3.ZERO, mat_wall)

	# --- Central castle --------------------------------------------------
	_add_box("CastleBase", Vector3(0, 1.25, 0), Vector3(16, 2.5, 16), Vector3.ZERO, mat_blue)
	_add_box("CastleTower", Vector3(0, 4.0, 0), Vector3(6, 3, 6), Vector3.ZERO, mat_red)
	_add_cone("CastleRoof", Vector3(0, 7.0, 0), 4.5, 3.0, mat_yellow)

	# Ramps up to the castle base (N, S, E, W)
	_add_box("RampSouth", Vector3(0, 1.25, 11.5), Vector3(6, 0.5, 7.43), Vector3(19.7, 0, 0), mat_orange)
	_add_box("RampNorth", Vector3(0, 1.25, -11.5), Vector3(6, 0.5, 7.43), Vector3(-19.7, 0, 0), mat_orange)
	_add_box("RampEast", Vector3(11.5, 1.25, 0), Vector3(7.43, 0.5, 6), Vector3(0, 0, -19.7), mat_orange)
	_add_box("RampWest", Vector3(-11.5, 1.25, 0), Vector3(7.43, 0.5, 6), Vector3(0, 0, 19.7), mat_orange)

	# Ramp from the castle base up to the tower top (king of the hill!)
	_add_box("RampTower", Vector3(0, 4.0, 5.5), Vector3(3, 0.5, 5.83), Vector3(30.96, 0, 0), mat_orange)

	# --- Colourful corner houses ----------------------------------------
	var corner_mats: Array = [mat_red, mat_green, mat_purple, mat_cyan]
	var corners: Array = [
		Vector3(21, 0, -21), Vector3(-21, 0, -21),
		Vector3(21, 0, 21), Vector3(-21, 0, 21),
	]
	for i in 4:
		var corner: Vector3 = corners[i]
		_add_box("House%d" % i, corner + Vector3(0, 2, 0), Vector3(5, 4, 5), Vector3.ZERO, corner_mats[i])
		_add_cone("HouseRoof%d" % i, corner + Vector3(0, 5.5, 0), 4.0, 3.0, mat_yellow)
		_add_flag("HouseFlag%d" % i, corner + Vector3(0, 7.0, 0), 4.0, corner_mats[i])

	# --- Low cover walls -------------------------------------------------
	_add_box("CoverA", Vector3(15, 1, -6), Vector3(12, 2, 1), Vector3.ZERO, mat_wall)
	_add_box("CoverB", Vector3(-15, 1, 6), Vector3(12, 2, 1), Vector3.ZERO, mat_wall)
	_add_box("CoverC", Vector3(9, 1, 20), Vector3(1, 2, 12), Vector3.ZERO, mat_wall)
	_add_box("CoverD", Vector3(-9, 1, -20), Vector3(1, 2, 12), Vector3.ZERO, mat_wall)

	# --- Crates to hide behind and climb ---------------------------------
	var crate_positions := [
		Vector3(13, 1.5, 10), Vector3(-13, 1.5, -10),
		Vector3(18, 1.5, 3), Vector3(-18, 1.5, -3),
		Vector3(12, 1.5, -14), Vector3(-12, 1.5, 14),
	]
	for i in crate_positions.size():
		_add_box("Crate%d" % i, crate_positions[i], Vector3(3, 3, 3), Vector3.ZERO, mat_crate)

	_add_box("CrateStackA", Vector3(13, 4.5, 10), Vector3(3, 3, 3), Vector3.ZERO, mat_crate)
	_add_box("CrateStackB", Vector3(-13, 4.5, -10), Vector3(3, 3, 3), Vector3.ZERO, mat_crate)

	# --- Bouncy jump pads ------------------------------------------------
	_add_jump_pad("JumpPadE", Vector3(16, 0.25, 0))
	_add_jump_pad("JumpPadW", Vector3(-16, 0.25, 0))
	_add_jump_pad("JumpPadN", Vector3(0, 0.25, -17))
	_add_jump_pad("JumpPadS", Vector3(0, 0.25, 17))

	# --- Trees around the edge ------------------------------------------
	var tree_spots := [
		Vector3(-57, 0, -28), Vector3(-57, 0, 0), Vector3(-57, 0, 28),
		Vector3(57, 0, -28), Vector3(57, 0, 0), Vector3(57, 0, 28),
		Vector3(-28, 0, 57), Vector3(0, 0, 57), Vector3(28, 0, 57),
		Vector3(-28, 0, -57), Vector3(0, 0, -57), Vector3(28, 0, -57),
	]
	for i in tree_spots.size():
		_add_tree("Tree%d" % i, tree_spots[i], 1.0)

	# --- Traffic cones (just for looks) ---------------------------------
	var cone_spots := [
		Vector3(9, 0, 9), Vector3(-9, 0, -9), Vector3(9, 0, -9), Vector3(-9, 0, 9),
		Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(0, 0, 21), Vector3(0, 0, -21),
	]
	for i in cone_spots.size():
		_add_cone("Cone%d" % i, cone_spots[i] + Vector3(0, 0.6, 0), 0.55, 1.2, mat_orange)

	# --- Balloon clusters floating overhead -----------------------------
	_add_balloons("BalloonsE", Vector3(20, 9, 12))
	_add_balloons("BalloonsW", Vector3(-20, 9, -12))
	_add_balloons("BalloonsN", Vector3(0, 10, -22))
	_add_balloons("BalloonsS", Vector3(0, 10, 22))


func _add_box(node_name: String, pos: Vector3, size: Vector3, rot_deg: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = rot_deg

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)

	add_child(body)


func _add_prop_mesh(node_name: String, pos: Vector3, mesh: Mesh, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _add_cone(node_name: String, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	_add_prop_mesh(node_name, pos, mesh, material)


func _add_cylinder(node_name: String, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	_add_prop_mesh(node_name, pos, mesh, material)


func _add_sphere(node_name: String, pos: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_add_prop_mesh(node_name, pos, mesh, material)


func _add_tree(node_name: String, base: Vector3, tree_scale: float) -> void:
	_add_cylinder(node_name + "_Trunk", base + Vector3(0, 1.5 * tree_scale, 0), 0.35 * tree_scale, 3.0 * tree_scale, mat_wood)
	_add_sphere(node_name + "_Leaves", base + Vector3(0, 3.7 * tree_scale, 0), 1.9 * tree_scale, mat_leaf)


func _add_flag(node_name: String, base: Vector3, pole_height: float, flag_material: Material) -> void:
	_add_cylinder(node_name + "_Pole", base + Vector3(0, pole_height * 0.5, 0), 0.09, pole_height, mat_wood)
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.8, 1.0, 0.08)
	_add_prop_mesh(node_name + "_Cloth", base + Vector3(0.95, pole_height - 0.6, 0), flag_mesh, flag_material)


func _add_balloons(node_name: String, center: Vector3) -> void:
	var balloon_colors: Array = [C_RED, C_YELLOW, C_GREEN, C_PURPLE, C_CYAN]
	var offsets: Array = [
		Vector3(0, 0, 0), Vector3(0.9, 0.6, 0.2), Vector3(-0.8, 0.3, -0.4),
		Vector3(0.4, 1.2, 0.6), Vector3(-0.5, 1.0, 0.5),
	]
	for i in offsets.size():
		_add_sphere(node_name + "_%d" % i, center + offsets[i], 0.7, _solid(balloon_colors[i]))


func _add_jump_pad(node_name: String, pos: Vector3) -> void:
	var pad := Area3D.new()
	pad.name = node_name
	pad.position = pos

	var mesh_instance := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(4, 0.4, 4)
	mesh_instance.mesh = pad_mesh
	mesh_instance.material_override = mat_jump
	pad.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var pad_shape := BoxShape3D.new()
	pad_shape.size = Vector3(4, 0.8, 4)
	collision.shape = pad_shape
	pad.add_child(collision)

	pad.body_entered.connect(_on_jump_pad)
	add_child(pad)


func _on_jump_pad(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.velocity.y = JUMP_PAD_FORCE
