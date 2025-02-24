@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "Build Date Setter Script"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var general_manager : Object = load("res://Scripts/Globals/GeneralManager.gd").new()
	var export_file : ConfigFile = ConfigFile.new()
	export_file.set_value("data", "build_date", general_manager.call("get_date"))
	add_file("res://ExportData.cfg", export_file.encode_to_text().to_utf8_buffer(), true)
	return
