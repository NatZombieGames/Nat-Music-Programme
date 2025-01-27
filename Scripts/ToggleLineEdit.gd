extends PanelContainer

@export var text : String = "Placeholder"
@export var font_size : int = 16
@export var editing_mode : bool = false
@export var emit_text_changed_signal : bool = true
@export var text_changed_signal_sender : Node
@export var text_changed_signal_name : String = "toggle_line_edit_text_changed"
@export var text_changed_signal_argument : String = ""

func _ready() -> void:
	%TextureButton.texture_normal = GeneralManager.get_icon_texture("Edit")
	%TextureButton.texture_pressed = GeneralManager.get_icon_texture("Save")
	%TextureButton.toggled.connect(func(state : bool) -> void: editing_mode = state; update_editing_mode(); if emit_text_changed_signal: text_changed_signal_sender.call(text_changed_signal_name, %LineEdit.text, text_changed_signal_argument); return)
	update()
	return

func update(data : Dictionary = {"text": text, "font_size": font_size, "editing_mode": editing_mode, "emit_text_changed_signal": emit_text_changed_signal, "text_changed_signal_sender": text_changed_signal_sender, "text_changed_signal_name": text_changed_signal_name, "text_changed_signal_argument": text_changed_signal_argument}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	%LineEdit.text = text
	%LineEdit.add_theme_font_size_override("font_size", font_size)
	%TextureButton.set_pressed_no_signal(editing_mode)
	update_editing_mode()
	return

func update_editing_mode() -> void:
	%LineEdit.editable = editing_mode
	%LineEdit.selecting_enabled = editing_mode
	%LineEdit.flat = !editing_mode
	if editing_mode == true:
		%LineEdit.grab_focus()
	else:
		%LineEdit.placeholder_text = %LineEdit.text
	return
