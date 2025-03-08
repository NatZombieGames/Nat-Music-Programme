extends PanelContainer

const action_button : PackedScene = preload("res://Scenes/CustomTextureButton.tscn")
@export var title : String = "Placeholder"
@export var subtitle : String = "Placeholder"
@export var active : bool = false
static var size_mod : float = 1.0
@export var copy_subtitle_button : bool = true
@export var copy_subtitle_text : String = "[i] ID '[u]" + subtitle + "[/u]' Was Copied To Clipboard. [/i]"
@export var image : ImageTexture
@export var action_button_sender : Node
@export var action_buttons : int = 0
@export var action_button_images : Array = []
@export var action_button_signal_names : Array = []
@export var action_button_arguments : Array = []

func _ready() -> void:
	if not GeneralManager.finished_loading_icons:
		await GeneralManager.finished_loading_icons_signal
	image = GeneralManager.get_icon_texture()
	update()
	return

func update(data : Dictionary = {}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	%Container/InfoContainer/Title.text = title
	%Container/InfoContainer/Subtitle.text = subtitle
	%Image.texture = image
	%Button.disabled = !copy_subtitle_button
	GeneralManager.disconnect_all_connections(%Button.pressed)
	%Button.pressed.connect(func() -> void: DisplayServer.clipboard_set(subtitle); get_node("/root/MainScreen").call("create_popup_notif", copy_subtitle_text); return)
	for i : int in range(0, action_buttons):
		if len(%Container/ActionsContainer.get_children()) < (i + 1):
			%Container/ActionsContainer.add_child(action_button.instantiate())
		%Container/ActionsContainer.get_child(i).update({"texture_icon_name": action_button_images[i], "pressed_signal_sender": self, "pressed_signal_name": "action_button_pressed", "argument": str(i)})
	size_mod = MasterDirectoryManager.user_data_dict["library_size_modifier"]
	%Image.custom_minimum_size.x = 55.0 * size_mod
	%Image.custom_minimum_size.y = 55.0 * size_mod
	$GreaterContainer/Container/InfoContainer/Title.add_theme_font_size_override("font_size", 16 * size_mod)
	$GreaterContainer/Container/InfoContainer/Subtitle.add_theme_font_size_override("font_size", 12 * size_mod)
	$GreaterContainer/Container/InfoContainer.set("theme_override_constants/separation", 10 / (size_mod / 2.0))
	return

func action_button_pressed(index : String) -> void:
	if typeof(action_button_arguments[int(index)]) == TYPE_ARRAY:
		action_button_sender.call(action_button_signal_names[int(index)], (func() -> Array: var args : Array = action_button_arguments[int(index)].duplicate(); args.append(get_index()); return args).call())
	else:
		action_button_sender.call(action_button_signal_names[int(index)], action_button_arguments[int(index)])
	var button_img : ImageTexture = %Container/ActionsContainer.get_child(int(index)).get_child(0).texture_normal
	if button_img.resource_name in ["Favourite", "Favourited"]:
		%Container/ActionsContainer.get_child(int(index)).update({"texture_icon_name": GeneralManager.get_other_list_item(["Favourite", "Favourited"], button_img.resource_name)})
	return
