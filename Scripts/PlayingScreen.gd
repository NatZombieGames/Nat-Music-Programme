extends Control

@export var active_song_list : Array = []
@export var active_song_list_id : String = ""
@export var active_song_id : String = ""
@export var shuffle : bool = false
var change_callable : Callable = (func(dir : int, loop : bool) -> void: active_song_id = [GeneralManager.arr_get(active_song_list, wrapi(active_song_list.find(active_song_id)+(1*dir), 0, len(active_song_list)), active_song_id), active_song_id][int(loop)]; load_song(); %TogglePlay.texture_normal = GeneralManager.get_icon_texture("Play"); return)
var play_callable : Callable = (func() -> void: %AudioPlayer.stream_paused = !%AudioPlayer.stream_paused;  %TogglePlay.texture_normal = [GeneralManager.get_icon_texture("Play"), GeneralManager.get_icon_texture("Pause")][int(%AudioPlayer.stream_paused)]; return)
var fullscreen_callable : Callable = (func() -> void: var state : bool = get_node(^"/root/MainScreen/Camera").enabled; get_node(^"/root/MainScreen/Camera").enabled = !state; self.get_child(0).enabled = state; %ToggleFullscreen.texture_normal = GeneralManager.get_icon_texture(["Close", ""][int(!state)] + "Fullscreen"); return)
var dragging_progress_bar : bool = false
var loop_enabled : bool = false
var volume_indicator_tween : Tween = create_tween()
const special_ids : PackedStringArray = ["@all", "@everyone"]
const settable_settings : Dictionary = {"shuffle": [false, true]}

func _ready() -> void:
	#
	%TogglePlay.texture_normal = GeneralManager.get_icon_texture(&"Play")
	%TogglePlay.pressed.connect(play_callable)
	%Previous.pressed.connect(change_callable.bind(-1, false))
	%Previous.texture_normal = GeneralManager.get_icon_texture(&"Previous")
	%Next.pressed.connect(change_callable.bind(1, false))
	%Next.texture_normal = GeneralManager.get_icon_texture(&"Next")
	%AudioPlayer.finished.connect(change_callable.bind(1, loop_enabled))
	%ProgressBar.drag_ended.connect(func(value_changed : bool) -> void: if value_changed: %AudioPlayer.play(%ProgressBar.value); %AudioPlayer.stream_paused = %TogglePlay.texture_normal.resource_name == "Pause"; dragging_progress_bar = false; return)
	%ProgressBar.drag_started.connect(func() -> void: dragging_progress_bar = true; return)
	%ProgressBar.set(&"theme_override_icons/grabber", GeneralManager.get_icon_texture(&"EmptyCircle"))
	%ProgressBar.set(&"theme_override_icons/grabber_highlight", GeneralManager.get_icon_texture(&"FilledCircle"))
	for item : String in [&"grabber", &"grabber_highlight"]:
		%ProgressBar.get(&"theme_override_icons/" + item).set_size_override(Vector2i(14, 14))
	%ToggleLoop.texture_normal = GeneralManager.get_icon_texture(&"LoopDisabled")
	%ToggleLoop.pressed.connect(func() -> void: loop_enabled = !loop_enabled; %ToggleLoop.texture_normal = GeneralManager.get_icon_texture(&"Loop" + [&"Disabled", &"Enabled"][int(loop_enabled)]); return)
	%ToggleFullscreen.texture_normal = GeneralManager.get_icon_texture(&"Fullscreen")
	%ToggleFullscreen.pressed.connect(fullscreen_callable)
	%MuteWidget.texture_normal = GeneralManager.get_icon_texture(&"VolumeDisabled")
	%MuteWidget.texture_pressed = GeneralManager.get_icon_texture(&"VolumeUp")
	%MuteWidget.toggled.connect(func(state : bool) -> void: %AudioPlayer.bus = [&"Muted", &"Master"][int(state)]; return)
	#
	if MasterDirectoryManager.finished_loading_data == false:
		await MasterDirectoryManager.finished_loading_data_signal
	for item : String in MasterDirectoryManager.user_data_dict["active_song_data"].keys():
		self.set(item, MasterDirectoryManager.user_data_dict["active_song_data"][item])
	%AudioPlayer.volume_db = MasterDirectoryManager.user_data_dict["volume"]
	shuffle = MasterDirectoryManager.user_data_dict["shuffle"]
	set_widgets()
	if active_song_id != "":
		load_song(active_song_id)
	return

func _process(_delta : float) -> void:
	if %AudioPlayer.stream != null:
		if not dragging_progress_bar:
			%ProgressBar.value = %AudioPlayer.get_playback_position()
		%Percentage.text = str(int((%ProgressBar.value / %ProgressBar.max_value) * 100)) + "%"
	if %TimeWidget.visible:
		%TimeWidget.text = Time.get_time_string_from_system().left(-3)
	return

func _input(_event : InputEvent) -> void:
	if is_pressed("VolumeDown") or is_pressed("VolumeUp"):
		if is_pressed("VolumeUp"):
			%AudioPlayer.volume_db += 1
			%VolumeIndicator.texture = GeneralManager.get_icon_texture("VolumeUp")
		else:
			%AudioPlayer.volume_db -= 1
			%VolumeIndicator.texture = GeneralManager.get_icon_texture("VolumeDown")
		MasterDirectoryManager.user_data_dict["volume"] = %AudioPlayer.volume_db
		volume_indicator_tween.kill()
		volume_indicator_tween = create_tween()
		volume_indicator_tween.tween_property(%VolumeIndicator, "self_modulate", Color(1, 1, 1, 0), 1.0).from(Color(1, 1, 1, 1))
	elif is_pressed("Previous") or is_pressed("Next"):
		if is_pressed("Previous"):
			change_callable.call(-1, false)
		else:
			change_callable.call(1, false)
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
		play_callable.call()
	elif is_pressed("ToggleLargePlayer"):
		fullscreen_callable.call()
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
		if (GeneralManager.get_id_type(list_id) == MasterDirectoryManager.use_type.UNKNOWN) or (typeof(GeneralManager.get_data(list_id)) == TYPE_STRING):
			print("Invalid Song List ID")
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
	active_song_list.filter(func(item : String) -> bool: return MasterDirectoryManager.song_id_dict.keys().has(item))
	if shuffle == true:
		active_song_list.shuffle()
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
	GeneralManager.cli_print_callable.call("[i]Player is now playing a song with the ID of [u]" + active_song_id + "[/u].[/i]")
	var song_data : Dictionary = GeneralManager.get_data(active_song_id)
	print("song data: " + str(song_data))
	%AudioPlayer.stream = GeneralManager.load_audio_file(song_data["song_file_path"])
	%Title.text = GeneralManager.limit(song_data["name"], 25)
	%"Album&Band".text = GeneralManager.limit(GeneralManager.get_data(song_data["album"], "name"), 10) + " | " + GeneralManager.limit(GeneralManager.get_data(GeneralManager.get_data(song_data["album"], "artist"), "name"), 10)
	var list_name : String = GeneralManager.get_data(active_song_list_id, "name")
	if not active_song_list_id in special_ids:
		%Playlist.text = ["All Of: ", "Album: ", "Listening To: ", "Playlist: "][int(active_song_list_id[0])] + GeneralManager.limit(list_name, 13)
	else:
		%Playlist.text = ["Every Song"][special_ids.find(active_song_list_id)]
	%Playlist.text += " | " + str(str(active_song_list.find(song_id)+1) + "/" + str(len(active_song_list)))
	%ProgressBar.max_value = %AudioPlayer.stream.get_length()
	%Image.texture = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(GeneralManager.get_data(song_data["album"], "image_file_path")))
	print("Image texture after load: " + str(%Image.texture))
	var image_average : Color = GeneralManager.get_image_average(GeneralManager.get_image_from_cache(GeneralManager.get_data(song_data["album"], "image_file_path")))
	%Background.color = image_average
	var stylebox : StyleBoxFlat = %Image.get_parent().get("theme_override_styles/panel").duplicate()
	stylebox.border_color = Color(image_average.r/1.5, image_average.g/1.5, image_average.b/1.5)
	%Image.get_parent().set("theme_override_styles/panel", stylebox)
	%TogglePlay.texture_normal = GeneralManager.get_icon_texture("Play")
	%AudioPlayer.play()
	print("Load Song Ran Succesfully")
	return OK

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
	%Image.texture = GeneralManager.get_icon_texture()
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
