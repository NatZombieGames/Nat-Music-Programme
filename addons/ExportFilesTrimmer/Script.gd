@tool
extends EditorExportPlugin

@export var files_to_trim : PackedStringArray = [
	"res://Assets/ShowcaseImages/Showcase_1.png", 
	"res://Assets/ShowcaseImages/Showcase_2.png",
	"res://Assets/ShowcaseImages/Showcase_3.png",
	"res://Assets/ShowcaseImages/Showcase_4.png",
	"res://Assets/ShowcaseImages/Showcase_5.png",
	"res://ReadMe.md",
	"res://export_presets.cfg",
	"res://addons/ExportDataSetter/ExportDataSetterInit.gd",
	"res://addons/ExportDataSetter/plugin.cfg",
	"res://addons/ExportDataSetter/Script.gd",
	"res://addons/ExportFilesTrimmer/ExportFilesTrimmerInit.gd",
	"res://addons/ExportFilesTrimmer/plugin.cfg",
	"res://addons/ExportFilesTrimmer/Script.gd",
	"res://addons/NatCustomExporter/NatCustomExporterInit.gd",
	"res://addons/NatCustomExporter/plugin.cfg",
	"res://addons/NatCustomExporter/Script.gd",
	]

func _get_name() -> String:
	return "Export Files Trimmer Script"

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path in files_to_trim:
		skip()
	return
