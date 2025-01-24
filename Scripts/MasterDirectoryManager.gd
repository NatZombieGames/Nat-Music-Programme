extends Node

@export var artist_id_dict : Dictionary = {}
@export var album_id_dict : Dictionary = {}
@export var song_id_dict : Dictionary = {}
@export var playlist_id_dict : Dictionary = {}
@export var user_data_dict : Dictionary = {}
@export var finished_loading_data : bool = false
var get_data_types : Callable = (func() -> Array: return use_type.keys().map(func(item): return item.to_lower()))
signal finished_loading_data_signal
const default_user_data : Dictionary = {"volume": -25, "active_song_data": {"active_song_list": [], "active_song_list_id": "", "active_song_id": ""}, "save_on_quit": true, "continue_playing": true, 
"keybinds": {"VolumeUp": ["", ""], "VolumeDown": ["", ""], "Rewind": ["", ""], "GoForward": ["", ""], "Next": ["", ""], "Previous": ["", ""], "TogglePause": ["", ""], "ToggleLargePlayer": ["", ""]}}
const id_chars : PackedStringArray = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", 
"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", 
"I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", 
"3", "4", "5", "6", "7", "8", "9", "!", '"', "£", "$", "%", "^", "&", "*", "(", ")", "-", "_", "=", "+", 
"{", "}", ":", ";", "'", "@", "~", "#", ",", "<", ".", ">", "/", "?", "|", "`", "¬", "¥", "¢"]
enum use_type {ARTIST, ALBUM, SONG, PLAYLIST, UNKNOWN}

func _notification(notif : int) -> void:
	if notif == Node.NOTIFICATION_WM_CLOSE_REQUEST and user_data_dict["save_on_quit"] == true:
		print("received quit notification and save on quit is true; saving data.")
		save_data()
	return

func create_entry(type : use_type, data : Dictionary = get_data_template(type)) -> void:
	[artist_id_dict, album_id_dict, song_id_dict, playlist_id_dict][type][generate_id(type)] = data
	return

func get_data_template(type : use_type) -> Dictionary:
	return [{"name": "", "albums": [], "image_file_path": "", "favourite": false, "metadata": []}, {"name": "", "artist": "", "songs": [], "image_file_path": "", "favourite": false, "metadata": []}, {"name": "", "album": "", "song_file_path": "", "favourite": false, "metadata": []}, {"name": "", "songs": [], "image_file_path": "", "favourite": false, "metadata": []}][type]

func generate_id(type : use_type) -> String:
	var result : String = ""
	var generating : bool = true
	while generating:
		result = str(type)
		for i in range(0, 16):
			result += id_chars[randi_range(0, len(id_chars)-1)]
		generating = result in MasterDirectoryManager.get(["artist", "album", "song", "playlist"][type] + "_id_dict").keys()
	print("Newly Generated " + str(use_type.keys()[type]).to_lower().capitalize() + " ID: " + str(result))
	return result

func save_data(save_location : String = "NMP_Data.dat") -> void:
	print("\n!! Saving Data !!")
	GeneralManager.set_mouse_busy_state.call(true)
	var data : ConfigFile = ConfigFile.new()
	for item in get_data_types.call():
		data.set_value("data", item + "_id_dict", self.get(item + "_id_dict"))
	if user_data_dict["continue_playing"]:
		for item : String in user_data_dict["active_song_data"].keys():
			user_data_dict["active_song_data"][item] = get_node("/root/MainScreen").playing_screen.get(item)
	else:
		user_data_dict["active_song_data"] = default_user_data["active_song_data"]
	data.set_value("data", "user_data_dict", user_data_dict)
	data.save(OS.get_executable_path().get_base_dir() + "/" + save_location)
	GeneralManager.set_mouse_busy_state.call(false)
	print("!! Saved Data Succesfully To '" + OS.get_executable_path().get_base_dir() + "/" + save_location + "' !!\n")
	return

func load_data() -> void:
	finished_loading_data = false
	print("\n!! Loading Data !!")
	if not FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/NMP_Data.dat"):
		print("!! No Data Available During Data Loading")
		user_data_dict = default_user_data
		finished_loading_data = true
		self.emit_signal("finished_loading_data_signal")
		return
	var data : ConfigFile = ConfigFile.new()
	data.load(OS.get_executable_path().get_base_dir() + "/NMP_Data.dat")
	for item in get_data_types.call():
		self.set(item + "_id_dict", data.get_value("data", item + "_id_dict", {}))
	var loaded_user_data : Dictionary = data.get_value("data", "user_data_dict", default_user_data)
	for item : String in default_user_data.keys():
		user_data_dict[item] = loaded_user_data.get(item, default_user_data[item])
	print("!! Data Succesfully Loaded From '" + OS.get_executable_path().get_base_dir() + "/NMP_Data.dat" + "' !!\n")
	finished_loading_data = true
	self.emit_signal("finished_loading_data_signal")
	return

func get_artist_discography_data(id : String) -> Dictionary:
	if GeneralManager.get_id_type(id) == use_type.ARTIST:
		var data : Dictionary
		for item : String in artist_id_dict[id]["albums"]:
			data[item] = album_id_dict[item]
		return data
	return {}

func get_album_tracklist_data(id : String) -> Dictionary:
	if GeneralManager.get_id_type(id) == use_type.ALBUM:
		var data : Dictionary
		for item : String in album_id_dict[id]["songs"]:
			data[item] = song_id_dict[item]
		return data
	return {}
