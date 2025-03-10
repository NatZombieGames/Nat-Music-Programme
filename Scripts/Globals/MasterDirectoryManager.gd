extends Node

@export var artist_id_dict : Dictionary[String, Dictionary] = {}
@export var album_id_dict : Dictionary[String, Dictionary] = {}
@export var song_id_dict : Dictionary[String, Dictionary] = {}
@export var playlist_id_dict : Dictionary[String, Dictionary] = {}
@export var user_data_dict : Dictionary = {}
@export var finished_loading_data : bool = false
@export var finished_saving_data : bool = false
@export var finished_loading_keybinds : bool = false
@export var data_types : PackedStringArray
@export var get_object_data : Callable = (func(id : String) -> Dictionary: return self.get(data_types[int(id[0])] + "_id_dict")[id])
@export var new_user : bool = false
var data_location : String = "" # read only after ready
@warning_ignore("unused_signal")
signal finished_loading_data_signal
signal finished_saving_data_signal
signal finished_loading_keybinds_signal
const default_user_data : Dictionary = {
"volume": 0, "player_fullscreen": false, "special_icon_scale": 2, "icon_scale": 1, 
"song_cache_size": 3, "image_cache_size": 20, "player_widgets": [false, false, false], 
"auto_clear": false, "clear_input": false, "shuffle": false, "command_on_startup": "", 
"window_position": Vector2.ZERO, "window_mode": DisplayServer.WINDOW_MODE_FULLSCREEN, 
"window_screen": 0, "window_size": Vector2(960, 540), "save_on_quit": true, 
"continue_playing": true, "continue_playing_exact": true, 
"active_song_data": {"active_song_list": [], "active_song_list_id": "", "active_song_id": "", "song_progress": 0}, 
"keybinds": {}, "sleep_when_unfocused": false, "generate_home_screen": true, 
"library_size_modifier": 1.0, "cli_size_modifier": 1.0, "profile_size_modifier": 1.0, 
"separate_cli_outputs": false, "solid_cli": false
}
const settable_settings : PackedStringArray = [
"volume", "player_fullscreen", "special_icon_scale", "icon_scale", "song_cache_size", 
"image_cache_size", "player_widgets", "auto_clear", "clear_input", "shuffle", 
"command_on_startup", "window_position", "window_mode", "window_screen", "window_size", 
"save_on_quit", "continue_playing", "continue_playing_exact", "sleep_when_unfocused", 
"generate_home_screen", "library_size_modifier", "cli_size_modifier", "profile_size_modifier", 
"separate_cli_outputs", "solid_cli"
]
const id_chars : PackedStringArray = [
"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", 
"u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", 
"O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5", "6", "7", 
"8", "9", "!", '"', "`", "¬", "%", "^", "&", "*", "(", ")", "|", "_", "=", "+", "{", "}", ":", ";", 
"'", "@", "~", "#", ",", "<", ".", ">", "/", "?", "¤", "£", "$", "¥", "¢", "÷", "´", "˄", "˅", "ˆ", 
]
var keybinds : Dictionary[String, Array] = {} # const after ready is finished
enum use_type {ARTIST, ALBUM, SONG, PLAYLIST, UNKNOWN}

func _ready() -> void:
	data_location = OS.get_executable_path().get_base_dir() + "/NMP_Data.dat"
	data_types = (func() -> Array: return use_type.keys().map(func(key : String) -> String: return key.to_lower()).filter(func(key : String) -> bool: return key != "unknown")).call()
	#print("i am about to load the keybinds")
	for item : String in InputMap.get_actions().filter(func(item : String) -> bool: return not item.left(3) == "ui_"):
		keybinds[item] = Array(InputMap.action_get_events(item).map(func(event : InputEvent) -> Dictionary: return GeneralManager.parse_inputevent_to_customevent(event)))
		if len(keybinds[item]) < 2:
			keybinds[item].append("")
	keybinds.make_read_only()
	finished_loading_keybinds = true
	self.emit_signal("finished_loading_keybinds_signal")
	#print(str("- - - - -\nkeybinds after completion: " + str(keybinds).replace('], "', ']\n= "')).replace('completion: { "', 'completion:\n= { "'))
	return

func _notification(notif : int) -> void:
	if notif == Node.NOTIFICATION_WM_CLOSE_REQUEST and user_data_dict["save_on_quit"] == true:
		#print("received quit notification and save on quit is true; saving data.")
		save_data()
		await get_tree().process_frame
		if finished_saving_data == false:
			await self.finished_saving_data_signal
		await get_tree().process_frame
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
	#print("Newly Generated " + str(use_type.keys()[type]).to_lower().capitalize() + " ID: " + str(result))
	return result

func save_data(save_location : String = "NMP_Data.dat") -> int:
	finished_saving_data = false
	save_location = OS.get_executable_path().get_base_dir() + "/" + save_location
	#print("\n!! Saving Data In " + save_location + " !!")
	GeneralManager.set_mouse_busy_state.call(true)
	get_node("/root/MainScreen").show_saving_indicator = true
	await get_tree().process_frame
	var data : ConfigFile = ConfigFile.new()
	user_data_dict["window_position"] = DisplayServer.window_get_position()
	user_data_dict["window_mode"] = DisplayServer.window_get_mode()
	user_data_dict["window_screen"] = DisplayServer.window_get_current_screen()
	user_data_dict["window_size"] = DisplayServer.window_get_size()
	user_data_dict["player_fullscreen"] = not get_node("/root/MainScreen/Camera").enabled
	user_data_dict["shuffle"] = get_node("/root/MainScreen").playing_screen.shuffle
	user_data_dict["auto_clear"] = get_node("/root/MainScreen/Camera/AspectRatioContainer/CommandLineInterface").auto_clear
	for item : String in data_types:
		data.set_value("data", item + "_id_dict", self.get(item + "_id_dict"))
	for item : String in user_data_dict["active_song_data"].keys():
		user_data_dict["active_song_data"][item] = get_node("/root/MainScreen").playing_screen.get(item)
	for keybind : String in user_data_dict["keybinds"].keys():
		if not keybind in keybinds:
			user_data_dict["keybinds"].erase(keybind)
	data.set_value("data", "user_data_dict", user_data_dict)
	#print("got to the writing portion")
	if (not FileAccess.file_exists(save_location)) or (data.encode_to_text() != FileAccess.open(save_location, FileAccess.READ).get_as_text()):
		#print("i am going to write it now")
		data.save(save_location)
	#print("finished writing portion")
	GeneralManager.set_mouse_busy_state.call(false)
	get_node("/root/MainScreen").show_saving_indicator = false
	await get_tree().process_frame
	GeneralManager.cli_print_callable.call("SYS: Saved Data Succesfully To '[u]" + save_location.get_file() + "[/u]' In '[u]" + save_location.get_base_dir() + "[/u]'.")
	get_node("/root/MainScreen").call("create_popup_notif", "Saved Data Succesfully To '[u]" + save_location.get_file() + "[/u]' In '[u]" + save_location.get_base_dir() + "[/u]'.")
	finished_saving_data = true
	self.emit_signal("finished_saving_data_signal")
	#print("!! Saved Data Succesfully To '" + save_location + "' !!\n")
	return OK

## For the CLI to call as the normal one is async.
func _save_data(location : String = "NMP_Data.dat") -> int:
	save_data(location)
	return OK

func load_data() -> void:
	finished_loading_data = false
	#print("\n!! Loading Data !!")
	if not FileAccess.file_exists(data_location):
		#print("!! No Data Available During Data Loading")
		new_user = true
		user_data_dict = default_user_data.duplicate()
		user_data_dict["keybinds"] = {}
		user_data_dict["active_song_data"] = {}
		#print("all " + str(len(keybinds.keys())) + " keybind keys before setting them: " + str(keybinds.keys()))
		#print(user_data_dict["keybinds"].is_read_only())
		for keybind : String in keybinds.keys():
			user_data_dict["keybinds"][keybind] = keybinds[keybind]
		finished_loading_data = true
		self.emit_signal("finished_loading_data_signal")
		await get_tree().process_frame
		GeneralManager.cli_print_callable.call("ALERT: No Data File Found During Load, Running With Default Data.")
		return
	var data : ConfigFile = ConfigFile.new()
	data.load(data_location)
	for item : String in data_types:
		self.get(item + "_id_dict").assign(data.get_value("data", item + "_id_dict", {}))
	var loaded_user_data : Dictionary = data.get_value("data", "user_data_dict", default_user_data)
	for key : String in default_user_data.keys():
		user_data_dict[key] = loaded_user_data.get(key, default_user_data[key])
	if not finished_loading_keybinds:
		await self.finished_loading_keybinds_signal
	#print("all " + str(len(keybinds.keys())) + " keybind keys before setting them: " + str(keybinds.keys()))
	for keybind : String in keybinds.keys():
		if not keybind in user_data_dict["keybinds"].keys():
			user_data_dict["keybinds"][keybind] = keybinds[keybind]
	apply_control_settings()
	#print("!! Data Succesfully Loaded From '" + data_location + "' !!\n")
	finished_loading_data = true
	self.emit_signal("finished_loading_data_signal")
	await GeneralManager.finished_loading_icons_signal
	GeneralManager.cli_print_callable.call("SYS: Loaded Data Succesfully From '[u]" + data_location + "[/u]'.")
	return

func set_user_settings(setting : StringName, value : Variant) -> int:
	if setting in settable_settings and typeof(value) == typeof(user_data_dict[setting]):
		GeneralManager.cli_print_callable.call("NOTIF: User Settings: Set [u]" + setting + "[/u] from [u]" + str(user_data_dict[setting]) + "[/u] > [u]" + str(value) + "[/u].")
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
					GeneralManager.cli_print_callable.call("User Settings: Tried to set [u]" + setting + "[/u] to [u]" + str(value) + "[/u], which is lower than 1, setting was set to 1 instead.")
			"cli_size_modifier":
				get_node("/root/MainScreen")._apply_cli_size_mod()
			"profile_size_modifier":
				get_node("/root/MainScreen")._apply_profile_size_mod()
		return OK
	if not setting in settable_settings:
		GeneralManager.cli_print_callable.call("ERROR: Setting [u]" + setting + "[/u] does not exist in User Settings or is unable to be set. Did you mean '[u]" + GeneralManager.spellcheck(setting, default_user_data.keys()) + "[/u]'?.")
	else:
		GeneralManager.cli_print_callable.call("ERROR: Tried to set [u]" + setting + "[/u] whos value is of type [u]" + type_string(typeof(user_data_dict[setting])) + "[/u] to [u]" + str(value) + "[/u] which is of type [u]" + type_string(typeof(value)) + "[/u].")
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
		#print("InputMap for action " + keybind + " after applying settings:\n" + str(InputMap.action_get_events(keybind)).replace(", InputEventKey: ", ",\nInputEventKey: "))
		#print("- - -")
	return

func get_artist_discography_data(id : String) -> Dictionary:
	if GeneralManager.get_id_type(id) == use_type.ARTIST:
		var data : Dictionary
		for album : String in artist_id_dict[id]["albums"]:
			data[album] = album_id_dict[album]
		return data
	return {}

func get_random_artist_songs(id : String, song_count : int = 15) -> PackedStringArray:
	if GeneralManager.get_id_type(id) == use_type.ARTIST:
		var songs : Array[String]
		for album : String in get_artist_discography_data(id):
			for song : String in get_album_tracklist_data(album):
				songs.append(song)
		songs.shuffle()
		if len(songs) > song_count:
			songs.resize(song_count)
		return PackedStringArray(songs)
	return []

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
