extends RichTextLabel

static func _on_meta_clicked(meta : String) -> void:
	OS.shell_open(meta)
	return

func _on_meta_hover_started(meta : String) -> void:
	if len($/root/MainScreen/Camera/AspectRatioContainer/TooltipContainer.get_children()) < 1:
		$/root/MainScreen.call("create_tooltip", meta)
	return
