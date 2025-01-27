extends PanelContainer

@onready var action_button : PackedScene = preload("res://Scenes/CustomTextureButton.tscn")
@export var title : String = "Placeholder"
@export var subtitle : String = "Placeholder"
@export var image : ImageTexture
@export var action_button_sender : Node
@export var action_buttons : int = 0
@export var action_button_images : Array = []
@export var action_button_signal_names : Array = []
@export var action_button_arguments : Array = []

func _ready() -> void:
	image = GeneralManager.get_icon_texture()
	update()
	return

func update(data : Dictionary = {"title": title, "subtitle": subtitle, "image": image, "action_button_sender": action_button_sender, "action_buttons": action_buttons, "action_button_images": action_button_images, "action_button_signal_names": action_button_signal_names, "action_button_arguments": action_button_arguments}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	%Container/InfoContainer/Title.text = title
	%Container/InfoContainer/Subtitle.text = subtitle
	%Image.texture = image
	for i : int in range(0, action_buttons):
		if len(%Container/ActionsContainer.get_children()) < i+1:
			%Container/ActionsContainer.add_child(action_button.instantiate())
		%Container/ActionsContainer.get_child(i).update({"texture_icon_name": action_button_images[i], "pressed_signal_sender": self, "pressed_signal_name": "action_button_pressed", "argument": str(i)})
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
