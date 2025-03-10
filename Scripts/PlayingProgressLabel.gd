extends Label

const code : String = "extends Node

func _process(_delta : float) -> void:
    self.text = get_node('/root/MainScreen/Camera/AspectRatioContainer/PlayerContainer/PlayingScreen/Camera/ScreenContainer/MasterContainer/InfoPanel/InfoContainer/ProgressContainer/Percentage').tooltip_text
    return"

func _make_custom_tooltip(_tip_text : String) -> Control:
	var label : Label = Label.new()
	var script : GDScript = GDScript.new()
	script.source_code = code
	script.reload()
	label.set_script(script)
	return label
