@tool
extends EditorExportPlugin

@export var target_extensions : Array = []
@export var read_directory : String = "res://"
@export var write_directory : String = "res://"
@export var print_info : bool = true

func _get_name() -> String:
	return "Custom Exporter Script"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not DirAccess.dir_exists_absolute(read_directory):
		push_error("ERROR: Error With 'CustomExporter' during '_export_begin': Invalid Read Directory Of: " + read_directory + ".")
		return
	if not DirAccess.dir_exists_absolute(write_directory):
		DirAccess.make_dir_absolute(write_directory)
	if print_info:
		print_rich("[i]N-Export is running with the extenion(s) of: " + str(target_extensions) + "[/i]")
	for file : String in PackedStringArray(Array(DirAccess.get_files_at(read_directory)).filter(func(file : String) -> bool: return file.get_extension() in target_extensions)):
		if print_info:
			print("N-Export Is Making File: " + str(write_directory + "/" + file))
		add_file(
			write_directory + "/" + file, 
			FileAccess.get_file_as_bytes(read_directory + "/" + file), 
			false)
	return
