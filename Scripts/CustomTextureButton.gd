extends PanelContainer

@onready var normal_stylebox : StyleBoxFlat = preload("res://Assets/CustomButtonNormal.tres")
@onready var pressed_stylebox : StyleBoxFlat = preload("res://Assets/CustomButtonPressed.tres")
@export var button_custom_minimum_size : Vector2i = Vector2i(24, 24)
@export var texture_icon_name : String = "Missing"
@export var pressed_texture_icon_name : String = "Missing"
@export var toggle : bool = false
@export var pressed : bool = false
@export var button_group : ButtonGroup
@export var pressed_signal_sender : Node
@export var pressed_signal_name : String = "custom_texture_button_pressed"
@export var argument : String = "0"

func _ready() -> void:
	if not GeneralManager.finished_loading_icons:
		await GeneralManager.finished_loading_icons_signal
	update()
	return

func update(data : Dictionary = {"button_custom_minimum_size": button_custom_minimum_size, "texture_icon_name": texture_icon_name, "pressed_texture_icon_name": pressed_texture_icon_name, "toggle": toggle, "pressed": pressed, "button_group": button_group, "pressed_signal_sender": pressed_signal_sender, "pressed_signal_name": pressed_signal_name, "argument": argument}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	set_panel()
	$Button.custom_minimum_size = button_custom_minimum_size
	$Button.texture_normal = GeneralManager.get_icon_texture(texture_icon_name)
	if pressed_texture_icon_name != "Missing":
		$Button.texture_pressed = GeneralManager.get_icon_texture(pressed_texture_icon_name)
	else:
		$Button.texture_pressed = GeneralManager.get_icon_texture(texture_icon_name)
	$Button.toggle_mode = toggle
	$Button.button_pressed = pressed
	$Button.button_group = button_group
	for item : Signal in [$Button.toggled, $Button.button_down, $Button.button_up]:
		GeneralManager.disconnect_all_connections(item)
	if toggle:
		$Button.toggled.connect(func(state : bool) -> void: pressed = state; set_panel(); if state == true: pressed_signal_sender.call(pressed_signal_name, argument); return)
	else:
		$Button.button_down.connect(func() -> void: pressed = true; set_panel(); pressed_signal_sender.call(pressed_signal_name, argument); return)
		$Button.button_up.connect(func() -> void: pressed = false; set_panel(); return)
	return

func set_panel() -> void:
	self.set("theme_override_styles/panel", [normal_stylebox, pressed_stylebox][int(pressed)])
	return
