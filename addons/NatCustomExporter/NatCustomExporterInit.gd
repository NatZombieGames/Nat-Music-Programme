@tool
extends EditorPlugin

var plugin : EditorExportPlugin = load("res://addons/NatCustomExporter/Script.gd").new()
const plugin_config : Dictionary = {
	"read_directory": "res://Assets/Icons", 
	"write_directory": "res://Assets/Icons", 
	"target_extensions": ["svg"], 
	"print_info": false}

func _get_plugin_name() -> String:
	return "Nat Custom Exporter"

func _enter_tree() -> void:
	for setting : String in plugin_config.keys():
		plugin.set(setting, plugin_config[setting])
	add_export_plugin(plugin)
	return

func _exit_tree() -> void:
	remove_export_plugin(plugin)
	return
