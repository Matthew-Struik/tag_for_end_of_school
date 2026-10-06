extends CanvasLayer

## Shows the controls before the match begins. Dismissed with the begin button.

@onready var _begin_button: Button = $CenterContainer/Panel/Margin/VBox/BeginButton


func _ready() -> void:
	visible = true
	var info_label: Label = get_node_or_null("CenterContainer/Panel/Margin/VBox/Info") as Label
	if info_label != null and OS.has_feature("mobile"):
		info_label.text = "Move: use the buttons on the left\nLook: drag the right side of the screen\nJump: JUMP button\nTag: TAG button\n\nRed = the tagger. Get close to a blue player and press TAG.\nBlue players: run away!\nIn Infection Mode, tagged players join the tagger team."

	_begin_button.pressed.connect(_on_begin_pressed)
	_begin_button.grab_focus()


func _on_begin_pressed() -> void:
	visible = false
