extends PanelContainer

@export var text : String = "":
	set(value):
		text = value
		$Text.text = value
		self.visible = value != ""
@export var text_size : int = 16:
	set(value):
		text_size = value
		$Text.set("theme_override_font_sizes/normal_font_size", value)
var starting_mouse_pos : Vector2
const mouse_diff_range : PackedInt32Array = [
	-15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

func _ready() -> void:
	self.visible = text != ""
	starting_mouse_pos = get_global_mouse_position()
	self.global_position = Vector2(starting_mouse_pos.x + 5, starting_mouse_pos.y + 5)
	return

func _process(_delta: float) -> void:
	var mouse_diff : Vector2 = (get_global_mouse_position() - starting_mouse_pos)
	if (not int(mouse_diff.x) in mouse_diff_range) or (not int(mouse_diff.y) in mouse_diff_range):
		self.queue_free()
	return
