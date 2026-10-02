extends Node3D

## Procedurally builds a colourful, fun tag arena: a walled field with a
## central platform, ramps, a tower, pillars and heaps of cover.

const FLOOR_TEXTURE := "res://assets/generated/arena_floor.png"
const WALL_TEXTURE := "res://assets/generated/stone_wall.png"
const CRATE_TEXTURE := "res://assets/generated/wood_crate.png"

const ARENA_SIZE := 64.0

var mat_floor: StandardMaterial3D
var mat_wall: StandardMaterial3D
var mat_crate: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_ramp: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_arena()


func _make_materials() -> void:
	mat_floor = StandardMaterial3D.new()
	mat_floor.albedo_texture = load(FLOOR_TEXTURE)
	mat_floor.uv1_scale = Vector3(16, 16, 1)
	mat_floor.roughness = 0.95

	mat_wall = StandardMaterial3D.new()
	mat_wall.albedo_texture = load(WALL_TEXTURE)
	mat_wall.uv1_scale = Vector3(6, 2, 1)
	mat_wall.roughness = 0.9

	mat_crate = StandardMaterial3D.new()
	mat_crate.albedo_texture = load(CRATE_TEXTURE)
	mat_crate.roughness = 0.8

	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.24, 0.42, 0.85)
	mat_metal.metallic = 0.55
	mat_metal.roughness = 0.35

	mat_ramp = StandardMaterial3D.new()
	mat_ramp.albedo_color = Color(0.9, 0.5, 0.15)
	mat_ramp.roughness = 0.7


func _build_arena() -> void:
	var half := ARENA_SIZE * 0.5

	# Floor
	_add_box("Floor", Vector3(0, -0.5, 0), Vector3(ARENA_SIZE, 1, ARENA_SIZE), Vector3.ZERO, mat_floor)

	# Perimeter walls
	_add_box("WallNorth", Vector3(0, 2.5, -half), Vector3(ARENA_SIZE + 2, 5, 1), Vector3.ZERO, mat_wall)
	_add_box("WallSouth", Vector3(0, 2.5, half), Vector3(ARENA_SIZE + 2, 5, 1), Vector3.ZERO, mat_wall)
	_add_box("WallWest", Vector3(-half, 2.5, 0), Vector3(1, 5, ARENA_SIZE + 2), Vector3.ZERO, mat_wall)
	_add_box("WallEast", Vector3(half, 2.5, 0), Vector3(1, 5, ARENA_SIZE + 2), Vector3.ZERO, mat_wall)

	# Central platform
	_add_box("CenterPlatform", Vector3(0, 1.25, 0), Vector3(16, 2.5, 16), Vector3.ZERO, mat_metal)

	# Ramps leading up to the central platform (N, S, E, W)
	_add_box("RampSouth", Vector3(0, 1.25, 11.5), Vector3(6, 0.5, 7.43), Vector3(19.7, 0, 0), mat_ramp)
	_add_box("RampNorth", Vector3(0, 1.25, -11.5), Vector3(6, 0.5, 7.43), Vector3(-19.7, 0, 0), mat_ramp)
	_add_box("RampEast", Vector3(11.5, 1.25, 0), Vector3(7.43, 0.5, 6), Vector3(0, 0, -19.7), mat_ramp)
	_add_box("RampWest", Vector3(-11.5, 1.25, 0), Vector3(7.43, 0.5, 6), Vector3(0, 0, 19.7), mat_ramp)

	# Little tower on top of the platform - king of the hill!
	_add_box("Tower", Vector3(0, 3.5, 0), Vector3(6, 2, 6), Vector3.ZERO, mat_metal)

	# Corner pillars (cover + verticality)
	_add_box("PillarNE", Vector3(24, 5, -24), Vector3(2, 10, 2), Vector3.ZERO, mat_metal)
	_add_box("PillarNW", Vector3(-24, 5, -24), Vector3(2, 10, 2), Vector3.ZERO, mat_metal)
	_add_box("PillarSE", Vector3(24, 5, 24), Vector3(2, 10, 2), Vector3.ZERO, mat_metal)
	_add_box("PillarSW", Vector3(-24, 5, 24), Vector3(2, 10, 2), Vector3.ZERO, mat_metal)

	# Low cover walls
	_add_box("CoverA", Vector3(16, 1, -8), Vector3(12, 2, 1), Vector3.ZERO, mat_wall)
	_add_box("CoverB", Vector3(-16, 1, 8), Vector3(12, 2, 1), Vector3.ZERO, mat_wall)
	_add_box("CoverC", Vector3(0, 1, -22), Vector3(1, 2, 14), Vector3.ZERO, mat_wall)
	_add_box("CoverD", Vector3(0, 1, 22), Vector3(14, 2, 1), Vector3.ZERO, mat_wall)

	# Crates to hide behind and climb
	var crate_positions := [
		Vector3(14, 1.5, 12), Vector3(-14, 1.5, -12),
		Vector3(20, 1.5, 4), Vector3(-20, 1.5, -4),
		Vector3(10, 1.5, -16), Vector3(-10, 1.5, 16),
		Vector3(22, 1.5, 22), Vector3(-22, 1.5, -22),
		Vector3(6, 1.5, 24), Vector3(-6, 1.5, -24),
	]
	for i in crate_positions.size():
		_add_box("Crate%d" % i, crate_positions[i], Vector3(3, 3, 3), Vector3.ZERO, mat_crate)

	# A couple of stacked crates for climbing
	_add_box("CrateStackA", Vector3(14, 4.5, 12), Vector3(3, 3, 3), Vector3.ZERO, mat_crate)
	_add_box("CrateStackB", Vector3(-14, 4.5, -12), Vector3(3, 3, 3), Vector3.ZERO, mat_crate)


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