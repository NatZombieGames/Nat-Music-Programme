extends PanelContainer

@export var title : String = "Placeholder"
@export var custom_min_size : Vector2 = Vector2(240, 25)

func _ready() -> void:
	self.visible = false
	return

func update(new_title : String = title, new_custom_min_size : Vector2 = custom_min_size) -> void:
	$Title.text = new_title
	self.custom_minimum_size = new_custom_min_size
	create_tween().tween_property(self, "global_position", Vector2(get_global_mouse_position().x, get_global_mouse_position().y-50), 2).from(get_global_mouse_position())
	self.visible = true
	await create_tween().tween_property(self, "modulate", Color(1, 1, 1, 0), 2).from(Color(1, 1, 1, 1)).finished
	self.queue_free()
	return
