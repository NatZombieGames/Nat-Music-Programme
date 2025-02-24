extends ColorRect

@export var title : String = ""
@export var subtitle : String = ""
@export var id : int = 0
@export var button_enabled : bool = true
@export var editable_title : bool = false
@export var button_min_size : Vector2 = Vector2(24, 24)
@export var button_icon_name : String = "Missing"
@export var signal_sender : Node
@export var pressed_signal_name : String = ""
@export var title_changed_signal_name : String = ""

func _ready() -> void:
	update()
	return

func update(data : Dictionary = {}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	$Container/ToggleLineEdit.visible = editable_title
	$Container/Title.visible = !editable_title
	$Container/Title.text = title
	$Container/Subtitle.text = subtitle
	$Container/Button.update({"visible": button_enabled, "button_custom_minimum_size": button_min_size, "texture_icon_name": button_icon_name, "pressed_signal_sender": signal_sender, "pressed_signal_name": pressed_signal_name, "argument": str(id)})
	$Container/ToggleLineEdit.update({"text": title, "editing_mode": true})
	await get_tree().process_frame
	$Container/ToggleLineEdit.update({"editing_mode": false})
	self.custom_minimum_size = Vector2($Container.size.x + 10, $Container.size.y + 10)
	return

func title_changed(new_value : String, _arg : String) -> void:
	signal_sender.call(title_changed_signal_name, [new_value, id])
	return
