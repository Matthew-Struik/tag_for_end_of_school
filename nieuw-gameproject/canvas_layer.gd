extends CanvasLayer

@onready var network_manager = get_parent()
@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton
@onready var ip_input: LineEdit = $IPInput
@onready var status_label: Label = $Label


func _ready() -> void:
	host_button.pressed.connect(host_game)
	join_button.pressed.connect(join_game)


func host_game() -> void:
	network_manager.host_game()
	status_label.text = "Hosting game!"


func join_game() -> void:
	var ip: String = ip_input.text.strip_edges()

	if ip.is_empty():
		status_label.text = "Enter an IP address!"
		return

	network_manager.join_game(ip)
	status_label.text = "Joining " + ip + "..."
