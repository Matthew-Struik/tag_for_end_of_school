extends RefCounted
class_name GunCatalog

const WEAPONS: Array[Dictionary] = [
	{"name": "Pistol", "cooldown": 0.45, "pellets": 1, "spread": 0.0, "damage": 1, "size": Vector3(0.12, 0.12, 0.6)},
	{"name": "AK-47", "cooldown": 0.12, "pellets": 1, "spread": 0.018, "damage": 1, "size": Vector3(0.14, 0.15, 0.82)},
	{"name": "Minigun", "cooldown": 0.075, "pellets": 1, "spread": 0.055, "damage": 1, "size": Vector3(0.24, 0.2, 1.0)},
	{"name": "Shotgun", "cooldown": 0.8, "pellets": 6, "spread": 0.12, "damage": 1, "size": Vector3(0.22, 0.2, 0.75)},
	{"name": "Sniper", "cooldown": 1.0, "pellets": 1, "spread": 0.003, "damage": 1, "size": Vector3(0.15, 0.16, 1.15)},
	{"name": "Rocket Launcher", "cooldown": 1.4, "pellets": 3, "spread": 0.02, "damage": 1, "size": Vector3(0.28, 0.28, 1.2)},
	{"name": "Golden Gun", "cooldown": 0.2, "pellets": 1, "spread": 0.0, "damage": 1, "size": Vector3(0.18, 0.2, 0.7)},
	{"name": "Plasma Blaster", "cooldown": 0.1, "pellets": 2, "spread": 0.04, "damage": 1, "size": Vector3(0.25, 0.25, 0.8)},
	{"name": "Laser Rifle", "cooldown": 0.3, "pellets": 1, "spread": 0.0, "damage": 1, "size": Vector3(0.16, 0.14, 1.0)},
	{"name": "Burst Rifle", "cooldown": 0.25, "pellets": 3, "spread": 0.025, "damage": 1, "size": Vector3(0.18, 0.18, 0.9)},
	{"name": "Heavy Cannon", "cooldown": 1.1, "pellets": 4, "spread": 0.08, "damage": 1, "size": Vector3(0.3, 0.32, 1.1)},
	{"name": "Final Blaster", "cooldown": 0.06, "pellets": 2, "spread": 0.03, "damage": 1, "size": Vector3(0.3, 0.24, 1.1)},

]

static func get_weapon(index: int) -> Dictionary:
	var safe_index: int = clampi(index, 0, WEAPONS.size() - 1)
	return WEAPONS[safe_index].duplicate()

static func get_weapon_count() -> int:
	return WEAPONS.size()
