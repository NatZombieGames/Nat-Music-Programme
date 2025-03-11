extends Node

@export var icons : Dictionary = {}
@export var is_valid_image : Callable = (func(path : String) -> bool: return path != "" and (path.is_absolute_path() or path.is_relative_path()) and path.get_extension() in ["jpg", "jpeg", "ktx", "png", "svg", "tga", "webp"])
@export var image_cache : Dictionary[String, Image] = {}
@export var image_average_cache : Dictionary[String, Color] = {}
@export var set_mouse_busy_state : Callable = (func(busy : bool) -> void: DisplayServer.cursor_set_shape([DisplayServer.CURSOR_ARROW, DisplayServer.CURSOR_BUSY][int(busy)]); return)
@export var is_valid_keybind : Callable = (func(event : InputEvent) -> bool: return ((event.get_class() != "InputEventMouseMotion") and (event.is_pressed()) and (get_event_code(event) not in banned_keycodes)))
@export var is_in_debug : bool = true
@export var cli_print_callable : Callable = (func(msg : String) -> void: get_node("/root/MainScreen/Camera/AspectRatioContainer/CommandLineInterface").call("print_to_output", msg); return)
@export var version : String = ""
@export var build : String = ""
@export var export_data : PackedStringArray = ["1970-1-1 (Thursday) | 00:00", "Godot Version Undetermined", "License Undetermined", "Architecture Undetermined"]
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
const export_data_names : PackedStringArray = ["build_date", "engine_build_version", "license", "architecture"]
const repo_url : String = "https://github.com/NatZombieGames/Nat-Music-Programme"
const valid_audio_types : PackedStringArray = ["mp3", "ogg", "wav"]
const weekday_names : PackedStringArray = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const month_names : PackedStringArray = ["Janauary", "Febuary", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const boolean_strings : PackedStringArray = ["1", "true", "enabled", "yes", "on"]
@warning_ignore("unused_signal")
signal finished_loading_icons_signal

func _ready() -> void:
	is_in_debug = not OS.has_feature("release") or (OS.has_feature("debug") and not OS.has_feature("editor"))
	build = ["Release", "Debug"][int(is_in_debug)]
	version = ProjectSettings.get("application/config/version")
	if not is_in_debug:
		#print("we are not in debug so are getting the export data, does the file exist? " + str(FileAccess.file_exists("res://ExportData.cfg")))
		var export_file : ConfigFile = ConfigFile.new()
		export_file.load("res://ExportData.cfg")
		for i : int in range(0, len(export_data_names)):
			export_data[i] = export_file.get_value("data", export_data_names[i], export_data[i])
	if not MasterDirectoryManager.finished_loading_data:
		await MasterDirectoryManager.finished_loading_data_signal
	cli_print_callable.call("SYS: Launching NMP Version [u]" + version + "[/u] In [u]" + build + "[/u] Mode At [u]" + get_date() + "[/u].")
	_load_icons()
	return

func _load_icons() -> void:
	finished_loading_icons = false
	icons = {}
	#print("\n\nfiles in icons:")
	#Array(Array(DirAccess.get_files_at("res://Assets/Icons")).filter(func(file : String) -> bool: return file.get_extension() == "svg")).map(func(item : String) -> String: print("- " + item); return item)
	#print("\n\n")
	for icon : String in PackedStringArray(Array(DirAccess.get_files_at("res://Assets/Icons")).filter(func(file : String) -> bool: return file.get_extension() == "svg")):
		icons[icon.left(icon.find("."))] = (func() -> Image: var to_return : Image = load_svg_to_img("res://Assets/Icons" + "/" + icon, MasterDirectoryManager.user_data_dict["icon_scale"]).get_image(); return to_return).call()
	await get_tree().process_frame
	finished_loading_icons = true
	self.emit_signal("finished_loading_icons_signal")
	return

func load_svg_to_img(svg_path : String, scale : float = 1.0) -> ImageTexture:
	# Code inspired from https://forum.godotengine.org/t/how-to-leverage-the-scalability-of-svg-in-godot/82292
	# But made for single-use instead.
	var bitmap : Image = Image.new()
	bitmap.load_svg_from_buffer(FileAccess.get_file_as_bytes(svg_path), scale)
	var texture : ImageTexture = ImageTexture.create_from_image(bitmap)
	texture.resource_name = svg_path.get_file().left(svg_path.get_file().find("."))
	return ImageTexture.create_from_image(bitmap)

func set_general_settings(setting : StringName, value : Variant) -> int:
	if setting in settable_settings and typeof(value) == typeof(self.get(setting)):
		cli_print_callable.call("NOTIF: General Settings: Set [u]" + setting + "[/u] from [u]" + str(self.get(setting)) + "[/u] > [u]" + str(value) + "[/u].")
		self.set(setting, value)
	if not setting in settable_settings:
		GeneralManager.cli_print_callable.call("ERROR: Setting [u]" + setting + "[/u] does not exist in General Settings or is unable to be set. Did you mean '[u]" + GeneralManager.spellcheck(setting, settable_settings)[0] + "[/u]'?.")
	else:
		GeneralManager.cli_print_callable.call("ERROR: Tried to set [u]" + setting + "[/u] whos value is of type [u]" + type_string(typeof(self.get(setting))) + "[/u] to [u]" + str(value) + "[/u] which is of type [u]" + type_string(typeof(value)) + "[/u].")
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

func packed_string_filter(arr : PackedStringArray, filter : Callable) -> PackedStringArray:
	var to_ret : PackedStringArray
	for item : String in arr:
		if filter.call(item) == true:
			to_ret.append(item)
	return to_ret

func get_icon_texture(icon_name : StringName = &"Missing") -> ImageTexture:
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

func spellcheck(query : String, words : PackedStringArray, return_max : int = 5, max_edit_distance : int = 0) -> PackedStringArray:
	var to_ret : Array[String]
	var word_to_dist_dict : Dictionary
	for word : String in words:
		word_to_dist_dict[word] = _get_word_distance(query, word)
	if max_edit_distance != 0:
		for key : String in word_to_dist_dict.keys():
			if word_to_dist_dict[key] > max_edit_distance:
				word_to_dist_dict.erase(key)
	to_ret.assign(word_to_dist_dict.keys())
	to_ret.sort_custom(func(key1 : String, key2 : String) -> bool: return word_to_dist_dict[key1] < word_to_dist_dict[key2])
	if len(to_ret) > return_max:
		to_ret.resize(return_max)
	return to_ret

func _get_word_distance(word1 : String, word2 : String) -> int:
	var dist : int = 0
	var word1_letters : Dictionary
	var word2_letters : Dictionary
	for character : String in get_unique_array(word1.split("", false)):
		word1_letters[character] = word1.count(character)
	for character : String in get_unique_array(word2.split("", false)):
		word2_letters[character] = word2.count(character)
	for key : String in word1_letters.keys():
		if word2_letters.get(key, 0) != word1_letters[key]:
			if word1_letters[key] >= word2_letters.get(key, 0):
				dist += word1_letters[key] - word2_letters.get(key, 0)
			else:
				dist += word2_letters[key] - word1_letters[key]
	if len(word1) < len(word2):
		dist += len(word2) - len(word1)
	elif len(word1) > len(word2):
		dist += len(word1) - len(word2)
	return dist

func load_audio_file(path : String) -> AudioStream:
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	var sound : AudioStream
	if path.get_extension() in valid_audio_types:
		match path.get_extension():
			"mp3":
				sound = AudioStreamMP3.new()
				sound.data = file.get_buffer(file.get_length())
			"ogg":
				sound = AudioStreamOggVorbis.load_from_file(path)
			"wav":
				sound = AudioStreamWAV.load_from_file(path)
	return sound

func get_id_type(id : String) -> MasterDirectoryManager.use_type:
	#print("Get id is running with an id of; " + id + ", which is " + str(len(id)) + " long and starts with " + id.left(1) + " and " + ["isnt", "is"][int(int(id.left(1)) > -1 and int(id.left(1)) < len(MasterDirectoryManager.data_types)-1)] + " inside the use type enum")
	if (len(id) == 17) and (int(id.left(1)) > -1) and (int(id.left(1)) < (len(MasterDirectoryManager.use_type.keys()) - 1)):
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

func limit_str(string : String, size : int, limiter : String = "…") -> String:
	if len(string) > size:
		return string.left((len(string) - size) * -1) + limiter
	return string

func smart_limit_str(strings : Array[String], size : int, limiter : String = "…") -> String:
	var strings_len : int = strings.reduce(func(total : int, item : String) -> int: return total + len(item), 0)
	if strings_len <= size:
		return strings.reduce(func(total : String, item : String) -> String: return total + item, "")
	var len_remaining : int = size - strings_len
	var to_return : String = ""
	var string_lengths : Array[int] = []
	var index : int = 0
	string_lengths.assign(strings.map(func(item : String) -> int: return len(item)))
	while len_remaining < 0:
		index = string_lengths.find(string_lengths.max())
		string_lengths[index] -= 1
		strings[index] = strings[index].left(-2) + limiter
		len_remaining += 1
	to_return = strings.reduce(func(total : String, item : String) -> String: return total + item, "")
	return to_return

func int_to_hex(num : int) -> String:
	return "%x" % [num]

func int_to_readable_int(num : int) -> String:
	var to_return : String = ""
	var reversed : String = str(num).reverse()
	for i : int in range(0, len(reversed)):
		if i != 0 and i != len(reversed) and i % 3 == 0:
			to_return += ","
		to_return += reversed[i]
	return to_return.reverse()

func get_date(include_date : bool = true, include_weekday : bool = true, include_time : bool = true) -> String:
	if not include_date and not include_weekday and not include_time:
		return ""
	var date_dict : Dictionary = Time.get_date_dict_from_system()
	date_dict.merge(Time.get_time_dict_from_system())
	for item : String in date_dict.keys():
		date_dict[item] = str(date_dict[item])
	date_dict = {
		"date": date_dict["year"] + "-" + date_dict["month"] + "-" + date_dict["day"], 
		"weekday": weekday_names[int(date_dict["weekday"])-1], 
		"time": date_dict["hour"] + ":" + date_dict["minute"]}
	if include_date and include_weekday and include_time:
		return date_dict["date"] + " (" + date_dict["weekday"] + ") | " + date_dict["time"]
	return [date_dict["date"], ""][int(!include_date)] + ["", " "][int(include_weekday and include_date)] + [["", "("][int(include_date)] + date_dict["weekday"] + ["", ")"][int(include_date)], ""][int(!include_weekday)] + ["", " | "][int(include_time and (include_date or include_weekday))] + [date_dict["time"], ""][int(!include_time)]

func seconds_to_readable_time(seconds : int) -> String:
	if seconds < 60:
		return str(seconds) + "s"
	elif seconds < 3600:
		@warning_ignore("integer_division")
		return str(seconds / 60) + "m" + str(seconds % 60) + "s"
	@warning_ignore("integer_division")
	return str(seconds / 3600) + "h" + str((seconds % 3600) / 60) + "m" + str((seconds % 3600) % 60) + "s"

func sort_alphabetically(arr : Array) -> PackedStringArray:
	arr.sort_custom(func(item1 : String, item2 : String) -> bool: return item2 > item1)
	return PackedStringArray(arr)

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
