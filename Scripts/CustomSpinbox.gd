extends PanelContainer

@export var text : String = ""
@export var value_int : int = 1
@export var value_float : float = 1.0
@export var type : value_type = value_type.INTEGER
@export var float_increment_amount : float = 0.25
@export var value_range : Vector2 = Vector2(0, 10)
@export var submitted_sender : Node
@export var submitted_signal_name : String = "custom_spinbox_changed"
@export var submitted_signal_argument : String = "0"
enum value_type {INTEGER, FLOAT}

func _ready() -> void:
	%Value.text_changed.connect(func(new_text : String) -> void: 
		if not [new_text.is_valid_int(), new_text.is_valid_float()][type]:
			new_text = str([value_int, value_float][type])
			%Value.text = new_text
			return
		new_text = str([
			clampi(int(new_text), int(value_range.x), int(value_range.y)), 
			clampf(float(new_text), float(value_range.x), float(value_range.y))
			][type])
		value_int = int(new_text)
		value_float = float(new_text)
		%Value.text = new_text
		return)
	%Value.text_submitted.connect(func(_submitted_text : String) -> void: 
		submitted_sender.call(submitted_signal_name, [[value_int, value_float][type], submitted_signal_argument])
		return)
	%IncrementButton.pressed.connect(func() -> void: 
		if type == value_type.INTEGER:
			%Value.text = str(mini(int(%Value.text) + 1, int(value_range.y)))
		else:
			%Value.text = str(minf(float(%Value.text) + float_increment_amount, value_range.y))
		value_int = int(%Value.text)
		value_float = float(%Value.text)
		%Value.emit_signal("text_submitted", %Value.text)
		return)
	%DecrementButton.pressed.connect(func() -> void: 
		if type == value_type.INTEGER:
			%Value.text = str(maxi(int(%Value.text) - 1, int(value_range.x)))
		else:
			%Value.text = str(maxf(float(%Value.text) - float_increment_amount, value_range.x))
		value_int = int(%Value.text)
		value_float = float(%Value.text)
		%Value.emit_signal("text_submitted", %Value.text)
		return)
	update()
	return

func update(data : Dictionary = {}) -> void:
	for key : String in data.keys():
		self.set(key, data[key])
	%Prefix.visible = text != ""
	%Prefix.text = text
	if type == value_type.INTEGER:
		%Value.text = str(value_int)
	else:
		%Value.text = str(value_float)
	return
