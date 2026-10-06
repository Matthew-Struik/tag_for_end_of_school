extends CanvasLayer

@onready var network_manager: Node = get_parent()
@onready var tutorial: CanvasLayer = get_node("/root/Node3D/Tutorial")

var menu_panel: PanelContainer
var spawn_npc_button: Button
var is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	visible = false
	spawn_npc_button.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if network_manager.get("game_started"):
			_toggle_menu()
			get_viewport().set_input_as_handled()


func _toggle_menu() -> void:
	is_open = not is_open
	visible = is_open
	get_tree().paused = is_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED
	spawn_npc_button.visible = is_open and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func _build_menu() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(320.0, 0.0)
	center.add_child(menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	menu_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size.y = 44.0
	resume_button.pressed.connect(_toggle_menu)
	column.add_child(resume_button)

	var tutorial_button := Button.new()
	tutorial_button.text = "View Tutorial"
	tutorial_button.custom_minimum_size.y = 44.0
	tutorial_button.pressed.connect(_view_tutorial)
	column.add_child(tutorial_button)

	spawn_npc_button = Button.new()
	spawn_npc_button.name = "SpawnNPCButton"
	spawn_npc_button.text = "Spawn NPC"
	spawn_npc_button.custom_minimum_size.y = 44.0
	spawn_npc_button.pressed.connect(_spawn_npc)
	spawn_npc_button.visible = false
	column.add_child(spawn_npc_button)

	var leave_button := Button.new()
	leave_button.name = "LeaveButton"
	leave_button.text = "Leave game"
	leave_button.custom_minimum_size.y = 44.0
	leave_button.pressed.connect(_leave_game)
	column.add_child(leave_button)


func _view_tutorial() -> void:
	get_tree().paused = false
	is_open = false
	visible = false
	tutorial.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _spawn_npc() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server() and network_manager.has_method("spawn_npc"):
		network_manager.call("spawn_npc")

func _leave_game() -> void:
	get_tree().paused = false
	is_open = false
	visible = false
	if network_manager.has_method("leave_game"):
		network_manager.call("leave_game")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()
