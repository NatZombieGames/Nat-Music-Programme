extends Node

@export var artist_id_dict : Dictionary = {}
@export var album_id_dict : Dictionary = {}
@export var song_id_dict : Dictionary = {}
@export var playlist_id_dict : Dictionary = {}
@export var user_data_dict : Dictionary = {}
@export var finished_loading_data : bool = false
@export var finished_saving_data : bool = false
@export var get_data_types : Callable = (func() -> Array: return use_type.keys().map(func(key : String) -> String: return key.to_lower()).filter(func(key : String) -> bool: return key != "unknown"))
@export var get_object_data : Callable = (func(id : String) -> Dictionary: return self.get(get_data_types.call()[int(id[0])] + "_id_dict")[id])
var data_location : String = ""
#   const after ready
@warning_ignore("unused_signal")
signal finished_loading_data_signal
signal finished_saving_data_signal
const default_user_data : Dictionary = {
	"volume": -10, "player_fullscreen": false, "special_icon_scale": 2, "icon_scale": 1, "song_cache_size": 3, "image_cache_size": 20, "player_widgets": [false, false], "auto_clear": false, "clear_input": false, "shuffle": false, "command_on_startup": "", "window_position": Vector2.ZERO, "window_mode": DisplayServer.WINDOW_MODE_MAXIMIZED, "window_screen": 0, "window_size": Vector2(960, 540), "save_on_quit": true, "continue_playing": true, "continue_playing_exact": true, "active_song_data": {"active_song_list": [], "active_song_list_id": "", "active_song_id": "", "song_progress": 0}, "keybinds": {}}
const id_chars : PackedStringArray = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", 
"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", 
"I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", 
"3", "4", "5", "6", "7", "8", "9", "!", '"', "£", "$", "%", "^", "&", "*", "(", ")", "¤", "_", "=", "+", 
"{", "}", ":", ";", "'", "@", "~", "#", ",", "<", ".", ">", "/", "?", "|", "`", "¬", "¥", "¢", "§", "¦", 
"¯", "±", "²", "³", "´", "˄", "˅", "ˆ", "ϕ", "ʭ", "ϖ", "ϣ", "Ϣ", "Ж", "Џ", "λ", "ϐ", "Ͼ", "Ͽ", "Ͻ", "•", 
"·", "¶"]
var keybinds : Dictionary = {} # const after ready is finished
var settable_settings : PackedStringArray = ["volume", "player_fullscreen", "special_icon_scale", "icon_scale", "song_cache_size", "image_cache_size", "player_widgets", "auto_clear", "clear_input", "shuffle", "command_on_startup", "window_position", "window_mode", "window_screen", "window_size", "save_on_quit", "continue_playing", "continue_playing_exact"]
enum use_type {ARTIST, ALBUM, SONG, PLAYLIST, UNKNOWN}

func _ready() -> void:
	data_location = OS.get_executable_path().get_base_dir() + "/NMP_Data.dat"
	for item : String in InputMap.get_actions().filter(func(item : String) -> bool: return not item.left(3) == "ui_"):
		keybinds[item] = Array(InputMap.action_get_events(item).map(func(event : InputEvent) -> Dictionary: return GeneralManager.parse_inputevent_to_customevent(event)))
		if len(keybinds[item]) < 2:
			keybinds[item] = [keybinds[item][0], ""]
	keybinds.make_read_only()
	print(str("- - - - -\nkeybinds after completion: " + str(keybinds).replace('], "', ']\n= "')).replace('completion: { "', 'completion:\n= { "'))
	return

func _notification(notif : int) -> void:
	if notif == Node.NOTIFICATION_WM_CLOSE_REQUEST and user_data_dict["save_on_quit"] == true:
		print("received quit notification and save on quit is true; saving data.")
		save_data()
		await get_tree().process_frame
		if finished_saving_data == false:
			await self.finished_saving_data_signal
	return

func create_entry(type : use_type, data : Dictionary = get_data_template(type)) -> int:
	[artist_id_dict, album_id_dict, song_id_dict, playlist_id_dict][type][generate_id(type)] = data
	return OK

func get_data_template(type : use_type) -> Dictionary:
	return [
		{"name": "", "albums": [], "image_file_path": "", "favourite": false}, 
		{"name": "", "artist": "", "songs": [], "image_file_path": "", "favourite": false}, 
		{"name": "", "album": "", "song_file_path": "", "favourite": false}, 
		{"name": "", "songs": [], "image_file_path": "", "favourite": false}
		][type]

func generate_id(type : use_type) -> String:
	var result : String = ""
	var generating : bool = true
	while generating:
		result = str(type)
		for i : int in range(0, 16):
			result += id_chars[randi_range(0, len(id_chars)-1)]
		generating = result in self.get(["artist", "album", "song", "playlist"][type] + "_id_dict").keys()
	print("Newly Generated " + str(use_type.keys()[type]).to_lower().capitalize() + " ID: " + str(result))
	return result

func save_data(save_location : String = "NMP_Data.dat") -> int:
	finished_saving_data = false
	save_location = OS.get_executable_path().get_base_dir() + "/" + save_location
	print("\n!! Saving Data !!")
	GeneralManager.set_mouse_busy_state.call(true)
	var data : ConfigFile = ConfigFile.new()
	user_data_dict["window_position"] = DisplayServer.window_get_position()
	user_data_dict["window_mode"] = DisplayServer.window_get_mode()
	user_data_dict["window_screen"] = DisplayServer.window_get_current_screen()
	user_data_dict["window_size"] = DisplayServer.window_get_size()
	user_data_dict["player_fullscreen"] = not get_node("/root/MainScreen/Camera").enabled
	user_data_dict["shuffle"] = get_node("/root/MainScreen").playing_screen.shuffle
	user_data_dict["auto_clear"] = get_node("/root/MainScreen/Camera/AspectRatioContainer/CommandLineInterface").auto_clear
	for item : String in get_data_types.call():
		data.set_value("data", item + "_id_dict", self.get(item + "_id_dict"))
	for item : String in user_data_dict["active_song_data"].keys():
		user_data_dict["active_song_data"][item] = get_node("/root/MainScreen").playing_screen.get(item)
	for keybind : String in user_data_dict["keybinds"].keys():
		if not keybind in keybinds:
			user_data_dict["keybinds"].erase(keybind)
	data.set_value("data", "user_data_dict", user_data_dict)
	if data.encode_to_text() != FileAccess.open(save_location, FileAccess.READ).get_as_text():
		data.save(save_location)
	GeneralManager.set_mouse_busy_state.call(false)
	GeneralManager.cli_print_callable.call("[i]Saved Data Succesfully To '[u]" + save_location.get_file() + "[/u]' In '[u]" + save_location.get_base_dir() + "[/u]'.[/i]")
	finished_saving_data = true
	self.emit_signal("finished_saving_data_signal")
	print("!! Saved Data Succesfully To '" + save_location + "' !!\n")
	return OK

func load_data() -> void:
	finished_loading_data = false
	print("\n!! Loading Data !!")
	if not FileAccess.file_exists(data_location):
		print("!! No Data Available During Data Loading")
		user_data_dict = default_user_data
		finished_loading_data = true
		self.emit_signal("finished_loading_data_signal")
		await get_tree().process_frame
		GeneralManager.cli_print_callable.call("[i]No Data File Found During Load, Running With Default Data.[/i]")
		return
	var data : ConfigFile = ConfigFile.new()
	data.load(data_location)
	for item : String in get_data_types.call():
		self.set(item + "_id_dict", data.get_value("data", item + "_id_dict", {}))
	var loaded_user_data : Dictionary = data.get_value("data", "user_data_dict", default_user_data)
	for item : String in default_user_data.keys():
		user_data_dict[item] = loaded_user_data.get(item, default_user_data[item])
	for item : String in keybinds.keys():
		if not item in user_data_dict["keybinds"].keys():
			user_data_dict["keybinds"][item] = keybinds[item]
	apply_control_settings()
	print("!! Data Succesfully Loaded From '" + data_location + "' !!\n")
	finished_loading_data = true
	self.emit_signal("finished_loading_data_signal")
	await GeneralManager.finished_loading_icons_signal
	GeneralManager.cli_print_callable.call("[i]Loaded Data Succesfully From '[u]" + data_location + "[/u]'.[/i]")
	return

func set_user_settings(setting : StringName, value : Variant) -> int:
	if setting in settable_settings and typeof(value) == typeof(user_data_dict[setting]):
		GeneralManager.cli_print_callable.call("[i]User Settings: Set [u]" + setting + "[/u] from [u]" + str(user_data_dict[setting]) + "[/u] > [u]" + str(value) + "[/u].[/i]")
		user_data_dict[setting] = value
		match setting:
			"volume":
				get_node("/root/MainScreen").playing_screen.get_child(1).volume_db = value
			"player_fullscreen":
				if get_node("/root/MainScreen/Camera").enabled == !value:
					get_node("/root/MainScreen").playing_screen.fullscreen_callable.call()
			"player_widgets":
				get_node("/root/MainScreen").playing_screen.call("set_widgets")
			"window_position":
				DisplayServer.window_set_position(value)
			"window_mode":
				DisplayServer.window_set_mode(value)
			"window_screen":
				DisplayServer.window_set_current_screen(value)
			"window_size":
				DisplayServer.window_set_size(value)
			"shuffle":
				get_node("/root/MainScreen").playing_screen.shuffle = value
			"auto_clear", "clear_input":
				get_node("/root/MainScreen/Camera/AspectRatioContainer/CommandLineInterface").set(setting, value)
			"special_icon_scale", "icon_scale", "song_cache_size", "image_cache_size":
				if value < 1:
					user_data_dict[setting] = 1
					GeneralManager.cli_print_callable.call("[i]User Settings: Tried to set [u]" + setting + "[/u] to [u]" + str(value) + "[/u], which is lower than 1, setting was set to 1 instead.[/i]")
		return OK
	if not setting in settable_settings:
		GeneralManager.cli_print_callable.call("[i]ERROR: Setting '[u]" + setting + "[/u]' is not a valid setting that can be set, please check it and try again.[/i]")
	else:
		GeneralManager.cli_print_callable.call("[i]ERROR: Tried to set value '[u]" + setting + "[/u]' to a value of the type '[u]" + type_string(typeof(value)) + "[/u]', when the expected type was '[u]" + type_string(typeof(user_data_dict[setting])) + "[/u]'.[/i]")
	return ERR_INVALID_PARAMETER

func get_user_settings() -> Dictionary:
	var data : Dictionary
	for setting : String in settable_settings:
		data[setting] = user_data_dict[setting]
	return data

func apply_control_settings() -> void:
	#print("user keybinds before application: " + str(user_data_dict["keybinds"]))
	for keybind : String in keybinds:
		#print("InputMap for action " + keybind + " before applying settings: " + str(InputMap.action_get_events(keybind)))
		InputMap.action_erase_events(keybind)
		#print("custom events for keybind " + keybind + ": " + str(user_data_dict["keybinds"][keybind]))
		for custom_event : Dictionary in user_data_dict["keybinds"][keybind].filter(func(array_item : Variant) -> bool: return not typeof(array_item) == TYPE_STRING):
			InputMap.action_add_event(keybind, GeneralManager.parse_customevent_to_inputevent(custom_event))
		print("InputMap for action " + keybind + " after applying settings:\n" + str(InputMap.action_get_events(keybind)).replace(", InputEventKey: ", ",\nInputEventKey: "))
		print("- - -")
	return

func get_artist_discography_data(id : String) -> Dictionary:
	if GeneralManager.get_id_type(id) == use_type.ARTIST:
		var data : Dictionary
		for album : String in artist_id_dict[id]["albums"]:
			data[album] = album_id_dict[album]
		return data
	return {}

func get_album_tracklist_data(id : String) -> Dictionary:
	if GeneralManager.get_id_type(id) == use_type.ALBUM:
		var data : Dictionary
		for song : String in album_id_dict[id]["songs"]:
			data[song] = song_id_dict[song]
		return data
	return {}

func get_playlist_songs_data(id : String) -> Dictionary:
	if GeneralManager.get_id_type(id) == use_type.PLAYLIST:
		var data : Dictionary
		for song : String in playlist_id_dict[id]["songs"]:
			data[song] = song_id_dict[song]
		return data
	return {}
