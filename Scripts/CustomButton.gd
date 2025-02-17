extends PanelContainer

@export var button_custom_minimum_size : Vector2i = Vector2i(24, 24)
@export var button_text : String = ""
@export var button_font_size : int = 16
@export var toggle : bool = false
@export var pressed : bool = false
@export var button_group : ButtonGroup
@export var pressed_signal_sender : Node
@export var pressed_signal_name : String = "custom_button_pressed"
@export var argument : String = "0"

func _ready() -> void:
	update()
	return

func update(data : Dictionary = {"button_custom_minimum_size": button_custom_minimum_size, "button_text": button_text, "button_font_size": button_font_size, "toggle": toggle, "pressed": pressed, "button_group": button_group, "pressed_signal_sender": pressed_signal_sender, "pressed_signal_name": pressed_signal_name, "argument": argument}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	$Button.custom_minimum_size = button_custom_minimum_size
	$Button.text = button_text
	$Button.toggle_mode = toggle
	$Button.button_pressed = pressed
	$Button.button_group = button_group 
	$Button.add_theme_font_size_override("font_size", button_font_size)
	for item : Signal in [$Button.toggled, $Button.button_down, $Button.button_up]:
		GeneralManager.disconnect_all_connections(item)
	if toggle:
		$Button.toggled.connect(func(state : bool) -> void: pressed = state; if state == true: pressed_signal_sender.call(pressed_signal_name, argument); return)
	else:
		$Button.button_down.connect(func() -> void: pressed = true; pressed_signal_sender.call(pressed_signal_name, argument); return)
		$Button.button_up.connect(func() -> void: pressed = false; return)
	return
