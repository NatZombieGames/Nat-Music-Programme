extends Label

func _make_custom_tooltip(tip_text : String) -> Control:
	if tip_text != "":
		#$/root/MainScreen/Camera/AspectRatioContainer/PlayerContainer/PlayingScreen.create_tooltip(tip_text)
		var label : Label = Label.new()
		label.text = tip_text
		return label
	return
