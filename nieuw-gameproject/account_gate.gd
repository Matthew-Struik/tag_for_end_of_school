extends CanvasLayer

## Local device profiles only. Passwords are salted and hashed; no account server is used.

const ACCOUNT_FILE: String = "user://local_accounts.cfg"

var panel: PanelContainer
var username_input: LineEdit
var password_input: LineEdit
var status_label: Label
var mode_button: Button
var action_button: Button
var register_mode: bool = true
var accounts: ConfigFile = ConfigFile.new()


func _ready() -> void:
	layer = 20
	_build_ui()
	visible = true
	var tutorial: CanvasLayer = get_tree().current_scene.get_node_or_null("Tutorial") as CanvasLayer
	if tutorial != null:
		tutorial.visible = false
	var load_error: Error = accounts.load(ACCOUNT_FILE)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		status_label.text = "Could not read saved accounts."


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.045, 0.075, 0.95)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210.0, -190.0)
	panel.custom_minimum_size = Vector2(420.0, 380.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "Create your player account"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var note: Label = Label.new()
	note.text = "Saved on this device only"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	username_input = LineEdit.new()
	username_input.placeholder_text = "Username"
	username_input.max_length = 24
	column.add_child(username_input)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Password (at least 6 characters)"
	password_input.secret = true
	password_input.max_length = 128
	column.add_child(password_input)
	status_label = Label.new()
	status_label.text = "Choose a username and password to register."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 44.0
	column.add_child(status_label)
	action_button = Button.new()
	action_button.text = "Create account"
	action_button.custom_minimum_size.y = 46.0
	action_button.pressed.connect(_submit)
	column.add_child(action_button)
	mode_button = Button.new()
	mode_button.text = "Already have an account? Log in"
	mode_button.flat = true
	mode_button.pressed.connect(_toggle_mode)
	column.add_child(mode_button)


func _toggle_mode() -> void:
	register_mode = not register_mode
	action_button.text = "Create account" if register_mode else "Log in"
	mode_button.text = "Already have an account? Log in" if register_mode else "Need an account? Create one"
	status_label.text = "Choose a username and password to register." if register_mode else "Enter your saved username and password."


func _submit() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text
	if username.length() < 3:
		status_label.text = "Username must be at least 3 characters."
		return
	if password.length() < 6:
		status_label.text = "Password must be at least 6 characters."
		return
	if register_mode:
		_register(username, password)
	else:
		_login(username, password)


func _register(username: String, password: String) -> void:
	if accounts.has_section_key("users", username.to_lower()):
		status_label.text = "That username is already saved on this device."
		return
	var salt: String = Crypto.new().generate_random_bytes(16).hex_encode()
	accounts.set_value("users", username.to_lower(), {"name": username, "salt": salt, "hash": _password_hash(password, salt)})
	var save_error: Error = accounts.save(ACCOUNT_FILE)
	if save_error != OK:
		status_label.text = "Could not save account on this device."
		return
	_finish_login(username)


func _login(username: String, password: String) -> void:
	var key: String = username.to_lower()
	if not accounts.has_section_key("users", key):
		status_label.text = "Username or password is incorrect."
		return
	var record: Variant = accounts.get_value("users", key)
	if not record is Dictionary:
		status_label.text = "Saved account data is damaged."
		return
	var stored: Dictionary = record as Dictionary
	var salt: String = str(stored.get("salt", ""))
	var expected_hash: String = str(stored.get("hash", ""))
	if not _constant_time_equal(_password_hash(password, salt), expected_hash):
		status_label.text = "Username or password is incorrect."
		return
	_finish_login(str(stored.get("name", username)))


func _password_hash(password: String, salt: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update((salt + password).to_utf8_buffer())
	return context.finish().hex_encode()


func _constant_time_equal(first: String, second: String) -> bool:
	if first.length() != second.length():
		return false
	var difference: int = 0
	for index: int in range(first.length()):
		difference |= first.unicode_at(index) ^ second.unicode_at(index)
	return difference == 0


func _finish_login(username: String) -> void:
	print("Local profile signed in: ", username)
	var lobby: Node = get_tree().current_scene.get_node_or_null("NetworkManager/CanvasLayer")
	if lobby != null:
		lobby.set_meta("profile_username", username)
	var tutorial: CanvasLayer = get_tree().current_scene.get_node_or_null("Tutorial") as CanvasLayer
	if tutorial != null:
		tutorial.visible = true
	visible = false
