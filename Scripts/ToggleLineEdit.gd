extends PanelContainer

@export var text : String = "Placeholder"
@export var font_size : int = 16
@export var button_custom_min_size : Vector2i = Vector2i(30, 30)
@export var editing_mode : bool = false
@export var emit_text_changed_signal : bool = true
@export var text_changed_signal_sender : Node
@export var text_changed_signal_name : String = "toggle_line_edit_text_changed"
@export var text_changed_signal_argument : String = ""

func _ready() -> void:
	%LineEdit.text_submitted.connect(func(_text : String = "") -> void: update_editing_mode(!editing_mode); return)
	if not GeneralManager.finished_loading_icons:
		await GeneralManager.finished_loading_icons_signal
	%Button.texture_normal = GeneralManager.get_icon_texture("Edit")
	%Button.texture_pressed = GeneralManager.get_icon_texture("Save")
	%Button.custom_minimum_size = button_custom_min_size
	%Button.toggled.connect(
		func(state : bool) -> void: 
			update_editing_mode(state); 
			if emit_text_changed_signal: 
				text_changed_signal_sender.call(text_changed_signal_name, %LineEdit.text, text_changed_signal_argument); 
			return)
	update()
	return

func update(data : Dictionary = {}) -> void:
	for item : String in data.keys():
		self.set(item, data[item])
	%LineEdit.text = text
	%LineEdit.add_theme_font_size_override("font_size", font_size)
	%Button.set_pressed_no_signal(editing_mode)
	update_editing_mode()
	return

func update_editing_mode(state : bool = editing_mode) -> void:
	editing_mode = state
	%LineEdit.editable = editing_mode
	%LineEdit.selecting_enabled = editing_mode
	%LineEdit.flat = !editing_mode
	if editing_mode == true:
		%LineEdit.grab_focus()
	else:
		%LineEdit.placeholder_text = %LineEdit.text
	return
