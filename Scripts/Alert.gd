extends Control

@export var title : String = "ALERT!":
	set(value):
		title = value
		$Panel/Container/Title.text = " " + title
@export var text : String = "Placeholder":
	set(value):
		text = value
		$Panel/Container/Content.text = text

func _ready() -> void:
	self.visible = false
	return

func fire() -> void:
	$Panel.modulate.a = 0
	self.visible = true
	var tween : Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.pause()
	tween.tween_property($Panel, "position:y", $Panel.position.y, 0.2).from($Panel.position.y + 25)
	tween.tween_property($Panel, "position:x", $Panel.position.x, 0.2).from($Panel.position.x - 25)
	tween.tween_property($Panel, "modulate:a", 1, 0.2).from(0)
	tween.play()
	await tween.finished
	tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT)#.set_trans(Tween.TRANS_SINE)
	tween.pause()
	tween.tween_property($Panel, "position:y", $Panel.position.y - 300, 15).from($Panel.position.y)
	tween.tween_property($Panel, "modulate:a", 0, 15).from(1)
	tween.play()
	await tween.finished
	self.queue_free()
	return
