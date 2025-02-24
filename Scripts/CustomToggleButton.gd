extends PanelContainer

@export var button_custom_minimum_size : Vector2i = Vector2i(30, 30)
@export var button_text : String = ""
@export var button_font_size : int = 16
@export var pressed : bool = false
@export var button_group : ButtonGroup
@export var send_signal_when_disabled : bool = true
@export var pressed_signal_sender : Node
@export var pressed_signal_name : String = "custom_toggle_button_pressed"
@export var argument : String = "0"

func _ready() -> void:
	update()
	return

func update(data : Dictionary = {}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	custom_minimum_size = button_custom_minimum_size
	%Button.text = button_text
	%Button.set("theme_override_font_sizes/font_size", button_font_size)
	GeneralManager.disconnect_all_connections(%Button.toggled)
	%Button.button_pressed = pressed
	%Button.toggled.connect(func(state : bool) -> void: pressed = state; if state in [true, !send_signal_when_disabled]: pressed_signal_sender.call(pressed_signal_name, argument, state); return)
	return
