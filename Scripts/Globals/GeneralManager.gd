extends Node

@export var icons : Dictionary = {}
@export var is_valid_image : Callable = (func(path : String) -> bool: return path != "" and (path.is_absolute_path() or path.is_relative_path()) and path.get_extension() in ["jpg", "jpeg", "ktx", "png", "svg", "tga", "webp"])
@export var image_cache : Dictionary = {}
@export var image_average_cache : Dictionary = {}
@export var set_mouse_busy_state : Callable = (func(busy : bool) -> void: DisplayServer.cursor_set_shape([DisplayServer.CURSOR_ARROW, DisplayServer.CURSOR_BUSY][int(busy)]); return)
@export var is_valid_keybind : Callable = (func(event : InputEvent) -> bool: return ((event.get_class() != "InputEventMouseMotion") and (event.is_pressed()) and (get_event_code(event) not in banned_keycodes)))
@export var is_in_debug : bool = true
@export var cli_print_callable : Callable = (func(msg : String) -> void: get_node("/root/MainScreen/Camera/AspectRatioContainer/CommandLineInterface").call("print_to_output", msg); return)
@export var version : String = ""
@export var build : String = ""
@export var rng_seed : int = 0:
	set(value):
		rng_seed = value
		seed(value)
	get:
		return rng_seed
@export var finished_loading_icons : bool = false
const key_keycodes : PackedInt32Array = [4194304, 4194305, 4194306, 4194307, 4194308, 4194309, 4194310, 4194311, 4194312, 4194313, 4194314, 4194315, 4194316, 4194317, 4194318, 4194319, 4194320, 4194321, 4194322, 4194323, 4194324, 4194325, 4194326, 4194327, 4194328, 4194329, 4194330, 4194331, 4194332, 4194333, 4194334, 4194335, 4194336, 4194337, 4194338, 4194339, 4194340, 4194341, 4194342, 4194343, 4194344, 4194345, 4194346, 4194347, 4194348, 4194349, 4194350, 4194351, 4194352, 4194353, 4194354, 4194355, 4194356, 4194357, 4194358, 4194359, 4194360, 4194361, 4194362, 4194363, 4194364, 4194365, 4194366, 4194433, 4194434, 4194435, 4194436, 4194437, 4194438, 4194439, 4194440, 4194441, 4194442, 4194443, 4194444, 4194445, 4194446, 4194447, 4194370, 4194371, 4194373, 4194376, 4194377, 4194378, 4194379, 4194380, 4194381, 4194382, 4194388, 4194389, 4194390, 4194391, 4194392, 4194393, 4194394, 4194395, 4194396, 4194397, 4194398, 4194399, 4194400, 4194401, 4194402, 4194403, 4194404, 4194405, 4194406, 4194407, 4194408, 4194409, 4194410, 4194411, 4194412, 4194413, 4194414, 4194415, 4194416, 4194417, 4194418, 4194419, 8388607, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 123, 124, 125, 126, 165, 167]
const mouse_keycodes : PackedInt32Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const banned_keycodes : PackedInt32Array = [4194325, 4194326, 4194328]
const key_modifiers : PackedStringArray = ["alt_pressed", "shift_pressed", "ctrl_pressed"]
const settable_settings : PackedStringArray = ["rng_seed"]
@warning_ignore("unused_signal")
signal finished_loading_icons_signal

func _ready() -> void:
	is_in_debug = not OS.has_feature("release") or (OS.has_feature("debug") and not OS.has_feature("editor"))
	build = ["Release", "Debug"][int(is_in_debug)]
	version = ProjectSettings.get("application/config/version")
	if not MasterDirectoryManager.finished_loading_data:
		await MasterDirectoryManager.finished_loading_data_signal
	print("icon folder:")
	Array(DirAccess.get_files_at("res://Assets/Icons")).map(func(item : String) -> String: print(item); return item)
	print("loading files from list:\n" + str(Array(DirAccess.get_files_at("res://Assets/Icons")).filter(func(item : String) -> bool: print("wrapi for item " + item + " is " + str(int(item.right(7) == ".import") + int(is_in_debug)) + ": " + str(bool(wrapi(int(item.right(7) == ".import") + int(is_in_debug), 0, 2)))); return bool(wrapi(int(item.right(7) == ".import") + int(is_in_debug), 0, 2)))))
	for icon : String in Array(DirAccess.get_files_at("res://Assets/Icons")).filter(func(item : String) -> bool: return bool(wrapi(int(item.right(7) == ".import") + int(is_in_debug), 0, 2))):
		icons[icon.left(icon.find("."))] = (func(file : String) -> Image: var to_return : Image = load_svg_to_img("res://Assets/Icons/" + file).get_image(); to_return.resource_name = icon.left(icon.find(".")); return to_return).call(icon)
	print("icons after load: " + str(icons))
	await get_tree().process_frame
	cli_print_callable.call("[color=gray][i]Launching NMP Version [u]" + version + "[/u] In [u]" + build + "[/u] Mode.[/i][/color]")
	finished_loading_icons = true
	self.emit_signal("finished_loading_icons_signal")
	return

func set_general_settings(setting : StringName, value : Variant) -> int:
	if setting in settable_settings and typeof(value) == typeof(self.get(setting)):
		cli_print_callable.call("[i]General Settings: Set [u]" + setting + "[/u] from [u]" + str(self.get(setting)) + "[/u] > [u]" + str(value) + "[/u].[/i]")
		self.set(setting, value)
	return ERR_INVALID_PARAMETER

func get_general_settings() -> Dictionary:
	var data : Dictionary
	for setting : String in settable_settings:
		data[setting] = self.get(setting)
	return data

func get_data(id : String, data_name : String = "") -> Variant:
	if id == "" or id == "Unknown":
		return "Unknown"
	var data_set : String = ["artist_id_dict", "album_id_dict", "song_id_dict", "playlist_id_dict"][int(id.left(1))]
	if not id in MasterDirectoryManager.get(data_set).keys():
		return "Unknown"
	if data_name == "":
		return MasterDirectoryManager.get(data_set).get(id)
	return MasterDirectoryManager.get(data_set).get(id)[data_name]

func get_image_average(image : Image) -> Color:
	if image.resource_name not in image_average_cache.keys():
		var colour : Vector3 = Vector3.ZERO
		for i : int in range(0, image.get_size().x):
			for i2 : int in range(0, image.get_size().y):
				var pixel : Color = image.get_pixelv(Vector2i(i, i2))
				colour += Vector3(pixel.r, pixel.g, pixel.b)
		colour /= (image.get_size().x * image.get_size().y)
		image_average_cache[image.resource_name] = Color(colour.x, colour.y, colour.z)
		while len(image_average_cache.keys()) > MasterDirectoryManager.user_data_dict["image_cache_size"]:
			image_average_cache.erase(image_average_cache.keys()[0])
	return image_average_cache[image.resource_name]

func get_other_list_item(array : Array, item : Variant) -> Variant:
	if len(array) == 2 and item in array:
		return array[int(!bool(array.find(item)))]
	return item

func get_icon_texture(icon_name : StringName = "Missing") -> ImageTexture:
	return (func(icons_name : String) -> ImageTexture: var image : ImageTexture = ImageTexture.create_from_image(icons[icons_name]); image.resource_name = icons_name; return image).call(icon_name)

func get_image(path : String) -> Image:
	if path in image_cache.keys():
		return image_cache[path]
	elif is_valid_image.call(path):
		var file : FileAccess = FileAccess.open(path, FileAccess.READ)
		var img : Image = Image.new()
		img.call("load_" + path.get_extension() + "_from_buffer", file.get_buffer(file.get_length()))
		img.resource_name = path.get_file().get_basename()
		image_cache[path] = img
		while len(image_cache.keys()) > MasterDirectoryManager.user_data_dict["image_cache_size"]:
			image_cache.erase(image_cache.keys()[0])
		return image_cache[path]
	return get_icon_texture().get_image()

func load_audio_file(path : String) -> AudioStream:
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	var sound : AudioStream
	match path.get_extension():
		"mp3":
			sound = AudioStreamMP3.new()
			sound.data = file.get_buffer(file.get_length())
		"wav":
			sound = ResourceLoader.load(path, "AudioStreamWAV")
		"oog":
			sound = AudioStreamOggVorbis.load_from_file(path)
	return sound

func get_id_type(id : String) -> MasterDirectoryManager.use_type:
	print("Get id is running with an id of; " + id + ", which is " + str(len(id)) + " long and starts with " + id.left(1) + " and " + ["isnt", "is"][int(int(id.left(1)) > -1 and int(id.left(1)) < len(MasterDirectoryManager.get_data_types.call())-1)] + " inside the use type enum")
	if (len(id) == 17) and (int(id.left(1)) > -1) and (int(id.left(1)) < len(MasterDirectoryManager.get_data_types.call())):
		return MasterDirectoryManager.use_type.get(MasterDirectoryManager.use_type.keys()[int(id.left(1))])
	return MasterDirectoryManager.use_type.UNKNOWN

func disconnect_all_connections(node_signal : Signal) -> void:
	for connection : Dictionary in node_signal.get_connections():
		node_signal.disconnect(connection["callable"])
	return

func arr_get(arr : Array[Variant], index : int, default : Variant) -> Variant:
	if index < len(arr):
		return arr[index]
	return default

func limit_str(string : String, size : int, limiter : String = "...") -> String:
	if len(string) > size:
		return string.left((len(string) - size) * -1) + limiter
	return string

func get_input_event(keycode : int) -> InputEvent:
	if keycode in key_keycodes:
		@warning_ignore("int_as_enum_without_cast")
		return (func() -> InputEventKey: var key : InputEventKey = InputEventKey.new(); key.keycode = keycode; return key).call()
	elif keycode in mouse_keycodes:
		@warning_ignore("int_as_enum_without_cast")
		return (func() -> InputEventMouseButton: var key : InputEventMouseButton = InputEventMouseButton.new(); key.button_index = keycode; return key).call()
	return null

func get_event_code(event : InputEvent) -> int:
	match event.get_class():
		"InputEventKey":
			return event.physical_keycode
		"InputEventMouseButton":
			return event.button_index
	return -1

func parse_inputevent_to_customevent(event : InputEvent) -> Dictionary:
	var data : Dictionary = {"code": 0, "alt_pressed": false, "shift_pressed": false, "ctrl_pressed": false}
	data["code"] = get_event_code(event)
	for item : String in key_modifiers:
		data[item] = event.get(item)
	return data

func parse_customevent_to_inputevent(dict : Dictionary) -> InputEvent:
	var event : InputEvent
	if dict["code"] in key_keycodes:
		event = InputEventKey.new()
		event.physical_keycode = dict["code"]
	elif dict["code"] in mouse_keycodes:
		event = InputEventMouseButton.new()
		event.button_index = dict["code"]
	for item : String in key_modifiers:
		event.set(item, dict[item])
	event.set("pressed", true)
	return event

func customevent_to_string(event : Dictionary) -> String:
	var to_return : String = ["Alt+", ""][int(not event["alt_pressed"])] + ["Shift+", ""][int(not event["shift_pressed"])] + ["Ctrl+", ""][int(not event["ctrl_pressed"])]
	if event["code"] in key_keycodes:
		return to_return + OS.get_keycode_string(event["code"])
	elif event["code"] in mouse_keycodes:
		match event["code"]:
			1:
				to_return += "LeftMouseButton"
			2:
				to_return += "RightMouseButton"
			3:
				to_return += "MiddleMouseButton"
			4:
				to_return += "MouseWheelUp"
			5:
				to_return += "MouseWheelDown"
			6:
				to_return += "MouseWheelLeft"
			7:
				to_return += "MouseWheelRight"
			8:
				to_return += "MouseWheelExtra1"
			9:
				to_return += "MouseWheelExtra2"
			_:
				to_return = "Null"
		return to_return
	return "Null"

func load_svg_to_img(svg_path : String, scale : float = 1.0) -> ImageTexture:
	#Code inspired from https://forum.godotengine.org/t/how-to-leverage-the-scalability-of-svg-in-godot/82292
	#But made for single-use instead.
	var bitmap : Image = Image.new()
	print("trying to load svg from path: " + svg_path + "\ndoes this path exist? " + str(FileAccess.file_exists(svg_path)) + "\nis this file empty? " + str(len(FileAccess.open(svg_path, FileAccess.READ).get_as_text()) == 0))
	bitmap.load_svg_from_buffer(FileAccess.get_file_as_bytes(svg_path), scale)
	var texture : ImageTexture = ImageTexture.create_from_image(bitmap)
	texture.resource_name = svg_path.get_file().replace(".svg", "").replace(".import", "")
	#print("name: " + str(texture.resource_name))
	return ImageTexture.create_from_image(bitmap)

func bool_arr_to_num(bools : Array[bool], size : int = 16) -> int:
	bools.resize(size)
	var bin : String = bools.reduce(func(total : String, item : bool) -> String: return total + str(int(item)), "")
	return bin.bin_to_int()

func num_to_bool_arr(num : int, size : int = 16) -> Array[bool]:
	var bools : Array[bool]
	for item : String in String.num_int64(num, 2):
		bools.append(bool(int(item)))
	bools.resize(size)
	return bools

func get_unique_array(arr : Array[Variant]) -> Array[Variant]:
	var to_return : Array[Variant]
	arr.map(func(item : Variant) -> Variant: 
		if not item in to_return:
			to_return.append(item)
		return)
	return to_return

func navigate_node(node : Node, path : String) -> Node:
	for code : String in path.split(",", false):
		if code == "˄":
			node = node.get_parent()
		elif code.is_valid_int():
			node = node.get_child(int(code))
	return node
