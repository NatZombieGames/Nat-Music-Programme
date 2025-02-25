@tool
extends EditorPlugin

var plugin : EditorExportPlugin = load("res://addons/BuildDateSetter/Script.gd").new()

func _get_plugin_name() -> String:
	return "Build Date Setter"

func _apply_changes() -> void:
	if plugin.get_script().source_code != FileAccess.open("res://addons/BuildDateSetter/Script.gd", FileAccess.READ).get_as_text():
		print("changing!")
		remove_export_plugin(plugin)
		plugin = load("res://addons/BuildDateSetter/Script.gd").new()
		add_export_plugin(plugin)
	return

func _enter_tree() -> void:
	add_export_plugin(plugin)
	return

func _exit_tree() -> void:
	remove_export_plugin(plugin)
	return
