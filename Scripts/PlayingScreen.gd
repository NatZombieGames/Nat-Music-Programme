extends Control

@export var active_song_list : Array = []
@export var active_song_list_id : String = ""
@export var active_song_id : String = ""
@export var shuffle : bool = false
@export var paused : bool = false:
	set(value):
		paused = value
		%AudioPlayer.stream_paused = value
		%TogglePlay.call("set_pressed_no_signal", value)
	get:
		return paused
@export var muted : bool = false:
	set(value):
		muted = value
		%AudioPlayer.bus = ["Muted", "Master"][int(value)]
		%MuteWidget.call("set_pressed_no_signal", value)
	get():
		return muted
@export var loop : bool = false:
	set(value):
		loop = value
		%ToggleLoop.call("set_pressed_no_signal", value)
	get:
		return loop
@export var song_progress : int = 0:
	set(value):
		if ((value >= 0) and (value <= 100)) and %AudioPlayer.stream != null:
			%AudioPlayer.play((%AudioPlayer.stream.get_length() / 100) * value)
	get:
		if %AudioPlayer.stream != null:
			return (%ProgressBar.value / %ProgressBar.max_value) * 100
		return 0
var change_callable : Callable = (
	func(dir : int, do_loop : bool) -> String: 
		if do_loop:
			return active_song_id
		if ((dir == 1 and (active_song_list.find(active_song_id) == len(active_song_list) - 1)) or (dir == 0 and (active_song_list.find(active_song_id) == 0))) and shuffle:
			active_song_list.shuffle()
		return active_song_list[wrapi(active_song_list.find(active_song_id) + dir, 0, len(active_song_list))])
var fullscreen_callable : Callable = (func() -> void: var state : bool = get_node("/root/MainScreen/Camera").enabled; get_node("/root/MainScreen/Camera").enabled = !state; self.get_child(0).enabled = state; %ToggleFullscreen.button_pressed = state; return)
var song_cache : Dictionary
var load_song_thread : Thread = Thread.new()
var load_song_mutex : Mutex = Mutex.new()
var dragging_progress_bar : bool = false
var volume_indicator_tween : Tween = create_tween()
var volume_indicator_textures : Array[ImageTexture] = []
#const after ready
const special_ids : PackedStringArray = ["@all", "@everyone"]
const settable_settings : Dictionary = {"shuffle": [false, true], "paused": [false, true], "loop": [false, true], "muted": [false, true]}

func _ready() -> void:
	if not GeneralManager.finished_loading_icons:
		await GeneralManager.finished_loading_icons_signal
	#
	reset_playing_screen()
	if MasterDirectoryManager.user_data_dict["continue_playing"] == true:
		for item : String in MasterDirectoryManager.user_data_dict["active_song_data"].keys().filter(func(item : String) -> bool: return item != "song_progress"):
			self.set(item, MasterDirectoryManager.user_data_dict["active_song_data"][item])
	%TogglePlay.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Play.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%TogglePlay.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/Pause.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%TogglePlay.toggled.connect(func(state : bool) -> void: paused = state; return)
	%Previous.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Previous.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%Previous.pressed.connect(func() -> void: load_song(change_callable.call(-1, false)); return)
	%Next.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Next.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%Next.pressed.connect(func() -> void: load_song(change_callable.call(1, false)); return)
	%ToggleFavourite.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Favourite.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleFavourite.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/Favourited.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleFavourite.pressed.connect(func() -> void: get_node("/root/MainScreen").call("set_favourite", active_song_id))
	%AudioPlayer.finished.connect(func() -> void: load_song(change_callable.call(1, loop)); return)
	%ProgressBar.drag_started.connect(func() -> void: dragging_progress_bar = true; return)
	%ProgressBar.drag_ended.connect(func(value_changed : bool) -> void: if value_changed: %AudioPlayer.play(%ProgressBar.value); %AudioPlayer.stream_paused = paused; dragging_progress_bar = false; return)
	%ProgressBar.set("theme_override_icons/grabber", GeneralManager.get_icon_texture("EmptyCircle"))
	%ProgressBar.set("theme_override_icons/grabber_highlight", GeneralManager.get_icon_texture("FilledCircle"))
	for item : String in ["grabber", "grabber_highlight"]:
		%ProgressBar.get("theme_override_icons/" + item).set_size_override(Vector2i(14, 14))
	%ToggleLoop.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/LoopDisabled.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleLoop.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/LoopEnabled.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleLoop.pressed.connect(func() -> void: loop = !loop; return)
	%ToggleFullscreen.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Fullscreen.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleFullscreen.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/CloseFullscreen.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleFullscreen.pressed.connect(fullscreen_callable)
	%MuteWidget.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeDisabled.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%MuteWidget.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeUp.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%MuteWidget.toggled.connect(func(state : bool) -> void: muted = state; return)
	volume_indicator_textures.append(GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeUp.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"] * 2))
	volume_indicator_textures.append(GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeDown.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"] * 2))
	volume_indicator_textures.make_read_only()
	%AudioPlayer.volume_db = MasterDirectoryManager.user_data_dict["volume"]
	shuffle = MasterDirectoryManager.user_data_dict["shuffle"]
	#
	set_widgets()
	if active_song_id != "":
		load_song(active_song_id)
	await get_tree().process_frame
	if MasterDirectoryManager.user_data_dict["continue_playing_exact"] == true:
		song_progress = MasterDirectoryManager.user_data_dict["active_song_data"].get("song_progress", 0)
	return

func _process(_delta : float) -> void:
	if ((%AudioPlayer.stream != null) and (not dragging_progress_bar)):
		%ProgressBar.value = %AudioPlayer.get_playback_position()
		%Percentage.text = str(int((%ProgressBar.value / %ProgressBar.max_value) * 100)) + "%"
	if %TimeWidget.visible:
		%TimeWidget.text = Time.get_time_string_from_system().left(-3)
	return

func _input(_event : InputEvent) -> void:
	if is_pressed("VolumeDown") or is_pressed("VolumeUp"):
		if is_pressed("VolumeUp"):
			%AudioPlayer.volume_db += 1
			%VolumeIndicator.texture = volume_indicator_textures[0]
		else:
			%AudioPlayer.volume_db -= 1
			%VolumeIndicator.texture = volume_indicator_textures[1]
		MasterDirectoryManager.user_data_dict["volume"] = %AudioPlayer.volume_db
		volume_indicator_tween.kill()
		volume_indicator_tween = create_tween()
		volume_indicator_tween.tween_property(%VolumeIndicator, "self_modulate", Color(1, 1, 1, 0), 1.0).from(Color(1, 1, 1, 1))
	elif is_pressed("Previous") or is_pressed("Next"):
		if is_pressed("Previous"):
			load_song(change_callable.call(-1, false))
		else:
			load_song(change_callable.call(1, false))
	elif is_pressed("Rewind1S") or is_pressed("FastForward1S"):
		if is_pressed("Rewind1S"):
			%AudioPlayer.seek(%AudioPlayer.get_playback_position() - 1)
		else:
			%AudioPlayer.seek(%AudioPlayer.get_playback_position() + 1)
	elif is_pressed("Rewind1%") or is_pressed("FastForward1%"):
		if is_pressed("Rewind1%"):
			%AudioPlayer.seek(%AudioPlayer.get_playback_position() - (%AudioPlayer.stream.get_length() / 100))
		else:
			%AudioPlayer.seek(%AudioPlayer.get_playback_position() + (%AudioPlayer.stream.get_length() / 100))
	elif is_pressed("TogglePause"):
		paused = !paused
	elif is_pressed("ToggleLargePlayer"):
		fullscreen_callable.call()
	return

func _exit_tree() -> void:
	load_song_thread.wait_to_finish()
	return

func load_song_list(list_id : String = active_song_list_id) -> int:
	print("Load Song List ID: '" + list_id + "', begins with '" + list_id.left(1) + "'")
	active_song_list_id = list_id
	active_song_list = []
	if list_id in special_ids:
		match list_id:
			"@all", "@everyone":
				for song : String in MasterDirectoryManager.song_id_dict.keys():
					active_song_list.append(song)
	else:
		if (GeneralManager.get_id_type(list_id) == MasterDirectoryManager.use_type.UNKNOWN) or GeneralManager.get_data(list_id) in ["", "Unknown"]:
			print("Invalid Song List ID, type is " + str(GeneralManager.get_id_type(list_id)) + ", data is invalid: " + str(GeneralManager.get_data(list_id) in ["", "Unknown"]))
			GeneralManager.cli_print_callable.call("[i][b]ERROR:[/b] Attempted to load song list with an ID of [u]" + list_id + "[/u], which isn't valid. Please check it and try again.[/i]")
			reset_playing_screen()
			return ERR_INVALID_PARAMETER
		match GeneralManager.get_id_type(list_id):
			MasterDirectoryManager.use_type.ARTIST:
				for item : String in GeneralManager.get_data(list_id, "albums"):
					active_song_list.append_array(GeneralManager.get_data(item, "songs"))
			MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST:
				active_song_list = GeneralManager.get_data(list_id, "songs")
			MasterDirectoryManager.use_type.SONG:
				active_song_list = [list_id]
			MasterDirectoryManager.use_type.PLAYLIST:
				active_song_list = MasterDirectoryManager.playlist_id_dict[list_id]["songs"]
	active_song_list.filter(func(item : String) -> bool: return MasterDirectoryManager.song_id_dict.keys().has(item))
	if shuffle == true:
		active_song_list.shuffle()
	song_cache = {}
	load_song(GeneralManager.arr_get(active_song_list, 0, ""))
	print("Load Song List Ran Succesfully")
	return OK

func load_song(song_id : String = active_song_id) -> int:
	print("\n\nLoad Song ID: '" + song_id + "', begins with '" + song_id.left(1) + "'")
	if (GeneralManager.get_id_type(song_id) != MasterDirectoryManager.use_type.SONG) or (not MasterDirectoryManager.song_id_dict.has(song_id)):
		GeneralManager.cli_print_callable.call("[i][b]ERROR:[/b] Attempted to load song of ID '[u]" + song_id + "[/u]' which isn't valid, please check it and try again.[/i]")
		reset_playing_screen()
		return ERR_INVALID_PARAMETER
	print("Song ID is valid.")
	active_song_id = song_id
	GeneralManager.cli_print_callable.call("[i]Player is now playing song [u]" + str(active_song_list.find(active_song_id) + 1) + "[/u]/[u]" + str(len(active_song_list)) + "[/u] with the ID of [u]" + active_song_id + "[/u].[/i]")
	var song_data : Dictionary = GeneralManager.get_data(active_song_id)
	print("song data: " + str(song_data))
	if not song_data["song_file_path"] in song_cache.keys():
		load_song_mutex.lock()
		song_cache[song_data["song_file_path"]] = GeneralManager.load_audio_file(song_data["song_file_path"])
		load_song_mutex.unlock()
	%AudioPlayer.stream = song_cache[song_data["song_file_path"]]
	if %AudioPlayer.stream == null:
		GeneralManager.cli_print_callable.call("[i] ERROR: Song with an ID of [u]" + song_id + "[/u] was unable to be loaded, the path may be invalid or corrupted, please check the audio file and try again. [/i]")
		reset_playing_screen()
	%Title.text = GeneralManager.limit_str(song_data["name"], 25)
	%"Album&Band".text = GeneralManager.limit_str(GeneralManager.get_data(song_data["album"], "name"), 10) + " | " + GeneralManager.limit_str(GeneralManager.get_data(GeneralManager.get_data(song_data["album"], "artist"), "name"), 10)
	var list_name : String = GeneralManager.get_data(active_song_list_id, "name")
	if not active_song_list_id in special_ids:
		%Playlist.text = ["All Of: ", "Album: ", "Listening To: ", "Playlist: "][int(active_song_list_id[0])] + GeneralManager.limit_str(list_name, 13)
	else:
		%Playlist.text = ["All Songs"][special_ids.find(active_song_list_id)]
	%Playlist.text += " | " + str(str(active_song_list.find(song_id)+1) + "/" + str(len(active_song_list)))
	%ProgressBar.max_value = %AudioPlayer.stream.get_length()
	%ToggleFavourite.set_pressed_no_signal(song_data["favourite"])
	%Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(GeneralManager.get_data(song_data["album"], "image_file_path")))
	print("Image texture after load: " + str(%Image.texture))
	var image_average : Color = GeneralManager.get_image_average(GeneralManager.get_image(GeneralManager.get_data(song_data["album"], "image_file_path")))
	%Background.color = image_average
	var stylebox : StyleBoxFlat = %Image.get_parent().get("theme_override_styles/panel").duplicate()
	stylebox.border_color = Color(image_average.r / 1.5, image_average.g / 1.5, image_average.b / 1.5)
	%Image.get_parent().set("theme_override_styles/panel", stylebox)
	%AudioPlayer.play()
	paused = paused
	if load_song_thread.is_started():
		load_song_thread.wait_to_finish()
	load_song_thread.start(Callable(self, "load_next_song_into_cache"))
	print("!! Load Song Ran Succesfully !!")
	return OK

func load_next_song_into_cache() -> void:
	load_song_mutex.lock()
	var next_song_path : String = GeneralManager.get_data(change_callable.call(1, false))["song_file_path"]
	if next_song_path not in song_cache.keys():
		song_cache[next_song_path] = GeneralManager.load_audio_file(next_song_path)
	while len(song_cache.keys()) > MasterDirectoryManager.user_data_dict["song_cache_size"]:
		song_cache.erase(song_cache.keys()[0])
	load_song_mutex.unlock()
	return

func set_player_settings(setting : StringName, value : Variant) -> int:
	if setting in settable_settings.keys():
		GeneralManager.cli_print_callable.call("[i]Player Settings: Set [u]" + setting + "[/u] from [u]" + str(self.get(setting)) + "[/u] > [u]" + str(value) + "[/u].[/i]")
		self.set(setting, value)
		return OK
	return ERR_INVALID_PARAMETER

func get_player_settings() -> Dictionary:
	return settable_settings

func reset_playing_screen() -> void:
	active_song_id = ""
	active_song_list = []
	active_song_list_id = ""
	%Playlist.text = "Playlist"
	%Title.text = "Title"
	%"Album&Band".text = "Album | Band"
	%Percentage.text = "0%"
	%ProgressBar.value = 0
	%Image.texture = GeneralManager.load_svg_to_img("res://Assets/Icons/Missing.svg", 5)
	%Background.color = Color8(50, 50, 50)
	%AudioPlayer.stop()
	%AudioPlayer.stream = null
	return

func is_pressed(action : StringName) -> bool:
	return Input.is_action_just_pressed(action, true)

func set_widgets() -> void:
	var widgets : Array[Node] = %Background/TopBar/Container.get_children().slice(1, -1)
	widgets.map(func(node : Node) -> Node: node.visible = MasterDirectoryManager.user_data_dict["player_widgets"][widgets.find(node)]; return node)
	%Background/TopBar/Container/Void.visible = true in MasterDirectoryManager.user_data_dict["player_widgets"]
	return
