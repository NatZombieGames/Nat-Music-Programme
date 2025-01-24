extends Node

@export var icons : Dictionary = {}
@export var is_valid_image : Callable = (func(path): return path != "" and (path.is_absolute_path() or path.is_relative_path()) and path.get_extension() in ["jpg", "jpeg", "ktx", "png", "svg", "tga", "webp"])
@export var image_cache : Dictionary = {}
@export var image_average_cache : Dictionary = {}
@export var set_mouse_busy_state : Callable = (func(busy : bool): DisplayServer.cursor_set_shape([DisplayServer.CURSOR_ARROW, DisplayServer.CURSOR_BUSY][int(busy)]))
const key_keycodes : PackedInt32Array = [4194304, 4194305, 4194306, 4194307, 4194308, 4194309, 4194310, 4194311, 4194312, 4194313, 4194314, 4194315, 4194316, 4194317, 4194318, 4194319, 4194320, 4194321, 4194322, 4194323, 4194324, 4194325, 4194326, 4194327, 4194328, 4194329, 4194330, 4194331, 4194332, 4194333, 4194334, 4194335, 4194336, 4194337, 4194338, 4194339, 4194340, 4194341, 4194342, 4194343, 4194344, 4194345, 4194346, 4194347, 4194348, 4194349, 4194350, 4194351, 4194352, 4194353, 4194354, 4194355, 4194356, 4194357, 4194358, 4194359, 4194360, 4194361, 4194362, 4194363, 4194364, 4194365, 4194366, 4194433, 4194434, 4194435, 4194436, 4194437, 4194438, 4194439, 4194440, 4194441, 4194442, 4194443, 4194444, 4194445, 4194446, 4194447, 4194370, 4194371, 4194373, 4194376, 4194377, 4194378, 4194379, 4194380, 4194381, 4194382, 4194388, 4194389, 4194390, 4194391, 4194392, 4194393, 4194394, 4194395, 4194396, 4194397, 4194398, 4194399, 4194400, 4194401, 4194402, 4194403, 4194404, 4194405, 4194406, 4194407, 4194408, 4194409, 4194410, 4194411, 4194412, 4194413, 4194414, 4194415, 4194416, 4194417, 4194418, 4194419, 8388607, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 123, 124, 125, 126, 165, 167]
const mouse_keycodes : PackedInt32Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

func _ready() -> void:
	print("I am " + ["in the editor.", "exported."][int(OS.has_feature("release") or (OS.has_feature("debug") and not OS.has_feature("editor")))])
	#print("Icons In Folder: " + str(DirAccess.get_files_at("res://Assets/Icons")).replace('", "', '"\n"'))
	for item in Array(DirAccess.get_files_at("res://Assets/Icons")).filter(func(item : String) -> bool: return [not item.right(7) == ".import", true][int(OS.has_feature("release") or (OS.has_feature("debug") and not OS.has_feature("editor")))]):
		#print("- Trying to load file at: res://Assets/Icons/" + item + ", that path " + ["doesn't", "does"][int(FileAccess.file_exists("res://Assets/Icons/" + item))] + " exist.")
		icons[item.replace(".svg", "").replace(".import", "")] = (func(file_name : String) -> Image: var to_return : Image = ResourceLoader.load("res://Assets/Icons/" + file_name.replace(".import", ""), "CompressedTexture2D").get_image(); to_return.resource_name = file_name.replace(".svg", ""); return to_return).call(item)
	#print("Icons Dict After Load: " + str(icons).replace('>, "', '>\n"') + "\n\n")
	return

func get_data(id : String, data_name : String = "") -> Variant:
	#print("Id: " + id)
	#print("data name: " + data_name)
	if id == "" or id == "Unknown":
		return "Unknown"
	var data_set : String = ["artist_id_dict", "album_id_dict", "song_id_dict", "playlist_id_dict"][int(id.left(1))]
	#print("Get data data set: " + data_set)
	#print("Id in data set of " + data_set + ": " + str(MasterDirectoryManager.get(data_set).has(id)))
	#print("data set content: " + str(MasterDirectoryManager.get(data_set)).replace(" }, ", " }\n\n"))
	if data_name == "":
		#print("get_data is returning: " + str(MasterDirectoryManager.get(data_set).get(id)))
		return MasterDirectoryManager.get(data_set).get(id)
	#print("get_data is returning: " + str(MasterDirectoryManager.get(data_set).get(id)[data_name]))
	return MasterDirectoryManager.get(data_set).get(id)[data_name]

func get_image_average(image : Image) -> Color:
	#print("\n\ntrying to get image average of " + image.resource_name + ", it " + ["is", "isnt"][int(image.resource_name not in image_average_cache.keys())] + " in the cache")
	if image.resource_name not in image_average_cache.keys():
		#print("image was not in cache, making image average\n\n")
		var colour : Vector3 = Vector3.ZERO
		for i in range(0, image.get_size().x):
			for i2 in range(0, image.get_size().y):
				var pixel : Color = image.get_pixelv(Vector2i(i, i2))
				colour += Vector3(pixel.r, pixel.g, pixel.b)
		colour /= (image.get_size().x * image.get_size().y)
		image_average_cache[image.resource_name] = Color(colour.x, colour.y, colour.z)
	return image_average_cache[image.resource_name]

func get_other_list_item(array : Array, item : Variant) -> Variant:
	if len(array) == 2 and item in array:
		return array[int(!bool(array.find(item)))]
	return item

func get_icon_texture(icon_name : String = "Missing") -> ImageTexture:
	return (func(icons_name : String) -> ImageTexture: var image : ImageTexture = ImageTexture.create_from_image(icons[icons_name]); image.resource_name = icons_name; return image).call(icon_name)

func get_image(path : String) -> Image:
	#print("get img path: " + path + ", is get img path valid: " + str(is_valid_image.call(path)))
	if is_valid_image.call(path):
		var file : FileAccess = FileAccess.open(path, FileAccess.READ)
		var img : Image = Image.new()
		#print("attempting to call '" + "load_" + path.get_extension() + "_from_buffer'")
		img.call("load_" + path.get_extension() + "_from_buffer", file.get_buffer(file.get_length()))
		img.resource_name = path.get_file().get_basename()
		#print("returning the img in get_image of: " + str(img))
		return img
	#print("returning default image in get_image")
	return get_icon_texture().get_image()

func get_image_from_cache(path : String) -> Image:
	if path in image_cache.keys():
		#print("returned image from cache using path: " + path)
		return image_cache[path]
	if is_valid_image.call(path):
		#print("image not in cache, added it using path: " + path)
		image_cache[path] = get_image(path)
		return image_cache[path]
	#print("image not in cache and path is invalid, return default.")
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
	#print("Get id is running with an id of; " + id + ", which is " + str(len(id)) + " long and starts with " + id.left(1) + " and " + ["isnt", "is"][int(int(id.left(1)) > -1 and int(id.left(1)) < len(MasterDirectoryManager.get_data_types.call())-1)] + " inside the use type enum")
	if len(id) > 1 and int(id.left(1)) > -1 and int(id.left(1)) < len(MasterDirectoryManager.get_data_types.call())-1:
		return MasterDirectoryManager.use_type.get(MasterDirectoryManager.use_type.keys()[int(id.left(1))])
	return MasterDirectoryManager.use_type.UNKNOWN

func n_get_parent(start : Node, number : int = 0) -> Node:
	var node : Node = start
	for i in range(0, number):
		node = node.get_parent()
	return node

func disconnect_all_connections(node_signal : Signal) -> void:
	for item in node_signal.get_connections():
		node_signal.disconnect(item["callable"])
	return

func arr_get(arr : Array[Variant], index : int, default : Variant) -> Variant:
	if index < len(arr):
		return arr[index]
	return default

func limit(string : String, size : int, limiter : String = "...") -> String:
	if len(string) > size:
		return string.left((len(string) - size) * -1) + limiter
	return string

func get_input_event(keycode : int) -> InputEvent:
	if keycode in key_keycodes:
		return (func() -> InputEventKey: var key = InputEventKey.new(); key.keycode = keycode; return key).call()
	elif keycode in mouse_keycodes:
		return (func() -> InputEventMouseButton: var key = InputEventMouseButton.new(); key.button_index = keycode; return key).call()
	return null

func get_event_code(event : InputEvent) -> int:
	if event.get_class() == "InputEventKey":
		return event.keycode
	elif event.get_class() == "InputEventMouseButton":
		return event.button_index
	return -1
