extends CanvasLayer

## Shows the controls before the match begins. Dismissed with the begin button.

@onready var _begin_button: Button = $CenterContainer/Panel/Margin/VBox/BeginButton


func _ready() -> void:
	visible = true
	_begin_button.pressed.connect(_on_begin_pressed)
	_begin_button.grab_focus()


func _on_begin_pressed() -> void:
	visible = false