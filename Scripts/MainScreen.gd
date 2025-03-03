extends Control

const entryitem_scene : PackedScene = preload("res://Scenes/EntryItem.tscn")
const basic_entryitem_scene : PackedScene = preload("res://Scenes/BasicEntryItem.tscn")
const popup_notif_scene : PackedScene = preload("res://Scenes/PopupNotification.tscn")
const list_item_scene : PackedScene = preload("res://Scenes/ListItem.tscn")
const keybind_scene : PackedScene = preload("res://Scenes/KeybindScene.tscn")
const tooltip_scene : PackedScene = preload("res://Scenes/Tooltip.tscn")
@export var playing_screen : Control
@export var cli : PanelContainer
var song_upload_list : Array = []
var popup_response : int = 0
var library_page : int = 0
var library_details_item_id : String
var custom_inputmap_actions : PackedStringArray = InputMap.get_actions().filter(func(item : String) -> bool: return not item.left(3) == "ui_")
var active_keybind_switching_data : Array = []
var new_entry_data : Dictionary
var new_entry_flag : int = 0
var new_page : int = 0
var tutorial_page : int = 0:
	set(value):
		tutorial_page = value
		%NewUserScreen/Background/Container/PageButtons/PreviousPage.disabled = tutorial_page == 0
		%NewUserScreen/Background/Container/PageButtons/NextPage.disabled = tutorial_page == len(tutorial_pages_text)-1
		%NewUserScreen/Background/Container/PageButtons/PageNumber.text = "Page " + str(tutorial_page + 1) + "/" + str(len(tutorial_pages_text))
		%NewUserScreen/Background/Container/BodyText.text = "[center]\n" + tutorial_pages_text[tutorial_page] + "\n[/center]"
		return
	get:
		return tutorial_page
signal popup_responded
const user_setting_keys : PackedStringArray = ["save_on_quit", "continue_playing", "continue_playing_exact"]
const tutorial_pages_text : PackedStringArray = [
	"[img]res://Assets/NMP_Icon.png[/img]\n\nThis is a short guide on how to use the app, if you would like to\nskip this, simply hit the Close button below.\n\nOtherwise, please use the Previous/Next Page buttons respectively to navigate.", 
	"[img]res://Assets/Tutorial Images/Image_1.png[/img]\n\nIn the top right of the screen you can see buttons for every page of the app, left to right these are:\nHome, New, Library and Profile, with the last button being an exit button.", 
	"[img]res://Assets/Tutorial Images/Image_1.png[/img]\n\nThe Home page is where you can get random recommendations for Artists, Albums, Songs and Playlists to listen to.\nThis will change depending on the day you open the programme.", 
	"[img]res://Assets/Tutorial Images/Image_2.png[/img]\n\nThe New page is where you will upload all of your songs, and create your artists/albums to put them in.\nThis is also where you can make new Playlists.", 
	"[img]res://Assets/Tutorial Images/Image_3.png[/img]\n\nThe Library page is where all of your Artists, Albums, Songs and Playlists are stored.\nThis is where you can manage them, and also Play them by hitting the Play button on every item.", 
	"[img]res://Assets/Tutorial Images/Image_4.png[/img]\n\nThe Profile page has many things, including Data Managment, Settings and Keybind Managment.\nFor more information see the Profile page.", 
	"[img=320x180]res://Assets/Tutorial Images/Image_5.png[/img]\n\nThis is the Player / Playing screen, seen in the bottom right of the screen.\n\nWhen playing a song it will appear here.\nYou can customize this screen using Widgets, which can be set inside the Profile page under Settings.", 
	"[img=175x175]res://Assets/Tutorial Images/Image_6.png[/img]\n\nThe app also features a built-in CLI, or Command Line Interface\nwhich can be oppened using Ctrl+O or in the respective Profile page.\n\nThe CLI can be used for more granular control of the app and its data\nfor more help using it, open it and run 'help'.", 
	"[img]res://Assets/NMP_Icon.png[/img]\n\nThat is all you need to know to get started using the NMP\n(Nat Music Programme)!\n\nNow you can get started by going to the New page and uploading your first songs!\nIf you have any feedback or suggestions or want to get the latest version; go to the [url=" + GeneralManager.repo_url + "][i]Project's Github[/i][/url]."
	]

func _ready() -> void:
	%LoadingScreen.visible = true
	GeneralManager.set_mouse_busy_state.call(true)
	await get_tree().process_frame
	#
	GeneralManager.rng_seed = int(float(Time.get_datetime_string_from_system().hash() * Time.get_date_string_from_system().hash()) / float(OS.get_name().hash()))
	playing_screen = %PlayingScreen
	cli = %CommandLineInterface
	MasterDirectoryManager.load_data()
	OS.set_restart_on_exit(false)
	await get_tree().process_frame
	if MasterDirectoryManager.finished_loading_data == false:
		await MasterDirectoryManager.finished_loading_data_signal
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ClearBtn.texture_normal = GeneralManager.get_icon_texture("Delete")
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ClearBtn.pressed.connect(Callable(self, "create_button_pressed").bind("3"))
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/SelectBtn.texture_normal = GeneralManager.get_icon_texture("Upload")
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/SelectBtn.pressed.connect(Callable(self, "create_button_pressed").bind("4"))
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/CloseBtn.texture_normal = GeneralManager.get_icon_texture("Close")
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/CloseBtn.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile.visible = false; %MainContainer/Library/Container/ScrollContainer.visible = true; return)
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.texture_normal = GeneralManager.get_icon_texture("Refresh")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.pressed.connect(func() -> void: open_context_menu(library_details_item_id); return)
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ClearBtn.texture_normal = GeneralManager.get_icon_texture("Delete")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ClearBtn.pressed.connect(Callable(self, "profile_clear_pressed"))
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.texture_normal = GeneralManager.get_icon_texture("Upload")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible == true: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM][library_page - 1], "profile_selector_selected", self); return)
	%MainContainer/Library/Container/Profile/Container/Container/Body/Playlist/DataList/Container/InfoContainer/AddArtistButton.texture_normal = GeneralManager.get_icon_texture("ArtistList")
	%MainContainer/Library/Container/Profile/Container/Container/Body/Playlist/DataList/Container/InfoContainer/AddArtistButton.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible == true: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.ARTIST, "playlist_profile_upload_button_pressed", self); return)
	%MainContainer/Library/Container/Profile/Container/Container/Body/Playlist/DataList/Container/InfoContainer/AddAlbumButton.texture_normal = GeneralManager.get_icon_texture("Album")
	%MainContainer/Library/Container/Profile/Container/Container/Body/Playlist/DataList/Container/InfoContainer/AddAlbumButton.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible == true: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.ALBUM, "playlist_profile_upload_button_pressed", self); return)
	%MainContainer/Library/Container/Profile/Container/Container/Body/Playlist/DataList/Container/InfoContainer/AddSongButton.texture_normal = GeneralManager.get_icon_texture("Songs")
	%MainContainer/Library/Container/Profile/Container/Container/Body/Playlist/DataList/Container/InfoContainer/AddSongButton.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible == true: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.SONG, "playlist_profile_upload_button_pressed", self); return)
	%NewUserScreen/Background/Container/PageButtons/PreviousPage.pressed.connect(func() -> void: tutorial_page -= 1; return)
	%NewUserScreen/Background/Container/PageButtons/NextPage.pressed.connect(func() -> void: tutorial_page += 1; return)
	%NewUserScreen/Background/Container/PageButtons/Close.pressed.connect(func() -> void: %NewUserScreen.visible = false; return)
	set_main_screen_page("0")
	set_create_screen_page("0")
	populate_library_screen(0)
	set_profile_screen_page("0")
	tutorial_page = 0
	%Hatbar/Container/BuildType.text = GeneralManager.build + " Build."
	%Hatbar/Container/Version.text = GeneralManager.version
	for item : String in user_setting_keys:
		%MainContainer/Profile/Container/Body/Settings/Container/SettingsPanel/Container/Buttons.get_child(user_setting_keys.find(item)).update({"pressed": MasterDirectoryManager.user_data_dict[item]})
	for i : int in range(0, len(MasterDirectoryManager.user_data_dict["player_widgets"])):
		%MainContainer/Profile/Container/Body/Settings/Container/WidgetPanel/Container/Buttons.get_child(i).update({"pressed": MasterDirectoryManager.user_data_dict["player_widgets"][i]})
	if not MasterDirectoryManager.finished_loading_keybinds:
		await MasterDirectoryManager.finished_loading_keybinds_signal
	update_keybinds_screen()
	DisplayServer.window_set_current_screen(wrapi(MasterDirectoryManager.user_data_dict["window_screen"], 0, DisplayServer.get_screen_count()))
	DisplayServer.window_set_size(MasterDirectoryManager.user_data_dict["window_size"])
	get_tree().get_root().set("position", MasterDirectoryManager.user_data_dict["window_position"])
	DisplayServer.window_set_mode(MasterDirectoryManager.user_data_dict["window_mode"])
	%PlayingScreen.fullscreen = MasterDirectoryManager.user_data_dict["player_fullscreen"]
	%NewUserScreen.visible = MasterDirectoryManager.new_user
	#
	await get_tree().process_frame
	await create_tween().tween_property(%LoadingScreen, "modulate", Color(1, 1, 1, 0), 0.25).from(Color(1, 1, 1, 1)).finished
	%LoadingScreen.visible = false
	GeneralManager.set_mouse_busy_state.call(false)
	GeneralManager.cli_print_callable.call("SYS: Programme Initialization Complete")
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
		if Input.is_action_just_pressed("ToggleFullscreen", true):
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
				MasterDirectoryManager.user_data_dict["window_mode"] = DisplayServer.window_get_mode()
			elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and MasterDirectoryManager.user_data_dict["window_mode"] == DisplayServer.WINDOW_MODE_FULLSCREEN:
				MasterDirectoryManager.user_data_dict["window_mode"] = DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_FULLSCREEN, MasterDirectoryManager.user_data_dict["window_mode"]][int(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)])
		elif Input.is_action_just_pressed("Save", true):
			MasterDirectoryManager.save_data()
		elif Input.is_action_just_pressed("QuitAndSave", true):
			MasterDirectoryManager.save_data()
			await get_tree().process_frame
			if MasterDirectoryManager.finished_saving_data == false:
				await MasterDirectoryManager.finished_saving_data_signal
			get_tree().quit()
		elif Input.is_action_just_pressed("QuitWithoutSaving", true):
			get_tree().quit()
		elif Input.is_action_just_pressed("HardReloadApp", true):
			OS.set_restart_on_exit(true)
			get_tree().quit()
		elif Input.is_action_just_pressed("ToggleCLI", true) and $Camera.enabled == true:
			%CommandLineInterface.active = !%CommandLineInterface.active
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

func profile_selector_selected(id : String) -> void:
	print("soy happened with an id of " + id + ", with a library details id of " + library_details_item_id + ", to change key of " + ["album", "artist"][int(GeneralManager.get_id_type(library_details_item_id) == MasterDirectoryManager.use_type.ALBUM)])
	library_details_info_altered(id, ["album", "artist"][int(GeneralManager.get_id_type(library_details_item_id) == MasterDirectoryManager.use_type.ALBUM)])
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.emit_signal("pressed")
	%MainContainer/Library/Container/Profile/SelectList.visible = false
	return

func populate_data_list(location : Node, type : MasterDirectoryManager.use_type, pressed_name : String = "entryitem_pressed", pressed_sender : Node = self) -> void:
	await _set_soft_loading(true)
	#
	var data : Dictionary = MasterDirectoryManager.get(str(MasterDirectoryManager.use_type.keys()[type]).to_lower() + "_id_dict")
	var keys : PackedStringArray = (func() -> Array: var arr : Array = data.keys(); arr.sort_custom((func(x : String, y : String) -> bool: return data[x]["name"] < data[y]["name"])); return arr).call()
	var get_image : Callable = (func(path : String) -> ImageTexture: var image : Image = GeneralManager.get_image(path); var texture : ImageTexture = ImageTexture.create_from_image(image); texture.resource_name = image.resource_name; return texture)
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

func populate_data_list_context_menu(location : Node, type : MasterDirectoryManager.use_type, data : Dictionary, pressed_sender : Node = self, action_button_signal_names : PackedStringArray = ["context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed"]) -> void:
	print("\n\ndata received in populate data list context menu: " + str(data) + "\n\n")
	await _set_soft_loading(true)
	#
	var keys : PackedStringArray = data.keys()
	var get_image : Callable = (func(path : String) -> ImageTexture: var image : Image = GeneralManager.get_image(path); var texture : ImageTexture = ImageTexture.create_from_image(image); texture.resource_name = image.resource_name; return texture)
	while len(location.get_children()) < len(keys):
		location.add_child(list_item_scene.instantiate())
	for item : Node in location.get_children():
		item.visible = location.get_children().find(item) < len(keys)
		if item.visible == true:
			var key : String = keys[location.get_children().find(item)]
			var parent_id : String
			if GeneralManager.get_id_type(library_details_item_id) != MasterDirectoryManager.use_type.PLAYLIST and type in [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.SONG]:
				parent_id = data[key][MasterDirectoryManager.use_type.find_key(int(key.left(1))-1).to_lower()]
			else:
				parent_id = library_details_item_id
			var to_update : Dictionary = {"title": data[key]["name"], "subtitle": key, "copy_subtitle_text": (" ID '[u]" + key + "[/u]' Was Copied To Clipboard. "), "image": GeneralManager.get_icon_texture("Missing"), "action_button_sender": pressed_sender, "action_buttons": 5, "action_button_images": ["Up", "Down", "Play", ["Favourite", "Favourited"][int(data[key]["favourite"])], "ListRemove"], "action_button_signal_names": action_button_signal_names, "action_button_arguments": [["0", parent_id, location], ["1", parent_id, location], ["2", key], ["3", key], ["4", parent_id, location, key]]}
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
		create_popup_notif(" " + ["Unable To Validate File", "Unable To Validate Directory"][int(style)] + ", Please Try Again With A Different Path. ")
		return
	if style == "0":
		print("adding one file")
		song_upload_list.append({"name": selected.get_file().get_basename(), "path": selected})
	elif style == "1":
		print("adding directory")
		for item : String in (func() -> Array: var dir : DirAccess = DirAccess.open(selected); print("Dir Access Status: " + str(DirAccess.get_open_error())); return Array(dir.get_files()).filter(func(file : String) -> bool: return file.get_extension() in ["mp3", "ogg"])).call():
			print("adding into song upload list: " + str({"name": item.get_basename(), "path": selected + "\\"[0] + item}))
			song_upload_list.append({"name": item.get_basename(), "path": selected + "\\"[0] + item})
		print("Dir Acess Err: " + str(DirAccess.get_open_error()))
	populate_song_list(song_upload_list, %MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container)
	return

func populate_library_screen(page : int) -> void:
	print("\n- populate library start with a page of " + str(page))
	await _set_soft_loading(true)
	#
	library_page = page
	%MainContainer/Library/Container/Profile.visible = false
	%MainContainer/Library/Container/ScrollContainer.visible = true
	%MainContainer/Library/Container/Header/TabContainer/Page.text = " " + str(MasterDirectoryManager.get_data_types.call().map(func(item : String) -> String: return item.capitalize())[page])
	var location : VBoxContainer = %MainContainer/Library/Container/ScrollContainer/ItemList
	var data : Dictionary = MasterDirectoryManager.get(MasterDirectoryManager.get_data_types.call()[page] + "_id_dict")
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
			print("data id: " + data_id + ", data: " + str(data[data_id]))
			var to_update : Dictionary = {"title": data[data_id]["name"], "subtitle": data_id, "copy_subtitle_text": (" ID '[u]" + data_id + "[/u]' Was Copied To Clipboard. "), "image": "", "action_button_sender": self, "action_buttons": 4, "action_button_images": ["Elipses", "Play", ["Favourite", "Favourited"][int(data[data_id]["favourite"])], "Delete"], "action_button_signal_names": ["open_context_menu", "play", "set_favourite", "delete"], "action_button_arguments": [data_id, data_id, data_id, data_id]}
			if library_page == 2:
				if data[data_id]["album"] != "" and data[data_id]["album"] in MasterDirectoryManager.album_id_dict.keys():
					to_update["image"] = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.album_id_dict[data[data_id]["album"]]["image_file_path"]))
				else:
					to_update["image"] = GeneralManager.get_icon_texture("Missing")
			else:
				to_update["image"] = ImageTexture.create_from_image(GeneralManager.get_image(data[data_id]["image_file_path"]))
			node.update(to_update)
	#
	await _set_soft_loading(false)
	return

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
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container.get_child(int(index)).queue_free()
	populate_song_list(song_upload_list, %MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container)
	return

func update_song_upload_list_data(data : Array[Variant] = ["new_value", 0], to_change : String = "name") -> void:
	#print("song upload list before: " + str(song_upload_list).replace(" }, ", " }\n") + "\ndata: " + str(data))
	song_upload_list[data[1]][to_change] = data[0]
	populate_song_list(song_upload_list, %MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container)
	#print("song upload list after: " + str(song_upload_list).replace(" }, ", " }\n"))
	return

func populate_song_list(data : Array, location : Node, subtitle_type : int = 0) -> void:
	print("\nsong list at population:\n" + str(data).replace(" }, ", " }\n"))
	#var location : Node = %MainContainer/New/Container/Container/Body/Song/Container/InfoPanel/Container/SelectPanel/GreaterContainer/ScrollContainer/Container
	#var location : Node = %MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container
	while len(location.get_children()) < len(data):
		location.add_child(basic_entryitem_scene.instantiate())
	for node : Node in location.get_children():
		node.visible = location.get_children().find(node) < len(data)
		if node.visible:
			var item : Dictionary = data[location.get_children().find(node)]
			#print("data to set in song list population: " + str({"title": item["name"], "subtitle": item["path"], "button_icon_name": "Delete", "pressed_signal_sender": self, "pressed_signal_name": "remove_from_song_upload_list", "pressed_signal_argument": str(song_upload_list.find(item))}))
			#                                     {"title": item["name"], "subtitle": item["path"], "id": str(data.find(item)), "editable_title": true, "signal_sender": self, "button_icon_name": "Delete", "pressed_signal_name": "remove_from_song_upload_list", "title_changed_signal_name": "change_song_upload_list_data"}
			node.call("update", {"title": item["name"], "subtitle": item.get(["path", "id"][subtitle_type]), "id": str(data.find(item)), "editable_title": true, "signal_sender": self, "button_icon_name": "Delete", "pressed_signal_name": "remove_from_song_upload_list", "title_changed_signal_name": "update_song_upload_list_data"})
			#await get_tree().process_frame
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/ItemQuantity.text = " Items: " + str(len(data)) + " "
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
		%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["image_file_path"]))
	else:
		%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(id)["image_file_path"]))
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Title.update({"editing_mode": true, "text": MasterDirectoryManager.get_object_data.call(id)["name"]})
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Title.update({"editing_mode": false})
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Subtitle.text = id
	%MainContainer/Library/Container/Profile/Container/Container/Body.get_children().map(func(node : Node) -> Node: node.visible = node.name.to_lower() == MasterDirectoryManager.get_data_types.call()[GeneralManager.get_id_type(id)]; return)
	var page_body : Node = %MainContainer/Library/Container/Profile/Container/Container/Body
	var page_parent : Node = %MainContainer/Library/Container/Profile/Container/Container/ParentContainer
	page_parent.visible = id_type in [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.SONG]
	page_body.visible = !(id_type == MasterDirectoryManager.use_type.SONG)
	if id_type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST]:
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
			MasterDirectoryManager.use_type.PLAYLIST:
				data_list_data = MasterDirectoryManager.get_playlist_songs_data(id)
				populate_data_list_context_menu(page_body, MasterDirectoryManager.use_type.SONG, data_list_data)
		GeneralManager.navigate_node(page_body, "˄,˄,0,0").text = " Items: " + str(len(data_list_data))
	if id_type in [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.SONG]:
		var data : Dictionary = {"image": null, "title": null, "subtitle": null}
		match id_type:
			MasterDirectoryManager.use_type.ALBUM:
				data["image"] = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["artist"])["image_file_path"]))
				data["title"] = MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.album_id_dict[id]["artist"]]["name"]
				data["subtitle"] = MasterDirectoryManager.album_id_dict[id]["artist"]
			MasterDirectoryManager.use_type.SONG:
				data["image"] = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["image_file_path"]))
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
	if args[0] in ["0", "1", "4"]:
		match GeneralManager.get_id_type(args[1]):
			MasterDirectoryManager.use_type.ARTIST:
				dataset = MasterDirectoryManager.artist_id_dict[args[1]]["albums"]
			MasterDirectoryManager.use_type.ALBUM:
				dataset = MasterDirectoryManager.album_id_dict[args[1]]["songs"]
			MasterDirectoryManager.use_type.PLAYLIST:
				dataset = MasterDirectoryManager.playlist_id_dict[args[1]]["songs"]
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
		"4":
			dataset.erase(args[3])
			args[2].remove_child(args[2].get_child(args[4]))
	return

func playlist_profile_upload_button_pressed(key : String) -> void:
	match GeneralManager.get_id_type(key):
		MasterDirectoryManager.use_type.ARTIST:
			for album : String in MasterDirectoryManager.artist_id_dict[key]["albums"]:
				MasterDirectoryManager.playlist_id_dict[library_details_item_id]["songs"].append_array(MasterDirectoryManager.album_id_dict[album]["songs"])
		MasterDirectoryManager.use_type.ALBUM:
			MasterDirectoryManager.playlist_id_dict[library_details_item_id]["songs"].append_array(MasterDirectoryManager.album_id_dict[key]["songs"])
		MasterDirectoryManager.use_type.SONG:
			MasterDirectoryManager.playlist_id_dict[library_details_item_id]["songs"].append(key)
	open_context_menu(library_details_item_id)
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
			playing_screen.song_cache = {}
		1:
			GeneralManager.image_cache = {}
		2:
			GeneralManager.image_average_cache = {}
		3:
			for item : Node in %MainContainer/Library/Container/ScrollContainer/ItemList.get_children():
				item.queue_free()
		4:
			playing_screen.song_cache = {}
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

func create_select_pressed(key : String) -> void:
	print("key pressed in create select: " + key)
	if new_page in [0, 1]:
		new_entry_data[["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)]] = key
		%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get(["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)] + "_id_dict")[new_entry_data[["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)]]]["image_file_path"]))
		%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Title.text = MasterDirectoryManager.get(["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)] + "_id_dict")[new_entry_data[["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)]]]["name"]
		%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Subtitle.text = new_entry_data[["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)]]
	elif new_page == 2:
		new_entry_data["album"] = key
		%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.album_id_dict[key]["image_file_path"]))
		%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Title.text = MasterDirectoryManager.album_id_dict[key]["name"]
		%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Subtitle.text = key
	elif new_page == 3:
		match GeneralManager.get_id_type(key):
			MasterDirectoryManager.use_type.ARTIST:
				for item : Array in MasterDirectoryManager.get_artist_discography_data(key).keys().map(func(item : String) -> Array: return MasterDirectoryManager.get_album_tracklist_data(item).keys()):
					new_entry_data["songs"].append_array(item)
			MasterDirectoryManager.use_type.ALBUM:
				new_entry_data["songs"].append_array(MasterDirectoryManager.get_album_tracklist_data(key).keys())
			MasterDirectoryManager.use_type.SONG:
				new_entry_data["songs"].append(key)
		populate_song_list(
			new_entry_data["songs"].map(func(item : String) -> Dictionary: var data : Dictionary = GeneralManager.get_data(item); data["id"] = item; return data), 
			%MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container, 
			1)
	%MainContainer/New/Container/Body/SelectList.visible = false
	return

func create_button_pressed(button : String, arg : String = "") -> void:
	if int(arg) in range(0, 9) and button.is_valid_int() == false:
		var intermediary : String = button
		button = arg
		arg = intermediary
	print("button pressed during create: " + button)
	match button:
		"0":
			%SelectImageDialog.visible = true
			new_entry_data["image_file_path"] = %SelectImageDialog.current_file
			%MainContainer/New/Container/Body/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(new_entry_data["image_file_path"]))
		"1":
			new_entry_data["name"] = arg
		"2":
			var id : String = MasterDirectoryManager.generate_id(new_page)
			if new_page == 2:
				var data : Dictionary
				for item : Dictionary in song_upload_list:
					id = MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.SONG)
					data = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.SONG)
					data["name"] = item["name"]; data["album"] = new_entry_data["album"]
					data["song_file_path"] = item["path"]
					MasterDirectoryManager.song_id_dict[id] = data
					if new_entry_data["album"] != "":
						MasterDirectoryManager.album_id_dict[new_entry_data["album"]]["songs"].append(id)
				create_popup_notif(" Uploaded [u]" + str(len(song_upload_list)) + "[/u] New Song" + ["", "s"][int(len(song_upload_list) > 1)] + [" To The Album [u]" + new_entry_data["album"] + ".[/i] ", ". "][int(new_entry_data["album"] == "")])
			else:
				MasterDirectoryManager.get(MasterDirectoryManager.get_data_types.call()[new_page] + "_id_dict")[id] = new_entry_data
				if new_page == 1 and new_entry_data["artist"] != "":
					MasterDirectoryManager.artist_id_dict[new_entry_data["artist"]]["albums"].append(id)
				create_popup_notif(" Made A New " + MasterDirectoryManager.get_data_types.call()[new_page].capitalize() + " With The ID [u]" + id + "[/u]. ")
			set_create_screen_page(str(new_page))
		"3":
			%MainContainer/New/Container/Body/SelectList.visible = false
			new_entry_data[["album", "artist"][int(%MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible)]] = ""
			%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = GeneralManager.get_icon_texture()
			%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Title.text = "Title"
			%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Subtitle.text = "Subtitle"
		"4":
			var header_visible : bool = %MainContainer/New/Container/Body/Container/Container/HeaderContainer.visible
			%MainContainer/New/Container/Body/SelectList.visible = !%MainContainer/New/Container/Body/SelectList.visible
			if %MainContainer/New/Container/Body/SelectList.visible:
				new_entry_flag = 0
				populate_data_list(%MainContainer/New/Container/Body/SelectList/ScrollContainer/Container, [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.ARTIST][int(header_visible)], "create_select_pressed", self)
			elif not new_entry_data[["album", "artist"][int(header_visible)]] in ["", "Unknown"]:
				%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get(["album", "artist"][int(header_visible)] + "_id_dict")[new_entry_data[["album", "artist"][int(header_visible)]]]["image_file_path"]))
				%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Title.text = MasterDirectoryManager.get(["album", "artist"][int(header_visible)] + "_id_dict")[new_entry_data[["album", "artist"][int(header_visible)]]]["name"]
				%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Subtitle.text = new_entry_data[["album", "artist"][int(header_visible)]]
		"5", "6", "7":
			%MainContainer/New/Container/Body/SelectList.visible = !%MainContainer/New/Container/Body/SelectList.visible
			if %MainContainer/New/Container/Body/SelectList.visible:
				new_entry_flag = int(button)-4
				populate_data_list(%MainContainer/New/Container/Body/SelectList/ScrollContainer/Container, int(button)-5, "create_select_pressed", self)
		"8", "9":
			set_song_upload_style(str(int(button)-8))
	return

func set_main_screen_page(page : String) -> void:
	var children : Array[Node] = %MainContainer.get_children()
	children.map(func(node : Node) -> Node: node.visible = children.find(node) == int(page); return node)
	#for item : Node in children:
	#	item.set("visible", children.find(item) == int(page))
	if page == "3":
		populate_library_screen(int(library_page))
	return

func set_create_screen_page(page : String) -> void:
	%MainContainer/New/Container/Header/TabContainer/Page.text = " " + MasterDirectoryManager.get_data_types.call()[int(page)].capitalize()
	new_page = int(page)
	new_entry_data = MasterDirectoryManager.get_data_template(new_page)
	song_upload_list = []
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/ItemQuantity.text = " Items: 0 "
	%MainContainer/New/Container/Body/Container/Container/HeaderContainer/ImageContainer/Image.texture = GeneralManager.get_icon_texture()
	%MainContainer/New/Container/Body/Container/Container/HeaderContainer/Container/Title.update({"text": "Placeholder", "editing_mode": false})
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = GeneralManager.get_icon_texture()
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Title.text = "Title"
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/Subtitle.text = "Subtitle"
	var children : Array[Node] = %MainContainer/New/Container/Body/Container/Container.get_children()
	children.pop_front()
	children[0].visible = (new_page in [0, 1, 3])
	children[1].visible = (new_page in [1, 2])
	children[2].visible = (new_page in [2, 3])
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/UploadDirectoryButton.visible = new_page == 2
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/UploadSongButton.visible = new_page == 2
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/Void5.visible = new_page == 2
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/Void6.visible = new_page == 2
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer.get_children().filter(func(node : Node) -> bool: return (node.get_index() in range(3, 9))).map(func(node : Node) -> Node: node.visible = !%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/UploadSongButton.visible; return node)
	GeneralManager.navigate_node(children[2], "0,0,1").visible = not (children[2].visible == true and children[1].visible == false)
	return

func set_profile_screen_page(page : String) -> void:
	var children : Array[Node] = %MainContainer/Profile/Container/Body.get_children()
	children.map(func(node : Node) -> Node: node.visible = children.find(node) == int(page); return node)
	#for node : Node in children:
	#	node.set("visible", children.find(node) == int(page))
	%MainContainer/Profile/Container/Header/TabContainer/Page.text = " " + children[int(page)].name
	return

func create_popup_notif(title : String, custom_min_size : Vector2 = Vector2(240, 25)) -> void:
	if $Camera.enabled:
		$Camera/AspectRatioContainer/PopupNotifications.add_child(popup_notif_scene.instantiate())
		$Camera/AspectRatioContainer/PopupNotifications.get_child(-1).update(title, custom_min_size)
	return

func create_tooltip(text : String, text_size : int = 16) -> void:
	if $Camera.enabled:
		$Camera/AspectRatioContainer/TooltipContainer.add_child(tooltip_scene.instantiate())
		$Camera/AspectRatioContainer/TooltipContainer.get_child(-1).set("text_size", text_size)
		$Camera/AspectRatioContainer/TooltipContainer.get_child(-1).set("text", text)
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

func toggle_cli(_arg : String) -> void:
	cli.active = !cli.active
	return

func open_tutorial() -> void:
	tutorial_page = 0
	%NewUserScreen.visible = true
	return

func _set_soft_loading(state : bool) -> void:
	%SoftLoadingScreen.visible = state
	await get_tree().process_frame
	await get_tree().process_frame
	return

func exit(_arg : String = "0") -> void:
	if await create_popup("Do You Wish To Save Your Data Before Exiting?") == 0:
		MasterDirectoryManager.save_data()
		await get_tree().process_frame
		if MasterDirectoryManager.finished_saving_data == false:
			await MasterDirectoryManager.finished_saving_data_signal
	get_tree().quit(0)
	return
