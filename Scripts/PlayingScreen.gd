extends Control

const tooltip_scene : PackedScene = preload("res://Scenes/Tooltip.tscn")
@export var active_song_list : Array[String] = []
@export var active_song_list_id : String = ""
@export var active_song_id : String = ""
@export var sleeping_state : bool = false:
	set(value):
		sleeping_state = value
		$Camera/SleepScreen.visible = value
@export var shuffle : bool = false:
	set(value):
		shuffle = value
		MasterDirectoryManager.user_data_dict["shuffle"] = value
@export var paused : bool = false:
	set(value):
		paused = value
		%AudioPlayer.stream_paused = value
		%TogglePlay.call("set_pressed_no_signal", value)
@export var muted : bool = false:
	set(value):
		muted = value
		%AudioPlayer.bus = ["Muted", "Master"][int(value)]
		%MuteWidget.call("set_pressed_no_signal", value)
		%VolumeControlPanel/Container/Mute.call("set_pressed_no_signal", value)
@export var loop : bool = false:
	set(value):
		loop = value
		MasterDirectoryManager.user_data_dict["loop"] = value
		%ToggleLoop.call("set_pressed_no_signal", value)
@export var song_progress : int = 0:
	set(value):
		song_progress = value
		if ((value >= 0) and (value <= 100)) and %AudioPlayer.stream != null:
			%AudioPlayer.play((%AudioPlayer.stream.get_length() / 100) * value)
	get:
		if %AudioPlayer.stream != null:
			return (%ProgressBar.value / %ProgressBar.max_value) * 100
		return 0
@export var volume : int = -10:
	set(value):
		volume = value
		%AudioPlayer.volume_db = volume
		MasterDirectoryManager.user_data_dict["volume"] = volume
		%VolumeControlPanel/Container/Display.text = "Volume Amplifier (DB): " + str(volume)
@export var song_cache : Dictionary[String, AudioStream]
@export var fullscreen : bool = false:
	set(value):
		fullscreen = value
		$Camera.enabled = value
		get_node("/root/MainScreen/Camera").enabled = !value
		%ToggleFullscreen.button_pressed = value
		if value == true:
			get_node("/root/MainScreen").cli.active = false
@export var extra_control_buttons : bool = false:
	set(value):
		extra_control_buttons = value
		MasterDirectoryManager.user_data_dict["extra_control_buttons"] = value
		$Camera/ScreenContainer/MasterContainer/InfoPanel/InfoContainer/ControlButtons.get_children().map(func(node : Control) -> Control: node.custom_minimum_size = [Vector2i(36, 36), Vector2i(30, 30)][int(value)]; await get_tree().process_frame; node.size = [Vector2i(36, 36), Vector2i(30, 30)][int(value)]; return)
		%First.visible = value
		%Last.visible = value
@export var disable_player_song_system_messages : bool = false:
	set(value):
		disable_player_song_system_messages = value
		MasterDirectoryManager.user_data_dict["disable_player_song_system_messages"] = value
var next_song_callable : Callable = (
	func(dir : int, do_loop : bool) -> String: 
		if do_loop:
			return active_song_id
		return active_song_list[wrapi(active_song_list.find(active_song_id) + dir, 0, len(active_song_list))])
var load_song_thread : Thread = Thread.new()
var load_song_mutex : Mutex = Mutex.new()
var dragging_progress_bar : bool = false
var volume_indicator_tween : Tween
var volume_indicator_textures : Array[ImageTexture] = [] # read only after ready
const special_ids : PackedStringArray = ["@all", "@random"]
const settable_settings : PackedStringArray = ["paused", "shuffle", "mute", "loop", "sleeping_state", "disable_player_song_system_messages", "extra_control_buttons"]

func _ready() -> void:
	volume_indicator_tween = create_tween()
	volume_indicator_tween.tween_interval(0)
	if not GeneralManager.finished_loading_icons:
		await GeneralManager.finished_loading_icons_signal
	#
	reset_playing_screen()
	%TogglePlay.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Play.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%TogglePlay.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/Pause.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%TogglePlay.toggled.connect(func(state : bool) -> void: paused = state; return)
	%Previous.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Previous.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%Previous.pressed.connect(func() -> void: load_song(next_song_callable.call(-1, false)); return)
	%Next.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Next.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%Next.pressed.connect(func() -> void: load_song(next_song_callable.call(1, false)); return)
	%First.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/First.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%First.pressed.connect(func() -> void: if len(active_song_list) > 0: load_song(active_song_list[0]); return)
	%Last.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Last.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%Last.pressed.connect(func() -> void: if len(active_song_list) > 0: load_song(active_song_list[-1]); return)
	%ToggleFavourite.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Favourite.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleFavourite.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/Favourited.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%ToggleFavourite.pressed.connect(func() -> void: get_node("/root/MainScreen").call("set_favourite", active_song_id))
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
	%ToggleFullscreen.pressed.connect(func() -> void: fullscreen = !fullscreen; return)
	%QuitWidget.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/Exit.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%QuitWidget.pressed.connect(func() -> void: 
		if MasterDirectoryManager.user_data_dict["save_on_quit"]:
			MasterDirectoryManager.save_data()
			await get_tree().process_frame
			if not MasterDirectoryManager.finished_saving_data:
				await MasterDirectoryManager.finished_saving_data_signal
			await get_tree().process_frame
		get_tree().quit()
		return)
	%MuteWidget.texture_normal = GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeDisabled.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%MuteWidget.texture_pressed = GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeUp.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"])
	%MuteWidget.toggled.connect(func(state : bool) -> void: muted = state; return)
	%VolumeControlPanel/Container/Mute.texture_normal = %MuteWidget.texture_normal
	%VolumeControlPanel/Container/Mute.texture_pressed = %MuteWidget.texture_pressed
	%VolumeControlPanel/Container/Mute.toggled.connect(func(state : bool) -> void: muted = state; return)
	%VolumeControlPanel/Container/Decrement.texture_normal = GeneralManager.get_icon_texture("Down")
	%VolumeControlPanel/Container/Decrement.pressed.connect(func() -> void: volume -= 1; return)
	%VolumeControlPanel/Container/Increment.texture_normal = GeneralManager.get_icon_texture("Up")
	%VolumeControlPanel/Container/Increment.pressed.connect(func() -> void: volume += 1; return)
	volume_indicator_textures.append(GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeUp.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"] * 2))
	volume_indicator_textures.append(GeneralManager.load_svg_to_img("res://Assets/Icons/VolumeDown.svg", MasterDirectoryManager.user_data_dict["special_icon_scale"] * 2))
	volume_indicator_textures.make_read_only()
	%AudioPlayer.finished.connect(func() -> void: load_song(next_song_callable.call(1, loop)); return)
	for setting : String in settable_settings:
		if MasterDirectoryManager.user_data_dict.has(setting):
			self.set(setting, MasterDirectoryManager.user_data_dict[setting])
	volume = MasterDirectoryManager.user_data_dict["volume"]
	if not get_node("/root/MainScreen").primary_initialization_finished:
		await get_node("/root/MainScreen").primary_initialization_finished_signal
	if MasterDirectoryManager.user_data_dict["continue_playing"] == true:
		for key : String in MasterDirectoryManager.user_data_dict["active_song_data"].keys().filter(func(item : String) -> bool: return item != "song_progress"):
			if key == "active_song_list":
				active_song_list.assign(MasterDirectoryManager.user_data_dict["active_song_data"]["active_song_list"])
			else:
				self.set(key, MasterDirectoryManager.user_data_dict["active_song_data"][key])
	#
	set_widgets()
	await get_tree().process_frame
	if active_song_id != "":
		load_song(active_song_id)
	await get_tree().process_frame
	if MasterDirectoryManager.user_data_dict["continue_playing_exact"] == true:
		song_progress = MasterDirectoryManager.user_data_dict["active_song_data"].get("song_progress", 0)
	return

func _notification(notif : int) -> void:
	match notif:
		Node.NOTIFICATION_APPLICATION_FOCUS_IN:
			sleeping_state = false
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT:
			sleeping_state = MasterDirectoryManager.user_data_dict.get("sleep_when_unfocused", false)
	return

func _process(_delta : float) -> void:
	if ((%AudioPlayer.stream != null) and (not dragging_progress_bar)):
		%ProgressBar.value = %AudioPlayer.get_playback_position()
		%Percentage.text = str(int((%ProgressBar.value / %ProgressBar.max_value) * 100)) + "%"
		%Percentage.tooltip_text = str(GeneralManager.seconds_to_readable_time(%ProgressBar.value) + " / " + GeneralManager.seconds_to_readable_time(%ProgressBar.max_value)) + " = " + %Percentage.text
	if %TimeWidget.visible:
		%TimeWidget.text = Time.get_time_string_from_system().left(-3)
	return

func _input(_event : InputEvent) -> void:
	if is_pressed("TogglePause"):
		paused = !paused
	elif is_pressed("ToggleLargePlayer"):
		fullscreen = !fullscreen
	elif not fullscreen:
		return
	elif is_pressed("VolumeDown") or is_pressed("VolumeUp"):
		if is_pressed("VolumeUp"):
			volume += 1
		else:
			volume -= 1
		%VolumeIndicator.texture = volume_indicator_textures[int(!is_pressed("VolumeUp"))]
		volume_indicator_tween.kill()
		volume_indicator_tween = create_tween()
		volume_indicator_tween.tween_property(%VolumeIndicator, "self_modulate", Color.TRANSPARENT, 1.0).from(Color.WHITE)
	elif is_pressed("Previous") or is_pressed("Next"):
		if is_pressed("Previous"):
			load_song(next_song_callable.call(-1, false))
		else:
			load_song(next_song_callable.call(1, false))
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
	elif is_pressed("OpenVolumeControl"):
		%VolumeControlPanel.visible = !%VolumeControlPanel.visible
	return

func _exit_tree() -> void:
	if load_song_thread.is_started():
		load_song_thread.wait_to_finish()
	volume_indicator_tween.kill()
	await get_tree().process_frame
	volume_indicator_tween.free()
	return

func load_song_list(list_id : String = active_song_list_id) -> int:
	#print("Load Song List ID: '" + list_id + "', begins with '" + list_id.left(1) + "'")
	active_song_list_id = list_id
	active_song_list = []
	if list_id in special_ids:
		match list_id:
			"@all":
				active_song_list.assign(MasterDirectoryManager.song_id_dict.keys())
			"@random":
				var songs : Array[String] = MasterDirectoryManager.song_id_dict.keys()
				if len(songs) > 0:
					for i : int in range(0, min(len(songs), 10)):
						active_song_list.append(songs.pick_random())
	else:
		if (GeneralManager.get_id_type(list_id) == MasterDirectoryManager.use_type.UNKNOWN) or GeneralManager.get_data(list_id) in ["", "Unknown"]:
			GeneralManager.cli_print_callable.call("[i]SYS_ERROR: Attempted to load song list with an ID of [u]" + list_id + "[/u], which isn't valid. Please check it and try again.[/i]")
			reset_playing_screen()
			return GeneralManager.err.INVALID_ID
		match GeneralManager.get_id_type(list_id):
			MasterDirectoryManager.use_type.ARTIST:
				for item : String in GeneralManager.get_data(list_id, "albums"):
					active_song_list.append_array(GeneralManager.get_data(item, "songs"))
			MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST:
				active_song_list.assign(GeneralManager.get_data(list_id, "songs"))
			MasterDirectoryManager.use_type.SONG:
				active_song_list.assign([list_id])
			MasterDirectoryManager.use_type.PLAYLIST:
				active_song_list.assign(MasterDirectoryManager.playlist_id_dict[list_id]["songs"])
	active_song_list.filter(func(item : String) -> bool: return MasterDirectoryManager.song_id_dict.keys().has(item))
	active_song_list.assign(GeneralManager.get_unique_array(active_song_list))
	if shuffle:
		active_song_list.shuffle()
	if len(active_song_list) == 0:
		GeneralManager.cli_print_callable.call("ALERT: Tried to long song list with ID [u]" + list_id + "[/u], but it has no songs so is unable to be loaded.")
		return GeneralManager.err.LOOKUP_FAILED
	GeneralManager.cli_print_callable.call("SYS: Loaded song list with ID [u]" + list_id + "[/u] with a length of [u]" + str(len(active_song_list)) + "[/u].")
	load_song(GeneralManager.arr_get(active_song_list, 0, ""))
	#print("Load Song List Ran Succesfully")
	return GeneralManager.err.OK

func load_song(song_id : String = active_song_id) -> int:
	#print("\n\nLoad Song ID: '" + song_id + "', begins with '" + song_id.left(1) + "'")
	if (GeneralManager.get_id_type(song_id) != MasterDirectoryManager.use_type.SONG) or (not MasterDirectoryManager.song_id_dict.has(song_id)):
		GeneralManager.cli_print_callable.call("SYS_ERROR: Attempted to load song of ID '[u]" + song_id + "[/u]' which isn't valid, please check it and try again.")
		reset_playing_screen()
		return GeneralManager.err.INVALID_ID
	#print("Song ID is valid.")
	active_song_id = song_id
	var song_data : Dictionary = GeneralManager.get_data(active_song_id)
	#print("song data: " + str(song_data))
	if not song_data["song_file_path"] in song_cache.keys():
		load_song_mutex.lock()
		song_cache[song_data["song_file_path"]] = GeneralManager.load_audio_file(song_data["song_file_path"])
		load_song_mutex.unlock()
	%AudioPlayer.stream = song_cache[song_data["song_file_path"]]
	if %AudioPlayer.stream == null:
		GeneralManager.cli_print_callable.call("SYS_ERROR: Song with an ID of [u]" + song_id + "[/u] was unable to be loaded, the path or audio file may be invalid or corrupted, please check them and try again.")
		reset_playing_screen()
		return GeneralManager.err.LOOKUP_FAILED
	%Title.text = GeneralManager.limit_str(song_data["name"], 30)
	%Title.tooltip_text = song_data["name"]
	%"Album&Band".text = GeneralManager.smart_limit_str([
		GeneralManager.get_data(song_data["album"], "name"), 
		" | ", 
		GeneralManager.get_data(GeneralManager.get_data(song_data["album"], "artist"), "name")]
		, 27)
	%"Album&Band".tooltip_text = GeneralManager.get_data(song_data["album"], "name") + "\n" + GeneralManager.get_data(GeneralManager.get_data(song_data["album"], "artist"), "name")
	var position_str : String = str(str(active_song_list.find(song_id)+1) + "/" + str(len(active_song_list)))
	if not active_song_list_id in special_ids:
		var list_name : String = GeneralManager.get_data(active_song_list_id, "name")
		%Playlist.text = GeneralManager.smart_limit_str([["All Of: ", "Album: ", "Playing: ", "Playlist: "][int(active_song_list_id.left(1))], list_name, " | ", position_str], 32)
		%Playlist.tooltip_text = list_name
	else:
		%Playlist.text = ["All Songs", "Random Songs"][special_ids.find(active_song_list_id)] + " | " + position_str
		%Playlist.tooltip_text = ["All Songs", "Random Songs"][special_ids.find(active_song_list_id)]
	%Playlist.tooltip_text += "\n" + position_str
	%ProgressBar.max_value = %AudioPlayer.stream.get_length()
	%ToggleFavourite.set_pressed_no_signal(song_data["favourite"])
	%Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(GeneralManager.get_data(song_data["album"], "image_file_path")))
	var image_average : Color = GeneralManager.get_image_average(GeneralManager.get_image(GeneralManager.get_data(song_data["album"], "image_file_path")))
	%Background.color = image_average
	var stylebox : StyleBoxFlat = %Image.get_parent().get("theme_override_styles/panel").duplicate()
	if ((image_average.r / 1.5) > 0.1) and ((image_average.g / 1.5) > 0.1) and ((image_average.b / 1.5) > 0.1):
		stylebox.border_color = Color(image_average.r / 1.5, image_average.g / 1.5, image_average.b / 1.5)
	else:
		stylebox.border_color = Color(max(image_average.r, 0.03) * 1.5, max(image_average.g, 0.03) * 1.5, max(image_average.b, 0.03) * 1.5)
	%Image.get_parent().set("theme_override_styles/panel", stylebox)
	%AudioPlayer.play()
	paused = paused
	if load_song_thread.is_started():
		load_song_thread.wait_to_finish()
	load_song_thread.start(Callable(self, "load_next_song_into_cache"))
	#print("!! Load Song Ran Succesfully !!")
	if not disable_player_song_system_messages:
		GeneralManager.cli_print_callable.call("SYS: Now playing song [u]" + str(active_song_list.find(active_song_id) + 1) + "[/u]/[u]" + str(len(active_song_list)) + "[/u] with the ID of [u]" + active_song_id + "[/u].")
	return GeneralManager.err.OK

func load_next_song_into_cache() -> void:
	load_song_mutex.lock()
	var next_song_path : String = GeneralManager.get_data(next_song_callable.call(1, false))["song_file_path"]
	if next_song_path not in song_cache.keys():
		song_cache[next_song_path] = GeneralManager.load_audio_file(next_song_path)
	while len(song_cache.keys()) > MasterDirectoryManager.user_data_dict["song_cache_size"]:
		song_cache.erase(song_cache.keys()[0])
	load_song_mutex.unlock()
	return

func set_player_settings(setting : StringName, value : Variant) -> int:
	if setting in settable_settings and typeof(self.get(setting)) == typeof(value):
		GeneralManager.cli_print_callable.call("NOTIF: Player Settings: Set [u]" + setting + "[/u] from [u]" + str(self.get(setting)) + "[/u] > [u]" + str(value) + "[/u].")
		self.set(setting, value)
		return GeneralManager.err.OK
	if not setting in settable_settings:
		GeneralManager.cli_print_callable.call("ERROR: Setting [u]" + setting + "[/u] does not exist in Player Settings or is unable to be set. Did you mean '[u]" + GeneralManager.spellcheck(setting, settable_settings)[0] + "[/u]'?.")
	else:
		GeneralManager.cli_print_callable.call("ERROR: Tried to set [u]" + setting + "[/u] whos value is of type [u]" + type_string(typeof(self.get(setting))) + "[/u] to [u]" + str(value) + "[/u] which is of type [u]" + type_string(typeof(value)) + "[/u].")
	return GeneralManager.err.INVALID

func get_player_settings() -> Dictionary:
	var data : Dictionary
	for setting : String in settable_settings:
		data[setting] = self.get(setting)
	return data

func reset_playing_screen() -> void:
	active_song_id = ""
	active_song_list = []
	active_song_list_id = ""
	%Playlist.text = "Playlist"
	%Playlist.tooltip_text = "Playlist"
	%Title.text = "Title"
	%Title.tooltip_text = "Title"
	%"Album&Band".text = "Album | Band"
	%"Album&Band".tooltip_text = "Album\nBand"
	%Percentage.text = "0%"
	%Percentage.tooltip_text = "0s / 0s"
	%ProgressBar.value = 0
	%Image.texture = GeneralManager.load_svg_to_img("res://Assets/Icons/Missing.svg", 5)
	%Background.color = Color8(41, 42, 42)
	%AudioPlayer.stop()
	%AudioPlayer.stream = null
	return

func is_pressed(action : StringName) -> bool:
	return Input.is_action_just_pressed(action, true)

func set_widgets() -> void:
	var widgets : Array[Node] = %Background/TopBar/Container.get_children().slice(1, -1)
	widgets.map(func(node : Node) -> Node: node.visible = MasterDirectoryManager.user_data_dict["player_widgets"][widgets.find(node)]; return node)
	%Background/TopBar/Container/Void.visible = (true in MasterDirectoryManager.user_data_dict["player_widgets"])
	return

func create_tooltip(text : String, text_size : int = 16) -> void:
	if fullscreen and len(%TooltipContainer.get_children()) < 1:
		%TooltipContainer.add_child(tooltip_scene.instantiate())
		%TooltipContainer.get_child(-1).text_size = text_size
		%TooltipContainer.get_child(-1).text = text
	return
