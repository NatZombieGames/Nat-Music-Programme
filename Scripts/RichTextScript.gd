extends RichTextLabel

func _ready() -> void:
	if not MasterDirectoryManager.finished_loading_data:
		await MasterDirectoryManager.finished_loading_data_signal
	for type : String in ["bold_italics", "italics", "mono", "normal", "bold"]:
		self.set("theme_override_font_sizes/" + type + "_font_size", 16.0 * MasterDirectoryManager.user_data_dict["cli_size_modifier"])
	return

static func _on_meta_clicked(meta : String) -> void:
	OS.shell_open(meta)
	return

func _on_meta_hover_started(meta : String) -> void:
	if len($/root/MainScreen/Camera/AspectRatioContainer/TooltipContainer.get_children()) < 1:
		$/root/MainScreen.call("create_tooltip", meta)
	return
