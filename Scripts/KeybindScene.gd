extends HBoxContainer

@export var title : String
@export var button_1_text : String
@export var button_2_text : String
@export var pressed_sender : Node
@export var pressed_signal_name : String = "keybind_scene_button_pressed"
@export var pressed_arguments : Array = []

func _ready() -> void:
	update()
	return

func update(data : Dictionary = {"title": title, "button_1_text": button_1_text, "button_2_text": button_2_text, "pressed_sender": pressed_sender, "pressed_signal_name": pressed_signal_name, "pressed_arguments": pressed_arguments}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	$Title.text = title
	%Button.text = button_1_text
	%Button2.text = button_2_text
	for item : Button in [%Button, %Button2]:
		GeneralManager.disconnect_all_connections(item.pressed)
		item.pressed.connect(func() -> void: var args : Array = [item.get_index()]; args.append_array(pressed_arguments); pressed_sender.call(pressed_signal_name, args); return)
	return
