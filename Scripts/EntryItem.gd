extends ColorRect

@onready var normal_stylebox : StyleBoxFlat = preload("res://Assets/CustomTextureButtonNormal.tres")
@onready var pressed_stylebox : StyleBoxFlat = preload("res://Assets/CustomTextureButtonPressed.tres")
@export var title : String = ""
@export var subtitle : String = ""
@export var image : ImageTexture
@export var enabled : bool = true
@export var toggle : bool = false
@export var pressed : bool = false
@export var button_group : ButtonGroup
@export var pressed_signal_sender : Node
@export var pressed_signal_name : String = "entryitem_pressed"
@export var pressed_signal_argument : String

func _ready() -> void:
	image = GeneralManager.get_icon_texture("Missing")
	update()
	return

func update(data : Dictionary = {"title": title, "subtitle": subtitle, "image": image, "enabled": enabled, "toggle": toggle, "pressed": pressed, "button_group": button_group, "pressed_signal_sender": pressed_signal_sender, "pressed_signal_name": pressed_signal_name, "pressed_signal_argument": pressed_signal_argument}) -> void:
	for item in data.keys():
		self.set(item, data[item])
	$Button/Container/Title.text = title
	$Button/Container/Subtitle.text = subtitle
	$Button/Container/ImageContainer/Image.texture = image
	$Button.button_pressed = pressed
	$Button.button_group = button_group
	for item : Signal in [$Button.toggled, $Button.button_down, $Button.button_up]:
		GeneralManager.disconnect_all_connections(item)
	if toggle:
		$Button.toggled.connect(func(state : bool) -> void: pressed = state; set_panel(); pressed_signal_sender.call(pressed_signal_name, pressed_signal_argument); return)
	else:
		$Button.button_down.connect(func() -> void: pressed = true; set_panel(); pressed_signal_sender.call(pressed_signal_name, pressed_signal_argument); return)
		$Button.button_up.connect(func() -> void: pressed = false; set_panel(); return)
	$Button.disabled = !enabled
	await get_tree().process_frame
	var min_size : Vector2 = Vector2($Button/Container.size.x + 10, $Button/Container.size.y + 10)
	$Button.custom_minimum_size = min_size
	self.custom_minimum_size = min_size
	set_panel()
	return

func set_panel() -> void:
	self.set("theme_override_styles/panel", [normal_stylebox, pressed_stylebox][int(pressed)])
	return
