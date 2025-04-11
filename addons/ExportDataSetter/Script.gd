@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "Export Data Setter Script"

func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var general_manager : Object = load("res://Scripts/Globals/GeneralManager.gd").new()
	var version_info : Dictionary = Engine.get_version_info()
	var export_file : ConfigFile = ConfigFile.new()
	export_file.set_value("data", "build_date", str(int(Time.get_unix_time_from_system())))
	export_file.set_value("data", "engine_build_version", "V" + str(version_info["major"]) + "." + str(version_info["minor"]) + "." + str(version_info["patch"]))
	export_file.set_value("data", "license", FileAccess.open("res://LICENSE.txt", FileAccess.READ).get_as_text().get_slice("\n", 2))
	export_file.set_value("data", "architecture", Array(features).filter(func(item : String) -> bool: return item.left(1) == "x" or item.left(3) == "arm")[0])
	add_file("res://ExportData.cfg", export_file.encode_to_text().to_utf8_buffer(), true)
	return
