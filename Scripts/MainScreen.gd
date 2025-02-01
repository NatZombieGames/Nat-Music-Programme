extends Control

@onready var entryitem_scene : PackedScene = preload("res://Scenes/EntryItem.tscn")
@onready var basic_entryitem_scene : PackedScene = preload("res://Scenes/BasicEntryItem.tscn")
@onready var popup_notif_scene : PackedScene = preload("res://Scenes/PopupNotification.tscn")
@onready var list_item_scene : PackedScene = preload("res://Scenes/ListItem.tscn")
@onready var keybind_scene : PackedScene = preload("res://Scenes/KeybindScene.tscn")
@export var playing_screen : Control
@export var cli : PanelContainer
var song_upload_list : Array = []
var popup_response : int = 0
var library_page : int = 0
var library_details_item_id : String
var custom_inputmap_actions : PackedStringArray = InputMap.get_actions().filter(func(item : String) -> bool: return not item.left(3) == "ui_")
var active_keybind_switching_data : Array = []
var new_playlist_data : Dictionary = (func() -> Dictionary: return MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.PLAYLIST)).call()
signal popup_responded
const user_setting_keys : PackedStringArray = ["save_on_quit", "continue_playing"]

func _ready() -> void:
	%LoadingScreen.visible = true
	GeneralManager.set_mouse_busy_state.call(true)
	await get_tree().process_frame
	#
	playing_screen = %PlayingScreen
	cli = %CommandLineInterface
	MasterDirectoryManager.load_data()
	await get_tree().process_frame
	if MasterDirectoryManager.finished_loading_data == false:
		await MasterDirectoryManager.finished_loading_data_signal
	%MainContainer/New/Container/Container/Body/Artist/Container/InfoPanel/Container/ImageContainer/SelectFileButton.pressed.connect(func() -> void: %SelectImageDialog.visible = true; %MainContainer/New/Container/Container/Body/Artist/Container/InfoPanel/Container/ImageContainer/ImagePath.text = %SelectImageDialog.current_file; update_new_artist_screen(); return)
	%MainContainer/New/Container/Container/Body/Artist/Container/InfoPanel/Container/ButtonContainer/LoadIconButton.pressed.connect(Callable(self, "update_new_artist_screen"))
	%MainContainer/New/Container/Container/Body/Artist/Container/InfoPanel/Container/ButtonContainer/ConfirmButton.pressed.connect(Callable(self, "update_new_artist_screen").bind(true))
	%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ArtistContainer/SelectArtistButton.pressed.connect(func() -> void: %MainContainer/New/Container/Container/Body/Album/ArtistList.visible = !%MainContainer/New/Container/Container/Body/Album/ArtistList.visible;  if %MainContainer/New/Container/Container/Body/Album/ArtistList.visible == true: populate_data_list(%MainContainer/New/Container/Container/Body/Album/ArtistList/ScrollContainer/Container, MasterDirectoryManager.use_type.ARTIST, "album_artist_selected", self); return)
	%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ImageContainer/SelectFileButton.pressed.connect(func() -> void: %SelectImageDialog.visible = true; %MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ImageContainer/ImagePath.text = %SelectImageDialog.current_file; update_new_album_screen(); return)
	%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ButtonContainer/LoadButton.pressed.connect(Callable(self, "update_new_album_screen"))
	%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ButtonContainer/ConfirmButton.pressed.connect(Callable(self, "update_new_album_screen").bind(true))
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/Container/AlbumContainer/SelectAlbumButton.pressed.connect(func() -> void: %MainContainer/New/Container/Container/Body/Song/AlbumList.visible = !%MainContainer/New/Container/Container/Body/Song/AlbumList.visible;  if %MainContainer/New/Container/Container/Body/Song/AlbumList.visible == true: populate_data_list(%MainContainer/New/Container/Container/Body/Song/AlbumList/ScrollContainer/Container, MasterDirectoryManager.use_type.ALBUM, "song_album_selected", self); return)
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/ButtonContainer/LoadButton.pressed.connect(Callable(self, "update_new_song_screen"))
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/ButtonContainer/ConfirmButton.pressed.connect(Callable(self, "update_new_song_screen").bind(true))
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/CloseBtn.texture_normal = GeneralManager.get_icon_texture("Close")
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/CloseBtn.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile.visible = false; %MainContainer/Library/Container/ScrollContainer.visible = true; return)
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.texture_normal = GeneralManager.get_icon_texture("Refresh")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.pressed.connect(func() -> void: open_context_menu(library_details_item_id); return)
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ClearBtn.texture_normal = GeneralManager.get_icon_texture("Delete")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ClearBtn.pressed.connect(Callable(self, "profile_clear_pressed"))
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.texture_normal = GeneralManager.get_icon_texture("Upload")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible == true: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM][library_page - 1], "profile_selector_selected", self); return)
	set_main_screen_page("0")
	set_new_screen_page("0")
	populate_library_screen(0)
	GeneralManager.set_mouse_busy_state.call(true)
	set_profile_screen_page("0")
	set_playlist_screen_page("0")
	%Hatbar/Container/BuildType.text = GeneralManager.build + " Build."
	%Hatbar/Container/Version.text = GeneralManager.version
	for item : String in user_setting_keys:
		%MainContainer/Profile/Container/Body/Settings/Container/SettingsPanel/Container/Buttons.get_child(user_setting_keys.find(item)).update({"pressed": MasterDirectoryManager.user_data_dict[item]})
	for i : int in range(0, len(MasterDirectoryManager.user_data_dict["player_widgets"])):
		%MainContainer/Profile/Container/Body/Settings/Container/WidgetPanel/Container/Buttons.get_child(i).update({"pressed": MasterDirectoryManager.user_data_dict["player_widgets"][i]})
	update_keybinds_screen()
	DisplayServer.window_set_mode(MasterDirectoryManager.user_data_dict["window_mode"])
	DisplayServer.window_set_current_screen(wrapi(MasterDirectoryManager.user_data_dict["window_screen"], 0, DisplayServer.get_screen_count()))
	DisplayServer.window_set_size(MasterDirectoryManager.user_data_dict["window_size"])
	get_tree().get_root().set("position", MasterDirectoryManager.user_data_dict["window_position"])
	if MasterDirectoryManager.user_data_dict["player_fullscreen"] == true:
		%PlayingScreen.fullscreen_callable.call()
	#
	await get_tree().process_frame
	await create_tween().tween_property(%LoadingScreen, "modulate", Color(1, 1, 1, 0), 0.25).from(Color(1, 1, 1, 1)).finished
	%LoadingScreen.visible = false
	GeneralManager.set_mouse_busy_state.call(false)
	return

func _input(event : InputEvent) -> void:
	#if event.get_class() != "InputEventMouseMotion" and event.is_echo() == false and event.is_pressed() == true:
	#	print(event)
	if GeneralManager.is_valid_keybind.call(event) and $Camera/AspectRatioContainer/KeybindScreen.visible == true:
		if GeneralManager.get_event_code(event) != KEY_DELETE:
			#print("\n\nkeybind: " + str(MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]) + "\nreplacing customevent " + str(MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]][active_keybind_switching_data[0]]) + "\nwith new custom event of " + str(GeneralManager.parse_inputevent_to_customevent(event)) + "\nkeybinds before change: " + str(MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]]) + ", changing index " + str(active_keybind_switching_data[0]) + "\n\n")
			MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]][active_keybind_switching_data[0]] = GeneralManager.parse_inputevent_to_customevent(event)
		else:
			MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]][active_keybind_switching_data[0]] = ""
		MasterDirectoryManager.apply_control_settings()
		await get_tree().process_frame
		update_keybinds_screen()
		$Camera/AspectRatioContainer/KeybindScreen.visible = false
		print("-")
	elif $Camera/AspectRatioContainer/KeybindScreen.visible == false:
		if Input.is_action_just_pressed(&"ToggleFullscreen", true):
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
				MasterDirectoryManager.user_data_dict["window_mode"] = DisplayServer.window_get_mode()
			elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and MasterDirectoryManager.user_data_dict["window_mode"] == DisplayServer.WINDOW_MODE_FULLSCREEN:
				MasterDirectoryManager.user_data_dict["window_mode"] = DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_FULLSCREEN, MasterDirectoryManager.user_data_dict["window_mode"]][int(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)])
		elif Input.is_action_just_pressed(&"QuitAndSave", true):
			MasterDirectoryManager.save_data()
			await get_tree().process_frame
			if MasterDirectoryManager.finished_saving_data == false:
				await MasterDirectoryManager.finished_saving_data_signal
			get_tree().quit()
		elif Input.is_action_just_pressed(&"QuitWithoutSaving", true):
			get_tree().quit()
		elif Input.is_action_just_pressed(&"HardReloadApp", true):
			get_tree().reload_current_scene()
		elif Input.is_action_just_pressed(&"ToggleCLI", true):
			%CommandLineInterface.active = !%CommandLineInterface.active
			%CommandLineInterface.visible = %CommandLineInterface.active
			%CommandLineInterface/Container/InputField.call(["release_focus", "grab_focus"][int(%CommandLineInterface.visible)])
	return

func update_keybinds_screen() -> void:
	while len(%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds.get_children()) < len(MasterDirectoryManager.keybinds):
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds.add_child(keybind_scene.instantiate())
	for keybind : StringName in MasterDirectoryManager.keybinds.keys():
		var events : Array = MasterDirectoryManager.user_data_dict["keybinds"][keybind]
		var data : Dictionary = {"title": "[i]" + keybind + "[/i]", "button_1_text": "None", "button_2_text": "None", "pressed_sender": self, "pressed_signal_name": "keybind_button_pressed", "pressed_arguments": [MasterDirectoryManager.keybinds.keys().find(keybind)]}
		for i : int in range(0, mini(len(events), 2)):
			if typeof(events[i]) == TYPE_DICTIONARY:
				data["button_" + str(i+1) + "_text"] = GeneralManager.customevent_to_string(events[i])
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds.get_child(MasterDirectoryManager.keybinds.keys().find(keybind)).update(data)
	return

func update_new_artist_screen(create : bool = false) -> void:
	var image_file_path : String = %MainContainer/New/Container/Container/Body/Artist/Container/InfoPanel/Container/ImageContainer/ImagePath.text
	%MainContainer/New/Container/Container/Body/Artist/Container/ImageContainer/Image.texture = GeneralManager.get_icon_texture("Missing")
	if GeneralManager.is_valid_image.call(image_file_path):
		%MainContainer/New/Container/Container/Body/Artist/Container/ImageContainer/Image.texture = ImageTexture.create_from_image(Image.load_from_file(image_file_path))
	if create:
		var data : Dictionary = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.ARTIST)
		data["name"] = %MainContainer/New/Container/Container/Body/Artist/Container/InfoPanel/Container/NameField.text
		data["image_file_path"] = image_file_path
		MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.ARTIST)] = data
		create_popup_notif("[i] New Artist Created Succesfully [/i]")
	return

func update_new_album_screen(create : bool = false) -> void:
	var image_file_path : String = %MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ImageContainer/ImagePath.text
	%MainContainer/New/Container/Container/Body/Album/Container/ImageContainer/Image.texture = GeneralManager.get_icon_texture("Missing")
	if GeneralManager.is_valid_image.call(image_file_path):
		%MainContainer/New/Container/Container/Body/Album/Container/ImageContainer/Image.texture = ImageTexture.create_from_image(Image.load_from_file(image_file_path))
	var artist_id : String = %MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ArtistContainer/ArtistField.text
	%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ArtistDisplay.text = "Artist: "
	if MasterDirectoryManager.artist_id_dict.has(artist_id):
		%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ArtistDisplay.text += MasterDirectoryManager.artist_id_dict[artist_id]["name"]
	%MainContainer/New/Container/Container/Body/Album/ArtistList.visible = false
	if create:
		var data : Dictionary = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.ALBUM)
		data["name"] = %MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/NameField.text
		data["artist"] = artist_id
		data["image_file_path"] = image_file_path
		MasterDirectoryManager.album_id_dict[MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.ALBUM)] = data
		MasterDirectoryManager.artist_id_dict[artist_id]["albums"].append(MasterDirectoryManager.album_id_dict.find_key(data))
		create_popup_notif("[i] New Album Created Succesfully [/i]")
	return

func update_new_song_screen(create : bool = false) -> void:
	var album_id : String = %MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/Container/AlbumContainer/AlbumField.text
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/Container/AlbumDisplay.text = "Album: "
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/ImageContainer/Image.texture = GeneralManager.get_icon_texture("Missing")
	if MasterDirectoryManager.album_id_dict.has(album_id):
		%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/Container/AlbumDisplay.text += MasterDirectoryManager.album_id_dict[album_id]["name"]
		if GeneralManager.is_valid_image.call(MasterDirectoryManager.album_id_dict[album_id]["image_file_path"]):
			%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(Image.load_from_file(MasterDirectoryManager.album_id_dict[album_id]["image_file_path"]))
	if create:
		for item : Dictionary in song_upload_list:
			var data : Dictionary = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.SONG)
			data["name"] = item["name"]
			data["album"] = album_id
			data["song_file_path"] = item["path"]
			MasterDirectoryManager.song_id_dict[MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.SONG)] = data
			if album_id != "":
				MasterDirectoryManager.album_id_dict[album_id]["songs"].append(MasterDirectoryManager.song_id_dict.find_key(data))
		create_popup_notif("[i] New Song" + ["(s)", ""][int(len(song_upload_list) < 2)] + " Uploaded Succesfully. [/i]")
		clear_song_upload_list()
	return

func album_artist_selected(id : String) -> void:
	print("selected album artist id is " + id)
	%MainContainer/New/Container/Container/Body/Album/ArtistList.visible = false
	%MainContainer/New/Container/Container/Body/Album/Container/InfoPanel/Container/ArtistContainer/ArtistField.text = id
	update_new_album_screen()
	return

func song_album_selected(id : String) -> void:
	print("selected song album id is " + id)
	%MainContainer/New/Container/Container/Body/Song/AlbumList.visible = false
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/HeaderContainer/Container/AlbumContainer/AlbumField.text = id
	update_new_song_screen()
	return

func profile_selector_selected(id : String) -> void:
	print("soy happened with an id of " + id + ", with a library details id of " + library_details_item_id + ", to change key of " + ["album", "artist"][int(GeneralManager.get_id_type(library_details_item_id) == MasterDirectoryManager.use_type.ALBUM)])
	library_details_info_altered(id, ["album", "artist"][int(GeneralManager.get_id_type(library_details_item_id) == MasterDirectoryManager.use_type.ALBUM)])
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.emit_signal("pressed")
	%MainContainer/Library/Container/Profile/SelectList.visible = false
	return

func profile_clear_pressed() -> void:
	match GeneralManager.get_id_type(library_details_item_id):
		MasterDirectoryManager.use_type.ALBUM:
			if MasterDirectoryManager.album_id_dict[library_details_item_id]["artist"] != "":
				MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.album_id_dict[library_details_item_id]["artist"]]["albums"].erase(library_details_item_id)
			MasterDirectoryManager.album_id_dict[library_details_item_id]["artist"] = ""
		MasterDirectoryManager.use_type.SONG:
			if MasterDirectoryManager.song_id_dict[library_details_item_id]["album"] != "":
				MasterDirectoryManager.album_id_dict[MasterDirectoryManager.song_id_dict[library_details_item_id]["album"]]["songs"].erase(library_details_item_id)
			MasterDirectoryManager.song_id_dict[library_details_item_id]["album"] = ""
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.emit_signal("pressed")
	return

func playlist_add_button_pressed(index : String, arg : String = "") -> void:
	if arg.is_valid_int() and not index.is_valid_int():
		var intermediary : Array[String] = [arg, index]
		arg = intermediary[1]
		index = intermediary[0]
	print("soy happened with an str index of " + index + " which as an int is " + str(int(index)))
	if int(index) in [3, 4, 5]:
		%MainContainer/Playlists/Container/Body/Create/SelectList.visible = !%MainContainer/Playlists/Container/Body/Create/SelectList.visible
	match int(index):
		0:
			%SelectImageDialog.visible = true
			new_playlist_data["image_file_path"] = %SelectImageDialog.current_file
			%MainContainer/Playlists/Container/Body/Create/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(new_playlist_data["image_file_path"]))
		1:
			new_playlist_data["name"] = arg
		2:
			var id : String = MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.PLAYLIST)
			MasterDirectoryManager.playlist_id_dict[id] = new_playlist_data
			new_playlist_data = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.PLAYLIST)
			create_popup_notif("[i] New Playlist [u]" + new_playlist_data["name"] + "[/u] Created With ID: [u]" + id + "[/u].[/i]")
		3:
			if %MainContainer/Playlists/Container/Body/Create/SelectList.visible:
				populate_data_list(%MainContainer/Playlists/Container/Body/Create/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.ARTIST, "playlist_add_content_selected", self)
		4:
			if %MainContainer/Playlists/Container/Body/Create/SelectList.visible:
				populate_data_list(%MainContainer/Playlists/Container/Body/Create/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.ALBUM, "playlist_add_content_selected", self)
		5:
			if %MainContainer/Playlists/Container/Body/Create/SelectList.visible:
				populate_data_list(%MainContainer/Playlists/Container/Body/Create/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.SONG, "playlist_add_content_selected", self)
	return

func playlist_add_content_selected(id : String) -> void:
	var songs : PackedStringArray
	match GeneralManager.get_id_type(id):
		MasterDirectoryManager.use_type.ARTIST:
			MasterDirectoryManager.get_artist_discography_data(id).keys().map(func(item : String) -> String: songs.append_array(MasterDirectoryManager.get_album_tracklist_data(item).keys()); return item)
		MasterDirectoryManager.use_type.ALBUM:
			songs.append_array(MasterDirectoryManager.get_album_tracklist_data(id).keys())
		MasterDirectoryManager.use_type.SONG:
			songs.append(id)
		_:
			create_popup_notif("[i] Invalid ID '[u]" + id + "[/u]' Selected For New Playlist Content Addition, Please Try Again. [/i]")
	new_playlist_data["songs"].append_array(songs)
	new_playlist_data["songs"] = GeneralManager.get_unique_array(new_playlist_data["songs"])
	%MainContainer/Playlists/Container/Body/Create/Container/Container/DataList/Container/InfoContainer/ItemQuantity.text = " Items: " + str(len(new_playlist_data["songs"]))
	var data : Dictionary
	for item : String in new_playlist_data["songs"]:
		data[item] = MasterDirectoryManager.get_object_data.call(item)
	populate_data_list_context_menu(%MainContainer/Playlists/Container/Body/Create/Container/Container/DataList/Container/ScrollContainer/Container, MasterDirectoryManager.use_type.SONG, data, self, [""])
	return

func playlist_song_list_button_pressed(args : Array[Variant]) -> void:
	var item : String
	var intermediary : String
	match args[0]:
		"0":
			if args[3] > 0:
				item = new_playlist_data["songs"][args[3]-1]
				intermediary = new_playlist_data["songs"][args[3]]
				new_playlist_data["songs"][args[3]] = item
				new_playlist_data["songs"][args[3]-1] = intermediary
				args[2].move_child(args[2].get_child(args[3]-1), args[3])
		"1":
			if args[3] < len(new_playlist_data["songs"])-1:
				item = new_playlist_data["songs"][args[3]+1]
				intermediary = new_playlist_data["songs"][args[3]]
				new_playlist_data["songs"][args[3]] = item
				new_playlist_data["songs"][args[3]+1] = intermediary
				args[2].move_child(args[2].get_child(args[3]+1), args[3])
		"2":
			play(args[1])
		"3":
			set_favourite(args[1])
	return

func populate_data_list(location : Node, type : MasterDirectoryManager.use_type, pressed_name : String = "entryitem_pressed", pressed_sender : Node = self) -> void:
	await _set_soft_loading(true)
	#
	var data : Dictionary = MasterDirectoryManager.get(str(MasterDirectoryManager.use_type.keys()[type]).to_lower() + "_id_dict")
	var keys : PackedStringArray = (func() -> Array: var arr : Array = data.keys(); arr.sort_custom((func(x : String, y : String) -> bool: return data[x]["name"] < data[y]["name"])); return arr).call()
	var get_image : Callable = (func(path : String) -> ImageTexture: var image : Image = GeneralManager.get_image_from_cache(path); var texture : ImageTexture = ImageTexture.create_from_image(image); texture.resource_name = image.resource_name; return texture)
	while len(location.get_children()) < len(keys):
		location.add_child(entryitem_scene.instantiate())
	for node : Node in location.get_children():
		node.visible = location.get_children().find(node) < len(keys)
		if node.visible == true:
			var key : String = keys[location.get_children().find(node)]
			var to_update : Dictionary = {"title": data[key]["name"], "subtitle": key, "image": GeneralManager.get_icon_texture("Missing"), "pressed_signal_sender": pressed_sender, "pressed_signal_name": pressed_name, "pressed_signal_argument": key}
			if type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST] and GeneralManager.is_valid_image.call(data[key]["image_file_path"]):
				to_update["image"] = get_image.call(data[key]["image_file_path"])
			elif type == MasterDirectoryManager.use_type.SONG and GeneralManager.is_valid_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"]):
				to_update["image"] = get_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"])
			node.call("update", to_update)
	#
	await _set_soft_loading(false)
	return

func populate_data_list_context_menu(location : Node, type : MasterDirectoryManager.use_type, data : Dictionary, pressed_sender : Node = self, action_button_signal_names : PackedStringArray = ["context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed"]) -> void:
	print("\n\ndata received in populate data list context menu: " + str(data) + "\n\n")
	await _set_soft_loading(true)
	#
	var keys : PackedStringArray = data.keys()
	var get_image : Callable = (func(path : String) -> ImageTexture: var image : Image = GeneralManager.get_image_from_cache(path); var texture : ImageTexture = ImageTexture.create_from_image(image); texture.resource_name = image.resource_name; return texture)
	while len(location.get_children()) < len(keys):
		location.add_child(list_item_scene.instantiate())
	for item : Node in location.get_children():
		item.visible = location.get_children().find(item) < len(keys)
		if item.visible == true:
			var key : String = keys[location.get_children().find(item)]
			var parent_id : String = data[key][MasterDirectoryManager.use_type.find_key(int(key.left(1))-1).to_lower()]
			var to_update : Dictionary = {"title": data[key]["name"], "subtitle": key, "copy_subtitle_text": ("[i] ID '[u]" + key + "[/u]' Was Copied To Clipboard. [/i]"), "image": GeneralManager.get_icon_texture("Missing"), "action_button_sender": pressed_sender, "action_buttons": 4, "action_button_images": ["Up", "Down", "Play", ["Favourite", "Favourited"][int(data[key]["favourite"])]], "action_button_signal_names": action_button_signal_names, "action_button_arguments": [["0", parent_id, location], ["1", parent_id, location], ["2", key], ["3", key]]}
			if type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST] and GeneralManager.is_valid_image.call(data[key]["image_file_path"]):
				to_update["image"] = get_image.call(data[key]["image_file_path"])
			elif type == MasterDirectoryManager.use_type.SONG and GeneralManager.is_valid_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"]):
				to_update["image"] = get_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"])
			item.call("update", to_update)
	#
	await _set_soft_loading(false)
	return

func set_song_upload_style(style : String) -> void:
	print("-\nsong upload style is " + str(style))
	var dialog : FileDialog = [%SelectSongDialog, %SelectSongDirectoryDialog][int(style)]
	dialog.visible = true
	var selected : String = [dialog.current_file, dialog.current_path.get_slice("/", 1)][int(style)]
	print("selected " + selected)
	print("selected is valid path: " + str(DirAccess.dir_exists_absolute(selected)))
	if selected != "" and not [FileAccess.file_exists(selected), DirAccess.dir_exists_absolute(selected)][int(style)]:
		create_popup_notif("[i]" + [" Unable To Validate File", " Unable To Validate Directory"][int(style)] + ", Please Try Again With A Different Path. [/i]")
		return
	if int(style) == 0:
		print("adding one file")
		song_upload_list.append({"name": selected.get_file().get_basename(), "path": selected})
	elif int(style) == 1:
		print("adding directory")
		for item : String in (func() -> Array: var dir : DirAccess = DirAccess.open(selected); print("Dir Access Status: " + str(DirAccess.get_open_error())); return Array(dir.get_files()).filter(func(file : String) -> bool: return file.get_extension() in ["mp3", "wav"])).call():
			print("adding into song upload list: " + str({"name": item.get_basename(), "path": selected + "\\"[0] + item}))
			song_upload_list.append({"name": item.get_basename(), "path": selected + "\\"[0] + item})
		print("Dir Acess Err: " + str(DirAccess.get_open_error()))
	populate_song_upload_list()
	return

func populate_library_screen(page : int) -> int:
	print("\n- populate library start with a page of " + str(page))
	await _set_soft_loading(true)
	#
	library_page = page
	%MainContainer/Library/Container/Profile.visible = false
	%MainContainer/Library/Container/ScrollContainer.visible = true
	%MainContainer/Library/Container/Header/TabContainer/Page.text = [" Artists", " Albums", " Songs"][page]
	var location : VBoxContainer = %MainContainer/Library/Container/ScrollContainer/ItemList
	var data : Dictionary = MasterDirectoryManager.get(["artist", "album", "song"][library_page] + "_id_dict")
	var data_keys : PackedStringArray = (func() -> Array: var arr : Array = data.keys(); arr.sort_custom((func(x : String, y : String) -> bool: return data[x]["name"] < data[y]["name"])); return arr).call()
	while len(location.get_children()) < len(data_keys):
		location.add_child(list_item_scene.instantiate())
	if len(data_keys) < len(location.get_children()):
		data_keys.append_array((func() -> Array: var arr : PackedStringArray = []; arr.resize(len(location.get_children()) - len(data_keys)); arr.fill("invalid"); return arr).call())
	for item : int in range(0, len(data_keys)):
		var node : Node = location.get_child(item)
		var data_id : String = data_keys[item]
		node.visible = data_id != "invalid"
		if node.visible:
			#print("data id: " + data_id + ", data: " + str(data[data_id]))
			var to_update : Dictionary = {"title": data[data_id]["name"], "subtitle": data_id, "copy_subtitle_text": ("[i] ID '[u]" + data_id + "[/u]' Was Copied To Clipboard. [/i]"), "image": "", "action_button_sender": self, "action_buttons": 4, "action_button_images": ["Elipses", "Play", ["Favourite", "Favourited"][int(data[data_id]["favourite"])], "Delete"], "action_button_signal_names": ["open_context_menu", "play", "set_favourite", "delete"], "action_button_arguments": [data_id, data_id, data_id, data_id]}
			if library_page == 2:
				if data[data_id]["album"] != "" and data[data_id]["album"] in MasterDirectoryManager.album_id_dict.keys():
					to_update["image"] = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(MasterDirectoryManager.album_id_dict[data[data_id]["album"]]["image_file_path"]))
				else:
					to_update["image"] = GeneralManager.get_icon_texture("Missing")
			else:
				to_update["image"] = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(data[data_id]["image_file_path"]))
			node.update(to_update)
	#
	await _set_soft_loading(false)
	return OK

func populate_library_screen_str(page : String) -> void:
	populate_library_screen(int(page))
	return

func library_details_info_altered(new_value : String, property_name : String) -> void:
	var item_dict_name : String = ["artist", "album", "song"][int(library_details_item_id[0])] + "_id_dict"
	print("trying to set " + item_dict_name + " with an id of " + library_details_item_id + " with the key of " + property_name + " to the value of " + new_value)
	if property_name in ["artist", "album"]:
		match property_name:
			"artist":
				if MasterDirectoryManager.album_id_dict[library_details_item_id]["artist"] != "":
					MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.album_id_dict[library_details_item_id]["artist"]]["albums"].erase(library_details_item_id)
				MasterDirectoryManager.artist_id_dict[new_value]["albums"].append(library_details_item_id)
			"album":
				if MasterDirectoryManager.song_id_dict[library_details_item_id]["album"] != "":
					MasterDirectoryManager.album_id_dict[MasterDirectoryManager.song_id_dict[library_details_item_id]["album"]]["songs"].erase(library_details_item_id)
				MasterDirectoryManager.album_id_dict[new_value]["songs"].append(library_details_item_id)
	MasterDirectoryManager.get(item_dict_name)[library_details_item_id][property_name] = new_value
	return

func clear_song_upload_list(_arg : String = "0") -> void:
	song_upload_list = []
	for item : Node in %MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/SelectPanel/GreaterContainer/ScrollContainer/Container.get_children():
		item.queue_free()
	return

func remove_from_song_upload_list(index : String) -> void:
	print("\nindex to remove form song upload list: " + index + "\n")
	song_upload_list.remove_at(int(index))
	%MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/SelectPanel/GreaterContainer/ScrollContainer/Container.get_child(int(index)).queue_free()
	populate_song_upload_list()
	return

func update_song_upload_list_data(data : Array[Variant] = ["new_value", 0], to_change : String = "name") -> void:
	#print("song upload list before: " + str(song_upload_list).replace(" }, ", " }\n") + "\ndata: " + str(data))
	song_upload_list[data[1]][to_change] = data[0]
	#print("song upload list after: " + str(song_upload_list).replace(" }, ", " }\n"))
	return

func populate_song_upload_list() -> void:
	print("\nsong upload list at population:\n" + str(song_upload_list).replace(" }, ", " }\n"))
	var location : Node = %MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/SelectPanel/GreaterContainer/ScrollContainer/Container
	for item : Node in location.get_children():
		item.queue_free()
	for item : Dictionary in song_upload_list:
		location.add_child(basic_entryitem_scene.instantiate())
		#print("data to set in song upload list population: " + str({"title": item["name"], "subtitle": item["path"], "button_icon_name": "Delete", "pressed_signal_sender": self, "pressed_signal_name": "remove_from_song_upload_list", "pressed_signal_argument": str(song_upload_list.find(item))}))
		#                                     {"title": item["name"], "subtitle": item["path"], "id": str(song_upload_list.find(item)), "editable_title": true, "signal_sender": self, "button_icon_name": "Delete", "pressed_signal_name": "remove_from_song_upload_list", "title_changed_signal_name": "change_song_upload_list_data"}
		location.get_child(-1).call("update", {"title": item["name"], "subtitle": item["path"], "id": str(song_upload_list.find(item)), "editable_title": true, "signal_sender": self, "button_icon_name": "Delete", "pressed_signal_name": "remove_from_song_upload_list", "title_changed_signal_name": "update_song_upload_list_data"})
		#await get_tree().process_frame
	return

func open_context_menu(id : String) -> int:
	print("open context menu called with id of: " + id)
	GeneralManager.set_mouse_busy_state.call(true)
	library_details_item_id = id
	%MainContainer/Library/Container/ScrollContainer.visible = false
	var id_type : MasterDirectoryManager.use_type = GeneralManager.get_id_type(id)
	if GeneralManager.get_id_type(id) == MasterDirectoryManager.use_type.UNKNOWN:
		return ERR_INVALID_PARAMETER
	#
	if id_type == MasterDirectoryManager.use_type.SONG:
		%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["image_file_path"]))
	else:
		%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(MasterDirectoryManager.get_object_data.call(id)["image_file_path"]))
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Title.update({"editing_mode": true, "text": MasterDirectoryManager.get_object_data.call(id)["name"]})
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Title.update({"editing_mode": false})
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Subtitle.text = id
	%MainContainer/Library/Container/Profile/Container/Container/Body.get_children().map(func(node : Node) -> Node: node.visible = node.name.to_lower() == MasterDirectoryManager.get_data_types.call()[GeneralManager.get_id_type(id)]; return)
	#for item : Node in %MainContainer/Library/Container/Profile/Container/Container/Body.get_children():
	#	item.visible = item.name.to_lower() == MasterDirectoryManager.get_data_types.call()[GeneralManager.get_id_type(id)]
	var page_body : Node = %MainContainer/Library/Container/Profile/Container/Container/Body
	var page_parent : Node = %MainContainer/Library/Container/Profile/Container/Container/ParentContainer
	page_parent.visible = !(id_type == MasterDirectoryManager.use_type.ARTIST)
	page_body.visible = !(id_type == MasterDirectoryManager.use_type.SONG)
	if id_type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM]:
		page_body = page_body.get_children().filter(func(node : Node) -> bool: return node.visible)[0].find_child("DataList", false).get_child(0).get_child(2).get_child(0)
		var data_list_data : Dictionary
		match id_type:
			MasterDirectoryManager.use_type.ARTIST:
				data_list_data = MasterDirectoryManager.get_artist_discography_data(id)
				populate_data_list_context_menu(page_body, MasterDirectoryManager.use_type.ALBUM, 
				data_list_data)
			MasterDirectoryManager.use_type.ALBUM:
				data_list_data = MasterDirectoryManager.get_album_tracklist_data(id)
				populate_data_list_context_menu(page_body, MasterDirectoryManager.use_type.SONG, 
				data_list_data)
		page_body.get_parent().get_parent().get_child(0).get_child(0).text = " Items: " + str(len(data_list_data))
	if id_type in [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.SONG]:
		var data : Dictionary = {"image": null, "title": null, "subtitle": null}
		match id_type:
			MasterDirectoryManager.use_type.ALBUM:
				data["image"] = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["artist"])["image_file_path"]))
				data["title"] = MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.album_id_dict[id]["artist"]]["name"]
				data["subtitle"] = MasterDirectoryManager.album_id_dict[id]["artist"]
			MasterDirectoryManager.use_type.SONG:
				data["image"] = ImageTexture.create_from_image(GeneralManager.get_image_from_cache(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["image_file_path"]))
				data["title"] = MasterDirectoryManager.album_id_dict[MasterDirectoryManager.song_id_dict[id]["album"]]["name"]
				data["subtitle"] = MasterDirectoryManager.song_id_dict[id]["album"]
		%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = data["image"]
		%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/Title.text = data["title"]
		%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/Subtitle.text = data["subtitle"]
	#
	%MainContainer/Library/Container/Profile.visible = true
	GeneralManager.set_mouse_busy_state.call(false)
	return OK

func context_action_button_pressed(args : Array) -> void:
	print("context action button pressed args: " + str(args))
	var dataset : Array
	var item : String
	var intermediary : String
	if args[0] in ["0", "1"]:
		if GeneralManager.get_id_type(args[1]) == MasterDirectoryManager.use_type.ARTIST:
			dataset = MasterDirectoryManager.artist_id_dict[args[1]]["albums"]
		else:
			dataset = MasterDirectoryManager.album_id_dict[args[1]]["songs"]
	match args[0]:
		"0":
			if args[3] > 0:
				item = dataset[args[3]-1]
				intermediary = dataset[args[3]]
				dataset[args[3]] = item
				dataset[args[3]-1] = intermediary
				args[2].move_child(args[2].get_child(args[3]-1), args[3])
		"1":
			if args[3] < len(dataset)-1:
				item = dataset[args[3]+1]
				intermediary = dataset[args[3]]
				dataset[args[3]] = item
				dataset[args[3]+1] = intermediary
				args[2].move_child(args[2].get_child(args[3]+1), args[3])
		"2":
			play(args[1])
		"3":
			set_favourite(args[1])
	return

func play(id : String) -> int:
	return %PlayingScreen.load_song_list(id)

func set_favourite(id : String) -> int:
	if GeneralManager.get_id_type(id) != MasterDirectoryManager.use_type.UNKNOWN:
		var data : Dictionary = MasterDirectoryManager.get_object_data.call(id)
		data["favourite"] = !data["favourite"]
		return OK
	return ERR_INVALID_PARAMETER

func delete(id : String, create_confirmation_popup : bool = true) -> void:
	print("delete id is: " + id + ", it starts with: " + id.left(1))
	#print("data before:\nartist: " + str(MasterDirectoryManager.artist_id_dict) + "\n\nalbum: " + str(MasterDirectoryManager.album_id_dict) + "\n\nsong: " + str(MasterDirectoryManager.song_id_dict) + "\n\nplaylist: " + str(MasterDirectoryManager.playlist_id_dict))
	if create_confirmation_popup:
		if await create_popup("Are You Sure You Want To Delete Item With ID:\n" + id) == 1:
			return
	match GeneralManager.get_id_type(id):
		MasterDirectoryManager.use_type.ARTIST:
			for item : String in MasterDirectoryManager.get_object_data.call(id)["albums"]:
				MasterDirectoryManager.get_object_data.call(item)["artist"] = ""
			MasterDirectoryManager.artist_id_dict.erase(id)
		MasterDirectoryManager.use_type.ALBUM:
			#print("\nsong data before album deletion: " + str(MasterDirectoryManager.song_id_dict) + "\n--")
			for item : String in MasterDirectoryManager.get_object_data.call(id)["songs"]:
				MasterDirectoryManager.get_object_data.call(item)["album"] = ""
			#print("\nsong data after album deletion: " + str(MasterDirectoryManager.song_id_dict) + "\n--")
			if MasterDirectoryManager.get_object_data.call(id)["artist"] != "":
				MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["artist"])["albums"].erase(id)
			MasterDirectoryManager.album_id_dict.erase(id)
		MasterDirectoryManager.use_type.SONG:
			if MasterDirectoryManager.get_object_data.call(id)["album"] != "":
				MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["songs"].erase(id)
			MasterDirectoryManager.song_id_dict.erase(id)
		MasterDirectoryManager.use_type.PLAYLIST:
			MasterDirectoryManager.playlist_id_dict.erase(id)
	#print("data after:\nartist: " + str(MasterDirectoryManager.artist_id_dict) + "\n\nalbum: " + str(MasterDirectoryManager.album_id_dict) + "\n\nsong: " + str(MasterDirectoryManager.song_id_dict) + "\n\nplaylist: " + str(MasterDirectoryManager.playlist_id_dict))
	return

func cache_managment_button_pressed(button : String) -> void:
	if await create_popup("Are You Sure You Wish To " + %MainContainer/Profile/Container/Body/Settings/Container/CachePanel/Container/Buttons.get_child(int(button)).button_text + "?") == 1:
		return
	match int(button):
		0:
			GeneralManager.image_cache = {}
			GeneralManager.image_average_cache = {}
			for item : Node in %MainContainer/Library/Container/ScrollContainer/ItemList.get_children():
				item.queue_free()
		1:
			GeneralManager.image_cache = {}
		2:
			GeneralManager.image_average_cache = {}
		3:
			for item : Node in %MainContainer/Library/Container/ScrollContainer/ItemList.get_children():
				item.queue_free()
	return

func keybind_button_pressed(args : Array) -> void:
	active_keybind_switching_data = args
	$Camera/AspectRatioContainer/KeybindScreen.visible = true
	return

func data_managment_button_pressed(button : String) -> void:
	if await create_popup("Are You Sure You Wish To " + %MainContainer/Profile/Container/Body/Data/Container/Panel1/Container/Buttons.get_child(int(button)).button_text + "?") == 1:
		return
	if int(button) < 6:
		var data : PackedStringArray = []
		match int(button):
			0:
				data.append_array(MasterDirectoryManager.playlist_id_dict.keys())
				data.append_array(MasterDirectoryManager.song_id_dict.keys())
				data.append_array(MasterDirectoryManager.album_id_dict.keys())
				data.append_array(MasterDirectoryManager.artist_id_dict.keys())
			1:
				data.append_array(MasterDirectoryManager.artist_id_dict.keys())
			2:
				data.append_array(MasterDirectoryManager.album_id_dict.keys())
			3:
				data.append_array(MasterDirectoryManager.song_id_dict.keys())
			4:
				data.append_array(MasterDirectoryManager.playlist_id_dict.keys())
		for item : String in data:
			delete(item, false)
		if int(button) in [0, 5]:
			MasterDirectoryManager.user_data_dict = MasterDirectoryManager.default_user_data
		return
	MasterDirectoryManager.save_data("NMP_Data_Backup_" + str(Time.get_unix_time_from_system()) + ".dat")
	return

func user_setting_changed(number : String, state : bool) -> int:
	MasterDirectoryManager.user_data_dict[user_setting_keys[int(number)]] = state
	return OK

func player_widget_changed(number : String, state : bool) -> int:
	MasterDirectoryManager.user_data_dict["player_widgets"][int(number)] = state
	playing_screen.call("set_widgets")
	return OK

func set_main_screen_page(page : String) -> void:
	var children : Array[Node] = %MainContainer.get_children()
	for item : Node in children:
		item.set_deferred("visible", children.find(item) == int(page))
	if page == "3":
		populate_library_screen(int(library_page))
	return

func set_new_screen_page(page : String) -> void:
	var children : Array[Node] = %MainContainer/New/Container/Container/Body.get_children()
	for item : Node in children:
		item.set_deferred("visible", children.find(item) == int(page))
	return

func set_profile_screen_page(page : String) -> void:
	var children : Array[Node] = %MainContainer/Profile/Container/Body.get_children()
	for node : Node in children:
		node.set_deferred("visible", children.find(node) == int(page))
	%MainContainer/Profile/Container/Header/TabContainer/Page.text = " " + children[int(page)].name
	return

func set_playlist_screen_page(page : String) -> void:
	var children : Array[Node] = %MainContainer/Playlists/Container/Body.get_children()
	for node : Node in children:
		node.set_deferred("visible", children.find(node) == int(page))
	%MainContainer/Playlists/Container/Header/TabContainer/Page.text = " " + children[int(page)].name
	return

func create_popup_notif(title : String, custom_min_size : Vector2 = Vector2(240, 25)) -> void:
	$Camera/AspectRatioContainer/PopupNotifications.add_child(popup_notif_scene.instantiate())
	$Camera/AspectRatioContainer/PopupNotifications.get_child(-1).update(title, custom_min_size)
	return

func create_popup(title : String, response_1 : String = "Yes", response_2 : String = "No") -> int:
	%PopupContainer/Popup/Container/Title.text = title
	%PopupContainer/Popup/Container/ResponseContainer/Response1.update({"button_text": response_1})
	%PopupContainer/Popup/Container/ResponseContainer/Response2.update({"button_text": response_2})
	%PopupContainer.visible = true
	await self.popup_responded
	return popup_response

func popup_response_pressed(arg : String) -> void:
	popup_response = int(arg)
	self.emit_signal("popup_responded")
	%PopupContainer.visible = false
	return

func _set_soft_loading(state : bool) -> void:
	%SoftLoadingScreen.visible = state
	GeneralManager.set_mouse_busy_state.call(state)
	await get_tree().process_frame
	await get_tree().process_frame
	return

func exit(_arg : String = "0") -> void:
	if await create_popup("Do You Wish To Save Your Data Before Exiting?") == 0:
		print("they said yes")
		MasterDirectoryManager.save_data()
		await get_tree().process_frame
	get_tree().quit(0)
	return
