extends Control

const entryitem_scene : PackedScene = preload("res://Scenes/EntryItem.tscn")
const basic_entryitem_scene : PackedScene = preload("res://Scenes/BasicEntryItem.tscn")
const popup_notif_scene : PackedScene = preload("res://Scenes/PopupNotification.tscn")
const list_item_scene : PackedScene = preload("res://Scenes/ListItem.tscn")
const tooltip_scene : PackedScene = preload("res://Scenes/Tooltip.tscn")
const home_page_bar_scene : PackedScene = preload("res://Scenes/HomePageBar.tscn")
const home_page_footer : PackedScene = preload("res://Scenes/HomePageFooter.tscn")
const custom_button : PackedScene = preload("res://Scenes/CustomButton.tscn")
const alert : PackedScene = preload("res://Scenes/Alert.tscn")
@export var playing_screen : Control
@export var cli : PanelContainer
@export var show_saving_indicator : bool = false:
	set(value):
		show_saving_indicator = value
		$Camera/AspectRatioContainer/SaveIndicator.visible = value
		while show_saving_indicator:
			await create_tween().tween_property($Camera/AspectRatioContainer/SaveIndicator/Indicator, "modulate:a", 0.5, 0.5).from(0.75).finished
			await create_tween().tween_property($Camera/AspectRatioContainer/SaveIndicator/Indicator, "modulate:a", 0.75, 0.5).from(0.5).finished
var song_upload_list : Array[Dictionary] = []
var popup_response : int = 0
var library_page : int = 0
var library_details_item_id : String
var custom_inputmap_actions : PackedStringArray = InputMap.get_actions().filter(func(item : String) -> bool: return not item.left(3) == "ui_")
var active_keybind_switching_data : Array = []
var new_entry_data : Dictionary
var new_entry_flag : int = 0
var new_page : int = 0
var primary_initialization_finished : bool = false
var tutorial_page : int = 0:
	set(value):
		tutorial_page = value
		%NewUserScreen/Background/Container/PageButtons/PreviousPage.disabled = tutorial_page == 0
		%NewUserScreen/Background/Container/PageButtons/NextPage.disabled = tutorial_page == len(tutorial_pages_text)-1
		%NewUserScreen/Background/Container/PageButtons/PageNumber.text = " Page " + str(tutorial_page + 1) + "/" + str(len(tutorial_pages_text))
		var anim_tween : Tween = create_tween()
		anim_tween.tween_property(%NewUserScreen/Background/Container/BodyText, "modulate:a", 0, 0.1).from(1)
		await anim_tween.finished
		%NewUserScreen/Background/Container/BodyText.text = "[center]\n" + tutorial_pages_text[tutorial_page] + "\n[/center]"
		anim_tween = create_tween()
		anim_tween.tween_property(%NewUserScreen/Background/Container/BodyText, "modulate:a", 1, 0.1).from(0)
		return
signal popup_responded
signal primary_initialization_finished_signal
const user_setting_keys : PackedStringArray = ["save_on_quit", "continue_playing", "continue_playing_exact", "generate_home_screen", "autocomplete", "cli_style"]
const accessibility_setting_keys : PackedStringArray = ["library_size_modifier", "cli_size_modifier", "profile_size_modifier", "separate_cli_outputs"]
const network_setting_keys : PackedStringArray = ["allow_network_requests", "check_latest_version_on_startup"]
const tutorial_pages_text : PackedStringArray = [
	"[img]res://Assets/NMP_Icon.png[/img]\n\nThis is a short guide on how to use the app, if you would like to\nskip this, simply hit the Close button below.\n\nOtherwise, please use the Previous / Next Page buttons respectively to navigate.", 
	"[img]res://Assets/Tutorial Images/Image_1.png[/img]\n\nIn the top right of the screen you can see buttons for every page of the app, left to right these are:\nHome, New, Library and Profile, the last button is the close button.", 
	"[img]res://Assets/Tutorial Images/Image_1.png[/img]\n\nThe Home page is where you can get random recommendations for Artists, Albums, Songs and Playlists to listen to.\nThis will change daily and is persistant across sessions in the same day.", 
	"[img]res://Assets/Tutorial Images/Image_2.png[/img]\n\nThe New page is where you will upload all of your songs, and create your Artists / Albums to put them in.\nThis is also where you can make new Playlists.", 
	"[img]res://Assets/Tutorial Images/Image_3.png[/img]\n\nThe Library page is where all of your Artists, Albums, Songs and Playlists are stored.\nThis is where you can manage and search through them, and also play them by hitting the Play button on every item.", 
	"[img]res://Assets/Tutorial Images/Image_4.png[/img]\n\nThe Profile page has many things, including Data Managment, Settings, Accessability and Keybind Managment.\nFor more information see the Profile page.", 
	"[img=320x180]res://Assets/Tutorial Images/Image_5.png[/img]\n\nThis is the Player / Playing screen, seen in the bottom right of the screen.\n\nWhen playing a song it will appear here.\nYou can customize this screen using Widgets, which can be set inside the Profile page under Settings.", 
	"[img=175x175]res://Assets/Tutorial Images/Image_6.png[/img]\n\nThe app also features a built-in CLI, or Command Line Interface\nwhich can be oppened using Ctrl+O or in the respective Profile page.\n\nThe CLI can be used for more granular control of the app and its data\nfor more help using it, open it and run 'help'.", 
	"[img]res://Assets/NMP_Icon.png[/img]\n\nThat is all you need to know to get started using the NMP\n(Nat Music Programme)!\n\nNow you can get started by going to the New page and uploading your first songs!\nIf you have any feedback or suggestions or want to get the latest version; go to the [url=https://github.com/NatZombieGames/Nat-Music-Programme][i]Project's Github[/i][/url]\nAlso consider joining the [url=https://discord.gg/wcZGjeXPNK][i]Official NatZombieGames Discord[/i][/url] for help and discussion with other users!"
	]
const rich_text_font_size_types : PackedStringArray = ["bold_italics", "italics", "mono", "normal", "bold"]

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
	if not GeneralManager.finished_loading_icons:
		await GeneralManager.finished_loading_icons_signal
	%LoadingScreen/Container/LoadingBar.texture = GeneralManager.load_svg_to_img("res://Assets/Icons/LoadingBar.svg", 2.0)
	%SoftLoadingScreen/ShadedArea/Container/LoadingBar.texture = GeneralManager.load_svg_to_img("res://Assets/Icons/LoadingBar.svg", 2.0)
	$Camera/AspectRatioContainer/SaveIndicator/Indicator.texture = GeneralManager.load_svg_to_img("res://Assets/Icons/Saving.svg", 2.0)
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ClearBtn.texture_normal = GeneralManager.get_icon_texture("Delete")
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/ClearBtn.pressed.connect(Callable(self, "create_button_pressed").bind("3"))
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/SelectBtn.texture_normal = GeneralManager.get_icon_texture("Upload")
	%MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/SelectBtn.pressed.connect(Callable(self, "create_button_pressed").bind("4"))
	%MainContainer/Library/Container/Header/TabContainer/Searchbox.text_submitted.connect(Callable(self, "search_library"))
	%MainContainer/Library/Container/Header/TabContainer/SearchButton.pressed.connect(func() -> void: search_library(%MainContainer/Library/Container/Header/TabContainer/Searchbox.text); return)
	%MainContainer/Library/Container/Header/TabContainer/FilterListButton.toggled.connect(
		func(state : bool) -> void: 
			if state:
				%MainContainer/Library/FiltersPage.position = Vector2i(%MainContainer/Library/Container/Header/TabContainer/FilterListButton.position.x + 115, %MainContainer/Library/Container/Header/TabContainer/FilterListButton.position.y + 10)
				%MainContainer/Library/FiltersPage/Container/Row1.modulate = [Color.GRAY, Color.WHITE][int(library_page in [1, 2])]
				%MainContainer/Library/FiltersPage/Container/Row1/Button.mouse_default_cursor_shape = [CursorShape.CURSOR_FORBIDDEN, CursorShape.CURSOR_POINTING_HAND][int(library_page in [1, 2])]
				%MainContainer/Library/FiltersPage/Container/Row2.modulate = [Color.GRAY, Color.WHITE][int(library_page in [2])]
				%MainContainer/Library/FiltersPage/Container/Row2/Button.mouse_default_cursor_shape = [CursorShape.CURSOR_FORBIDDEN, CursorShape.CURSOR_POINTING_HAND][int(library_page in [2])]
				%MainContainer/Library/FiltersPage/Container/Row3.modulate = [Color.GRAY, Color.WHITE][int(library_page in [0, 1, 3])]
				%MainContainer/Library/FiltersPage/Container/Row3/Button.mouse_default_cursor_shape = [CursorShape.CURSOR_FORBIDDEN, CursorShape.CURSOR_POINTING_HAND][int(library_page in [0, 1, 3])]
				%MainContainer/Library/FiltersPage/Container/Row4.modulate = [Color.GRAY, Color.WHITE][int(library_page in [2])]
				%MainContainer/Library/FiltersPage/Container/Row4/Button.mouse_default_cursor_shape = [CursorShape.CURSOR_FORBIDDEN, CursorShape.CURSOR_POINTING_HAND][int(library_page in [2])]
			%MainContainer/Library/FiltersPage.size = %MainContainer/Library/FiltersPage.custom_minimum_size
			%MainContainer/Library/FiltersPage.visible = state
			return)
	%MainContainer/Library/FiltersPage/Container/Row1/Button.pressed.connect(
		func() -> void:
			if %MainContainer/Library/FiltersPage/Container/Row1.modulate == Color.GRAY:
				return
			if %MainContainer/Library/Container/Header/TabContainer/Searchbox.text != "":
				%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "-"
			%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "artist:id"
			return)
	%MainContainer/Library/FiltersPage/Container/Row2/Button.pressed.connect(
		func() -> void:
			if %MainContainer/Library/FiltersPage/Container/Row2.modulate == Color.GRAY:
				return
			if %MainContainer/Library/Container/Header/TabContainer/Searchbox.text != "":
				%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "-"
			%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "album:id"
			return)
	%MainContainer/Library/FiltersPage/Container/Row3/Button.pressed.connect(
		func() -> void:
			if %MainContainer/Library/FiltersPage/Container/Row3.modulate == Color.GRAY:
				return
			if %MainContainer/Library/Container/Header/TabContainer/Searchbox.text != "":
				%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "-"
			%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "song:id"
			return)
	%MainContainer/Library/FiltersPage/Container/Row4/Button.pressed.connect(
		func() -> void:
			if %MainContainer/Library/FiltersPage/Container/Row4.modulate == Color.GRAY:
				return
			if %MainContainer/Library/Container/Header/TabContainer/Searchbox.text != "":
				%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "-"
			%MainContainer/Library/Container/Header/TabContainer/Searchbox.text += "playlist:id"
			return)
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/CloseBtn.texture_normal = GeneralManager.get_icon_texture("Close")
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/CloseBtn.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile.visible = false; %MainContainer/Library/Container/ScrollContainer.visible = true; %MainContainer/Library/Container/Profile/SelectList.visible = false; return)
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.texture_normal = GeneralManager.get_icon_texture("Refresh")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/RefreshBtn.pressed.connect(func() -> void: open_context_menu(library_details_item_id); return)
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ClearBtn.texture_normal = GeneralManager.get_icon_texture("Delete")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ClearBtn.pressed.connect(Callable(self, "profile_clear_pressed"))
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.texture_normal = GeneralManager.get_icon_texture("Upload")
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.pressed.connect(
		func() -> void: 
			%MainContainer/Library/Container/Profile/SelectList.position = Vector2i(%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.position.x + 175, %MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.position.y + 225)
			%MainContainer/Library/Container/Profile/SelectList/ScrollContainer.scroll_horizontal = 0
			%MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; 
			if %MainContainer/Library/Container/Profile/SelectList.visible: 
				populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM][library_page - 1], "profile_selector_selected", self); 
			return)
	%MainContainer/Library/Container/Profile/Container/Container/Body/DataList/Container/InfoContainer/AddArtistButton.texture_normal = GeneralManager.get_icon_texture("ArtistList")
	%MainContainer/Library/Container/Profile/Container/Container/Body/DataList/Container/InfoContainer/AddArtistButton.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.ARTIST, "playlist_profile_upload_button_pressed", self); return)
	%MainContainer/Library/Container/Profile/Container/Container/Body/DataList/Container/InfoContainer/AddAlbumButton.texture_normal = GeneralManager.get_icon_texture("Album")
	%MainContainer/Library/Container/Profile/Container/Container/Body/DataList/Container/InfoContainer/AddAlbumButton.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.ALBUM, "playlist_profile_upload_button_pressed", self); return)
	%MainContainer/Library/Container/Profile/Container/Container/Body/DataList/Container/InfoContainer/AddSongButton.texture_normal = GeneralManager.get_icon_texture("Songs")
	%MainContainer/Library/Container/Profile/Container/Container/Body/DataList/Container/InfoContainer/AddSongButton.pressed.connect(func() -> void: %MainContainer/Library/Container/Profile/SelectList.visible = !%MainContainer/Library/Container/Profile/SelectList.visible; if %MainContainer/Library/Container/Profile/SelectList.visible: populate_data_list(%MainContainer/Library/Container/Profile/SelectList/ScrollContainer/Container, MasterDirectoryManager.use_type.SONG, "playlist_profile_upload_button_pressed", self); return)
	%MainContainer/Library/Container/Profile/Container/Container/AudioFileContainer/Container/ClearBtn.pressed.connect(
		func() -> void:
			MasterDirectoryManager.song_id_dict[library_details_item_id]["song_file_path"] = ""
			%MainContainer/Library/Container/Profile/Container/Container/AudioFileContainer/Container/Title.text = "None"
			return)
	%MainContainer/Library/Container/Profile/Container/Container/AudioFileContainer/Container/SelectBtn.pressed.connect(
		func() -> void:
			%SelectSongDialog.visible = true
			await %SelectSongDialog.file_selected
			MasterDirectoryManager.song_id_dict[library_details_item_id]["song_file_path"] = %SelectSongDialog.current_path
			%MainContainer/Library/Container/Profile/Container/Container/AudioFileContainer/Container/Title.text = %SelectSongDialog.current_path.get_file()
			return)
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
	for setting : String in user_setting_keys:
		%MainContainer/Profile/Container/Body/Settings/Container/SettingsPanel/Container/Buttons.get_child(user_setting_keys.find(setting)).update({"pressed": MasterDirectoryManager.user_data_dict[setting]})
	for access_setting : String in accessibility_setting_keys:
		match typeof(MasterDirectoryManager.user_data_dict[access_setting]):
			TYPE_FLOAT:
				%MainContainer/Profile/Container/Body/Accessibility/Container/Panel1/Container/Buttons.get_child(accessibility_setting_keys.find(access_setting)).update({"value_float": MasterDirectoryManager.user_data_dict[access_setting]})
			TYPE_BOOL:
				%MainContainer/Profile/Container/Body/Accessibility/Container/Panel1/Container/Buttons.get_child(accessibility_setting_keys.find(access_setting)).update({"pressed": MasterDirectoryManager.user_data_dict[access_setting]})
	for setting : String in network_setting_keys:
		%MainContainer/Profile/Container/Body/Network/Container/Panel1/Container/Buttons.get_child(network_setting_keys.find(setting)).update({"pressed": MasterDirectoryManager.user_data_dict[setting]})
	for i : int in range(0, len(MasterDirectoryManager.user_data_dict["player_widgets"])):
		%MainContainer/Profile/Container/Body/Settings/Container/WidgetPanel/Container/Buttons.get_child(i).update({"pressed": MasterDirectoryManager.user_data_dict["player_widgets"][i]})
	if not MasterDirectoryManager.finished_loading_keybinds:
		await MasterDirectoryManager.finished_loading_keybinds_signal
	update_keybinds_screen()
	DisplayServer.window_set_current_screen(wrapi(MasterDirectoryManager.user_data_dict["window_screen"], 0, DisplayServer.get_screen_count()))
	DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN][int(MasterDirectoryManager.user_data_dict["fullscreen"])])
	ProjectSettings.set("display/window/energy_saving/keep_screen_on", MasterDirectoryManager.user_data_dict["keep_screen_on"])
	%PlayingScreen.fullscreen = MasterDirectoryManager.user_data_dict["player_fullscreen"]
	%NewUserScreen.visible = MasterDirectoryManager.new_user
	if MasterDirectoryManager.user_data_dict["generate_home_screen"]:
		await create_home_screen()
	else:
		_apply_scroll_cursors()
	await get_tree().process_frame
	_apply_cli_size_mod()
	_apply_profile_size_mod()
	primary_initialization_finished = true
	self.emit_signal("primary_initialization_finished_signal")
	#
	await get_tree().create_timer(0.05).timeout
	await create_tween().tween_property(%LoadingScreen, "modulate", Color(1, 1, 1, 0), 0.25).from(Color(1, 1, 1, 1)).finished
	%LoadingScreen.visible = false
	GeneralManager.set_mouse_busy_state.call(false)
	GeneralManager.cli_print_callable.call("SYS: Programme Initialization Complete")
	%MainContainer/Library/FiltersPage.visible = false
	if GeneralManager.version != GeneralManager.latest_version and not GeneralManager.latest_version in ["Unknown", "Unresolved"]:
		create_alert("Your has been found to not match the latest available, go to\n[url=https://github.com/NatZombieGames/Nat-Music-Programme/releases/latest][i]The Latest Release Here[/i][/url]", "ALERT!")
	return

func _input(event : InputEvent) -> void:
	#if event.get_class() != "InputEventMouseMotion" and not event.is_echo() and event.is_pressed():
	#	print(get_viewport().gui_get_focus_owner())
	if GeneralManager.is_valid_keybind.call(event) and $Camera/AspectRatioContainer/KeybindScreen.visible:
		if GeneralManager.get_event_code(event) != KEY_DELETE:
			#print("\n\nkeybind: " + str(MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]) + "\nreplacing customevent " + str(MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]][active_keybind_switching_data[0]]) + "\nwith new custom event of " + str(GeneralManager.parse_inputevent_to_customevent(event)) + "\nkeybinds before change: " + str(MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]]) + ", changing index " + str(active_keybind_switching_data[0]) + "\n\n")
			MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]][active_keybind_switching_data[0]] = GeneralManager.parse_inputevent_to_customevent(event)
		else:
			MasterDirectoryManager.user_data_dict["keybinds"][MasterDirectoryManager.keybinds.keys()[active_keybind_switching_data[1]]][active_keybind_switching_data[0]] = ""
		MasterDirectoryManager.apply_control_settings()
		await get_tree().process_frame
		update_keybinds_screen()
		$Camera/AspectRatioContainer/KeybindScreen.visible = false
		#print("-")
	elif $Camera/AspectRatioContainer/KeybindScreen.visible == false:
		if Input.is_action_just_pressed("ToggleFullscreen", true):
			MasterDirectoryManager.user_data_dict["fullscreen"] = !MasterDirectoryManager.user_data_dict["fullscreen"]
			DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN][int(MasterDirectoryManager.user_data_dict["fullscreen"])])
		elif Input.is_action_just_pressed("Save", true):
			MasterDirectoryManager.save_data()
		elif Input.is_action_just_pressed("QuitAndSave", true):
			MasterDirectoryManager.save_data()
			if MasterDirectoryManager.finished_saving_data == false:
				await MasterDirectoryManager.finished_saving_data_signal
			get_tree().quit()
		elif Input.is_action_just_pressed("QuitWithoutSaving", true):
			get_tree().quit()
		elif Input.is_action_just_pressed("HardReloadApp", true):
			OS.set_restart_on_exit(true)
			get_tree().quit()
		elif Input.is_action_just_pressed("ToggleCLI", true) and $Camera.enabled:
			%CommandLineInterface.active = !%CommandLineInterface.active
	return

func create_home_screen() -> void:
	await _set_soft_loading(true)
	#
	var to_create : Dictionary[String, PackedStringArray] = {}
	var time_dict : Dictionary[String, Variant] = {}
	time_dict.assign(Time.get_datetime_dict_from_system())
	var weekday : String = GeneralManager.weekday_names[time_dict["weekday"]-1]
	var month : String = GeneralManager.month_names[time_dict["month"]-1]
	var albums : PackedStringArray = MasterDirectoryManager.album_id_dict.keys()
	var songs : PackedStringArray = MasterDirectoryManager.song_id_dict.keys()
	var playlists : PackedStringArray = MasterDirectoryManager.playlist_id_dict.keys()
	var temp_arr : PackedStringArray = []
	var temp_str : String = ""
	var temp_dict : Dictionary
	%MainContainer/Home/MarginGiver/ScrollContainer/Container.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
	if MasterDirectoryManager.user_data_dict["active_song_data"].get("active_song_id", "") != "":
		temp_str = MasterDirectoryManager.user_data_dict["active_song_data"]["active_song_id"]
		temp_dict = MasterDirectoryManager.song_id_dict[temp_str]
		if temp_dict["album"] != "" and MasterDirectoryManager.album_id_dict[temp_dict["album"]]["artist"] != "":
			temp_arr = [MasterDirectoryManager.album_id_dict[temp_dict["album"]]["artist"]]
			temp_arr.append_array(MasterDirectoryManager.get_random_artist_songs(MasterDirectoryManager.album_id_dict[temp_dict["album"]]["artist"]))
			to_create["More From " + MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.album_id_dict[temp_dict["album"]]["artist"]]["name"] + ":"] = temp_arr
		temp_arr = []
	for artist : String in MasterDirectoryManager.artist_id_dict.keys():
		if MasterDirectoryManager.artist_id_dict[artist]["name"].left(1) == weekday.left(1):
			temp_arr.append(artist)
	await get_tree().process_frame
	temp_arr = []
	if len(albums) > 15:
		seed((time_dict["year"] * time_dict["month"]) - time_dict["day"])
		for i : int in range(0, 10):
			temp_arr.append(albums[randi_range(0, len(albums)-1)])
			albums.remove_at(albums.find(temp_arr[-1]))
		seed(GeneralManager.rng_seed)
		to_create["Albums Trending Today:"] = temp_arr
		temp_arr = []
	await get_tree().process_frame
	if len(songs) > 15:
		seed((time_dict["year"] / time_dict["month"]) + time_dict["day"])
		for i : int in range(0, 10):
			temp_arr.append(songs[randi_range(0, len(songs)-1)])
			songs.remove_at(songs.find(temp_arr[-1]))
		seed(GeneralManager.rng_seed)
		to_create["Songs Trending Today:"] = temp_arr
		temp_arr = []
	await get_tree().process_frame
	for artist : String in MasterDirectoryManager.artist_id_dict.keys():
		if MasterDirectoryManager.artist_id_dict[artist]["name"].left(1) == weekday.left(1):
			temp_arr.append(artist)
	if len(temp_arr) > 0:
		seed(0)
		temp_str = temp_arr[randi_range(0, len(temp_arr)-1)]
		temp_arr = [temp_str]
		temp_arr.append_array(MasterDirectoryManager.get_random_artist_songs(temp_str))
		to_create[MasterDirectoryManager.artist_id_dict[temp_str]["name"] + " " + weekday + ":"] = temp_arr
		seed(GeneralManager.rng_seed)
	await get_tree().process_frame
	temp_arr = []
	for artist : String in MasterDirectoryManager.artist_id_dict.keys():
		if MasterDirectoryManager.artist_id_dict[artist]["name"].left(1) == month.left(1):
			temp_arr.append(artist)
	if len(temp_arr) > 0:
		seed(0)
		temp_str = temp_arr[randi_range(0, len(temp_arr)-1)]
		temp_arr = [temp_str]
		temp_arr.append_array(MasterDirectoryManager.get_random_artist_songs(temp_str))
		to_create[month + " For " + MasterDirectoryManager.artist_id_dict[temp_str]["name"] + ":"] = temp_arr
		seed(GeneralManager.rng_seed)
	await get_tree().process_frame
	temp_arr = []
	if len(songs) > 0:
		var temp_arr_2 : PackedStringArray = (func() -> PackedStringArray: return MasterDirectoryManager.song_id_dict.keys().filter(func(item : String) -> bool: return MasterDirectoryManager.song_id_dict[item]["favourite"])).call()
		if len(temp_arr_2) < 15:
			temp_arr = temp_arr_2
			temp_arr = GeneralManager.packed_string_shuffle(temp_arr)
		else:
			seed((time_dict["day"] * time_dict["month"]) / time_dict["year"])
			for i : int in range(0, 15):
				temp_arr.append(temp_arr_2[randi_range(0, len(temp_arr_2)-1)])
				temp_arr_2.remove_at(temp_arr_2.find(temp_arr[-1]))
			seed(GeneralManager.rng_seed)
		if len(temp_arr) > 0:
			to_create["Revisit Old Favourites:"] = temp_arr
		temp_arr = []
	if len(playlists) > 0:
		seed(time_dict["year"] * (time_dict["day"] / time_dict["month"]))
		temp_str = playlists[randi_range(0, len(playlists)-1)]
		temp_arr = [temp_str]
		temp_arr.append_array(MasterDirectoryManager.playlist_id_dict[temp_str]["songs"])
		to_create["When Did You Last Listen To " + MasterDirectoryManager.playlist_id_dict[temp_str]["name"] + "?:"] = temp_arr
		seed(GeneralManager.rng_seed)
	for key : String in to_create.keys():
		%MainContainer/Home/MarginGiver/ScrollContainer/Container.add_child(home_page_bar_scene.instantiate())
		%MainContainer/Home/MarginGiver/ScrollContainer/Container.get_child(-1).update(to_create[key], key)
	%MainContainer/Home/MarginGiver/ScrollContainer/Container.add_child(home_page_footer.instantiate())
	%MainContainer/Home/MarginGiver/ScrollContainer/Container.get_child(-1).get_child(1).update({"button_custom_minimum_size": Vector2i(35, 35), "texture_icon_name": "Random", "pressed_signal_sender": self, "pressed_signal_name": "play", "argument": "@random"})
	await get_tree().process_frame
	_apply_scroll_cursors()
	#
	await _set_soft_loading(false)
	return

## For the CLI to call since the real one is async.
func _create_home_screen() -> int:
	create_home_screen()
	return GeneralManager.err.OK

func update_keybinds_screen() -> void:
	var keybinds : PackedStringArray = MasterDirectoryManager.keybinds.keys()
	#print(str(MasterDirectoryManager.keybinds).replace('": [{', '":\n\t[{').replace('}], "', '}]\n"'))
	while len(%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.get_children()) < len(keybinds):
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.add_child(Label.new())
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.get_child(-1).custom_minimum_size.y = 30
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.get_child(-1).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	while len(%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow1.get_children()) < len(keybinds):
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow1.add_child(custom_button.instantiate())
	while len(%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow2.get_children()) < len(keybinds):
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow2.add_child(custom_button.instantiate())
	for i : int in range(0, len(keybinds)):
		var events : Array = MasterDirectoryManager.user_data_dict["keybinds"][keybinds[i]]
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.get_child(i).text = keybinds[i].capitalize()
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow1.get_child(i).update({"button_text": "None", "pressed_signal_sender": self, "pressed_signal_name": "keybind_button_pressed", "argument": [0, i]})
		if typeof(events[0]) == TYPE_DICTIONARY:
			%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow1.get_child(i).update({"button_text": GeneralManager.customevent_to_string(events[0])})
		%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow2.get_child(i).update({"button_text": "None", "pressed_signal_sender": self, "pressed_signal_name": "keybind_button_pressed", "argument": [1, i]})
		if typeof(events[1]) == TYPE_DICTIONARY:
			%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/ButtonRow2.get_child(i).update({"button_text": GeneralManager.customevent_to_string(events[1])})
	%MainContainer/Profile/Container/Body/Keybinds/Container/Panel1/Container/Keybinds/Labels.get_children().map(func(node : Label) -> Label: node.custom_minimum_size.y = 30; node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; return node)
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
	#print("soy happened with an id of " + id + ", with a library details id of " + library_details_item_id + ", to change key of " + ["album", "artist"][int(GeneralManager.get_id_type(library_details_item_id) == MasterDirectoryManager.use_type.ALBUM)])
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
	if location.get_parent().get_class() == "ScrollContainer":
		location.get_parent().scroll_horizontal = 0
		location.get_parent().scroll_vertical = 0
	while len(location.get_children()) < len(keys):
		location.add_child(entryitem_scene.instantiate())
	for node : Node in location.get_children():
		node.visible = location.get_children().find(node) < len(keys)
		if node.visible:
			var key : String = keys[location.get_children().find(node)]
			var to_update : Dictionary = {"title": data[key]["name"], "subtitle": key, "image": GeneralManager.get_icon_texture("Missing"), "pressed_signal_sender": pressed_sender, "pressed_signal_name": pressed_name, "pressed_signal_argument": key}
			if type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST] and GeneralManager.is_valid_image.call(data[key]["image_file_path"]):
				to_update["image"] = get_image.call(data[key]["image_file_path"])
			elif type == MasterDirectoryManager.use_type.SONG and GeneralManager.is_valid_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"]):
				to_update["image"] = get_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"])
			node.call("update", to_update)
	if type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM]:
		location.add_child(entryitem_scene.instantiate())
		location.get_child(-1).call("update", {"title": "Go To Create Screen", "subtitle": "", "image": GeneralManager.get_icon_texture("AddItem"), "pressed_signal_sender": self, "pressed_signal_name": "set_main_screen_page", "pressed_signal_argument": "1"})
	#
	await _set_soft_loading(false)
	return

func populate_data_list_context_menu(location : Node, type : MasterDirectoryManager.use_type, data : Dictionary, pressed_sender : Node = self, action_button_signal_names : PackedStringArray = ["context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed", "context_action_button_pressed", "open_context_menu"]) -> void:
	#print("\n\ndata received in populate data list context menu: " + str(data) + "\n\n")
	await _set_soft_loading(true)
	#
	var keys : PackedStringArray = data.keys()
	var get_image : Callable = (func(path : String) -> ImageTexture: var image : Image = GeneralManager.get_image(path); var texture : ImageTexture = ImageTexture.create_from_image(image); texture.resource_name = image.resource_name; return texture)
	if location.get_parent().get_class() == "ScrollContainer":
		location.get_parent().scroll_horizontal = 0
		location.get_parent().scroll_vertical = 0
	while len(location.get_children()) < len(keys):
		location.add_child(list_item_scene.instantiate())
	for item : Node in location.get_children():
		item.visible = location.get_children().find(item) < len(keys)
		if item.visible:
			var key : String = keys[location.get_children().find(item)]
			var parent_id : String
			if GeneralManager.get_id_type(library_details_item_id) != MasterDirectoryManager.use_type.PLAYLIST and type in [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.SONG]:
				parent_id = data[key][MasterDirectoryManager.use_type.find_key(int(key.left(1))-1).to_lower()]
			else:
				parent_id = library_details_item_id
			var to_update : Dictionary = {"title": data[key]["name"], "subtitle": key, "copy_subtitle_text": (" ID '[u]" + key + "[/u]' Was Copied To Clipboard. "), "image": GeneralManager.get_icon_texture("Missing"), "action_button_sender": pressed_sender, "action_buttons": 6, "action_button_images": ["Up", "Down", "Play", ["Favourite", "Favourited"][int(data[key]["favourite"])], "ListRemove", "Elipses"], "action_button_signal_names": action_button_signal_names, "action_button_arguments": [["0", parent_id, location], ["1", parent_id, location], ["2", key], ["3", key], ["4", parent_id, location, key], key]}
			if type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST] and GeneralManager.is_valid_image.call(data[key]["image_file_path"]):
				to_update["image"] = get_image.call(data[key]["image_file_path"])
			elif type == MasterDirectoryManager.use_type.SONG and GeneralManager.is_valid_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"]):
				to_update["image"] = get_image.call(MasterDirectoryManager.album_id_dict[data[key]["album"]]["image_file_path"])
			item.call("update", to_update)
	#
	await _set_soft_loading(false)
	return

func set_song_upload_style(style : String) -> void:
	#print("-\nsong upload style is " + str(style))
	var dialog : FileDialog = [%SelectSongDialog, %SelectSongDirectoryDialog][int(style)]
	var selected : String
	var starting_list : Array[Dictionary] = song_upload_list.duplicate()
	dialog.visible = true
	await [dialog.file_selected, dialog.dir_selected][int(style)]
	selected = dialog.current_path
	#print("selected " + selected)
	#print(dialog.current_path.split("/"))
	#print("selected is valid dir: " + str(DirAccess.dir_exists_absolute(selected)))
	#print("selected is valid file: " + str(FileAccess.file_exists(selected)))
	if selected != "" and not [FileAccess.file_exists(selected), DirAccess.dir_exists_absolute(selected)][int(style)]:
		create_popup_notif(" " + ["Unable To Validate File", "Unable To Validate Directory"][int(style)] + ", Please Try Again With A Different Path. ")
		return
	if style == "0":
		#print("adding one file")
		song_upload_list.append({"name": selected.get_file().get_basename(), "path": selected})
	elif style == "1":
		#print("adding directory")
		for item : String in (func() -> Array: var dir : DirAccess = DirAccess.open(selected); print("Dir Access Status: " + str(DirAccess.get_open_error())); return Array(dir.get_files()).filter(func(file : String) -> bool: return file.get_extension() in GeneralManager.valid_audio_types)).call():
			#print("adding into song upload list: " + str({"name": item.get_basename(), "path": selected + "\\"[0] + item}))
			song_upload_list.append({"name": item.get_basename(), "path": selected + "\\"[0] + item})
		#print("Dir Acess Err: " + str(DirAccess.get_open_error()))
	if starting_list == song_upload_list:
		create_popup_notif("Unabled to upload any songs, make sure they are of a valid type.")
	populate_song_list(song_upload_list, %MainContainer/New/Container/Body/Container/Container/DataList/Container/ScrollContainer/Container)
	return

func populate_library_screen(page : int) -> void:
	#print("\n- populate library start with a page of " + str(page))
	await _set_soft_loading(true)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BUSY)
	#
	%MainContainer/Library/Container/Header/TabContainer.get_children().filter(func(node : Node) -> bool: return node.get_class() == "PanelContainer")[int(page)].update({"pressed": true})
	if page != library_page:
		%MainContainer/Library/Container/ScrollContainer.scroll_vertical = 0
		%MainContainer/Library/Container/ScrollContainer.scroll_horizontal = 0
		library_page = page
	%MainContainer/Library/Container/Profile.visible = false
	%MainContainer/Library/Container/Header/TabContainer/FilterListButton.button_pressed = false
	%MainContainer/Library/Container/ScrollContainer.visible = true
	%MainContainer/Library/Container/Header/TabContainer/Page.text = " " + str(Array(MasterDirectoryManager.data_types).map(func(item : String) -> String: return item.capitalize())[page]) + " "
	var location : VBoxContainer = %MainContainer/Library/Container/ScrollContainer/ItemList
	var data : Dictionary = MasterDirectoryManager.get(MasterDirectoryManager.data_types[page] + "_id_dict")
	var data_keys : PackedStringArray = (func() -> Array: var arr : Array = data.keys(); arr.sort_custom((func(x : String, y : String) -> bool: return data[x]["name"] < data[y]["name"])); return arr).call()
	while len(location.get_children()) < len(data_keys):
		location.add_child(list_item_scene.instantiate())
	location.get_child(0).size_mod = MasterDirectoryManager.user_data_dict["library_size_modifier"]
	if len(data_keys) < len(location.get_children()):
		data_keys.append_array((func() -> Array: var arr : PackedStringArray = []; arr.resize(len(location.get_children()) - len(data_keys)); arr.fill("invalid"); return arr).call())
	for item : int in range(0, len(data_keys)):
		var node : Node = location.get_child(item)
		var data_id : String = data_keys[item]
		node.active = data_id != "invalid"
		node.visible = node.active
		if node.active:
			#print("data id: " + data_id + ", data: " + str(data[data_id]))
			var to_update : Dictionary = {"title": data[data_id]["name"], "subtitle": data_id, "copy_subtitle_text": (" ID '[u]" + data_id + "[/u]' Was Copied To Clipboard. "), "image": "", "action_button_sender": self, "action_buttons": 4, "action_button_images": ["Elipses", "Play", ["Favourite", "Favourited"][int(data[data_id]["favourite"])], "Delete"], "action_button_signal_names": ["open_context_menu", "play", "set_favourite", "delete"], "action_button_arguments": [data_id, data_id, data_id, data_id]}
			if library_page == 2:
				if data[data_id]["album"] != "" and data[data_id]["album"] in MasterDirectoryManager.album_id_dict.keys():
					to_update["image"] = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.album_id_dict[data[data_id]["album"]]["image_file_path"]))
				else:
					to_update["image"] = GeneralManager.get_icon_texture("Missing")
			else:
				to_update["image"] = ImageTexture.create_from_image(GeneralManager.get_image(data[data_id]["image_file_path"]))
			node.update(to_update)
	if %MainContainer/Library/Container/Header/TabContainer/Searchbox.text != "":
		search_library(%MainContainer/Library/Container/Header/TabContainer/Searchbox.text)
	#
	await _set_soft_loading(false)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	return

func populate_library_screen_str(page : String) -> void:
	populate_library_screen(int(page))
	return

func search_library(query : String = "") -> void:
	await _set_soft_loading(true)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BUSY)
	#
	var children : Array[Node] = %MainContainer/Library/Container/ScrollContainer/ItemList.get_children().filter(func(node : Node) -> bool: return node.active)
	var filters : Dictionary[String, String]
	var match_case : bool = !%MainContainer/Library/Container/Header/TabContainer/MatchCaseButton.button_pressed
	for filter : String in PackedStringArray(query.split("-", false)):
		if library_page in [1, 2] and filter.left(7).to_lower() == "artist:":
			filters["artist"] = filter.right(-7)
		elif library_page in [2] and filter.left(6).to_lower() == "album:":
			filters["album"] = filter.right(-6)
		elif library_page in [0, 1, 3] and filter.left(5).to_lower() == "song:":
			filters["song"] = filter.right(-5)
		elif library_page in [2] and filter.left(9).to_lower() == "playlist:":
			filters["playlist"] = filter.right(-9)
		elif filter.left(10).to_lower() == "favourite:":
			filters["favourite"] = filter.right(-10)
		elif filter.left(5).to_lower() == "name:":
			filters["name"] = filter.right(-5)
		else:
			filters["name"] = filter
	#print("query: " + query)
	#print("match case: " + str(match_case))
	#print("filters: " + str(filters))
	for child : Node in children:
		if query == "":
			child.visible = true
			continue
		var valid : bool = true
		var id : String = child.subtitle
		for filter : String in filters.keys():
			match filter:
				"artist":
					if library_page == 1:
						valid = filters["artist"] == MasterDirectoryManager.album_id_dict[id]["artist"]
					elif MasterDirectoryManager.song_id_dict[id]["album"] in MasterDirectoryManager.album_id_dict.keys():
						valid = filters["artist"] == MasterDirectoryManager.album_id_dict[MasterDirectoryManager.song_id_dict[id]["album"]]["artist"]
					if not valid:
						break
				"album":
					valid = filters["album"] == MasterDirectoryManager.song_id_dict[id]["album"]
					if not valid:
						break
				"song":
					match library_page:
						0:
							for album : String in MasterDirectoryManager.artist_id_dict[id]["albums"]:
								if MasterDirectoryManager.album_id_dict.has(album):
									valid = filters["song"] in MasterDirectoryManager.album_id_dict[album]["songs"]
								if not valid:
									break
						1:
							valid = filters["song"] in MasterDirectoryManager.album_id_dict[id]["songs"]
						3:
							valid = filters["song"] in MasterDirectoryManager.playlist_id_dict[id]["songs"]
					if not valid:
						break
				"playlist":
					valid = MasterDirectoryManager.playlist_id_dict.has(filters["playlist"]) and id in MasterDirectoryManager.playlist_id_dict[filters["playlist"]]["songs"]
					if not valid:
						break
				"favourite":
					valid = MasterDirectoryManager.song_id_dict[id]["favourite"] == (filters["favourite"].to_lower() in GeneralManager.boolean_strings)
					if not valid:
						break
				"name":
					if match_case:
						valid = filters["name"] in child.title
					else:
						valid = filters["name"].to_lower() in child.title.to_lower()
					if not valid:
						break
		child.visible = valid
	#
	await _set_soft_loading(false)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	return

## For the CLI to call since the real one is async.
func _search_library(query : String = "") -> void:
	search_library(query)
	return

func library_details_info_altered(new_value : String, property_name : String) -> void:
	var item_dict_name : String = ["artist", "album", "song"][int(library_details_item_id[0])] + "_id_dict"
	#print("trying to set " + item_dict_name + " with an id of " + library_details_item_id + " with the key of " + property_name + " to the value of " + new_value)
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
	#print("\nindex to remove from song upload list: " + index + "\n")
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
	#print("\nsong list at population:\n" + str(data).replace(" }, ", " }\n"))
	while len(location.get_children()) < len(data):
		location.add_child(basic_entryitem_scene.instantiate())
	for node : Node in location.get_children():
		node.visible = location.get_children().find(node) < len(data)
		if node.visible:
			var item : Dictionary = data[location.get_children().find(node)]
			node.call("update", {"title": item["name"], "subtitle": item.get(["path", "id"][subtitle_type]), "id": str(data.find(item)), "editable_title": true, "signal_sender": self, "button_icon_name": "Delete", "pressed_signal_name": "remove_from_song_upload_list", "title_changed_signal_name": "update_song_upload_list_data"})
			#await get_tree().process_frame
	%MainContainer/New/Container/Body/Container/Container/DataList/Container/InfoContainer/ItemQuantity.text = " Items: " + str(len(data)) + " "
	return

func mass_import(_arg : String = "") -> void:
	%MassImportDialog.visible = true
	await %MassImportDialog.dir_selected
	var path : String = %MassImportDialog.current_path
	var new_artist_ids : PackedStringArray
	var new_album_ids : PackedStringArray
	var new_song_ids : PackedStringArray
	var available_images : PackedStringArray
	#print("Path at mass import: " + path)
	for artist_dir : String in DirAccess.get_directories_at(path):
		new_artist_ids.append(MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.ARTIST))
		#print("making new ARTIST with id '" + new_artist_ids[-1] + "' and name '" + artist_dir + "'")
		MasterDirectoryManager.artist_id_dict[new_artist_ids[-1]] = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.ARTIST)
		MasterDirectoryManager.artist_id_dict[new_artist_ids[-1]]["name"] = artist_dir
		available_images = GeneralManager.packed_string_filter(DirAccess.get_files_at(path + "/" + artist_dir), GeneralManager.is_valid_image)
		if len(available_images) > 0:
			MasterDirectoryManager.artist_id_dict[new_artist_ids[-1]]["image_file_path"] = path + "/" + artist_dir + "/" + available_images[0]
		for album_dir : String in DirAccess.get_directories_at(path + "/" + artist_dir):
			new_album_ids.append(MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.ALBUM))
			#print("making new ALBUM  with id '" + new_album_ids[-1] + "' and name '" + album_dir + "'")
			MasterDirectoryManager.album_id_dict[new_album_ids[-1]] = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.ALBUM)
			MasterDirectoryManager.album_id_dict[new_album_ids[-1]]["name"] = album_dir
			MasterDirectoryManager.album_id_dict[new_album_ids[-1]]["artist"] = new_artist_ids[-1]
			MasterDirectoryManager.artist_id_dict[new_artist_ids[-1]]["albums"].append(new_album_ids[-1])
			available_images = GeneralManager.packed_string_filter(DirAccess.get_files_at(path + "/" + artist_dir + "/" + album_dir), GeneralManager.is_valid_image)
			if len(available_images) > 0:
				MasterDirectoryManager.album_id_dict[new_album_ids[-1]]["image_file_path"] = path + "/" + artist_dir + "/" + album_dir + "/" + available_images[0]
			for song_file : String in DirAccess.get_files_at(path + "/" + artist_dir + "/" + album_dir):
				if song_file.get_extension() in GeneralManager.valid_audio_types:
					new_song_ids.append(MasterDirectoryManager.generate_id(MasterDirectoryManager.use_type.SONG))
					#print("making new  SONG  with id '" + new_song_ids[-1] + "' and name '" + song_file.get_basename() + "'")
					MasterDirectoryManager.song_id_dict[new_song_ids[-1]] = MasterDirectoryManager.get_data_template(MasterDirectoryManager.use_type.SONG)
					MasterDirectoryManager.song_id_dict[new_song_ids[-1]]["name"] = song_file.get_basename()
					MasterDirectoryManager.song_id_dict[new_song_ids[-1]]["song_file_path"] = path + "\\" + artist_dir + "\\" + album_dir + "\\" + song_file
					MasterDirectoryManager.song_id_dict[new_song_ids[-1]]["album"] = new_album_ids[-1]
					MasterDirectoryManager.album_id_dict[new_album_ids[-1]]["songs"].append(new_song_ids[-1])
	await get_tree().process_frame
	if len(new_artist_ids) == 0:
		create_popup_notif("Unable to create any data at directory [u]" + path + "[/u], please check it and try again.")
	else:
		create_popup_notif("Succesfully created [u]" + str(len(new_artist_ids)) + "[/u] Artists, [u]" + str(len(new_album_ids)) + "[/u] Albums and [u]" + str(len(new_song_ids)) + "[/u] Songs.")
	return

## For the CLI to call as normal one is aysnc
func _mass_import() -> int:
	mass_import()
	return GeneralManager.err.OK

func open_context_menu(id : String) -> int:
	#print("open context menu called with id of: " + id)
	GeneralManager.set_mouse_busy_state.call(true)
	library_details_item_id = id
	%MainContainer/Library/Container/ScrollContainer.visible = false
	%MainContainer/Library/Container/Profile/SelectList.visible = false
	var id_type : MasterDirectoryManager.use_type = GeneralManager.get_id_type(id)
	if GeneralManager.get_id_type(id) == MasterDirectoryManager.use_type.UNKNOWN:
		return GeneralManager.err.INVALID_ID
	#
	%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/SelectBtn.tooltip_text = "Select " + MasterDirectoryManager.data_types[id_type-1].capitalize()
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = GeneralManager.get_icon_texture()
	if id_type == MasterDirectoryManager.use_type.SONG:
		if MasterDirectoryManager.get_object_data.call(id)["album"] != "":
			%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["image_file_path"]))
	else:
		%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/ImageContainer/Image.texture = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(id)["image_file_path"]))
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Title.update({"editing_mode": true, "text": MasterDirectoryManager.get_object_data.call(id)["name"]})
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Title.update({"editing_mode": false})
	%MainContainer/Library/Container/Profile/Container/Container/HeaderContainer/Container/Subtitle.text = id
	var page_body : Control = %MainContainer/Library/Container/Profile/Container/Container/Body
	var page_parent : PanelContainer = %MainContainer/Library/Container/Profile/Container/Container/ParentContainer
	var audio_file : PanelContainer = %MainContainer/Library/Container/Profile/Container/Container/AudioFileContainer
	audio_file.visible = id_type == MasterDirectoryManager.use_type.SONG
	page_parent.visible = id_type in [MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.SONG]
	page_body.visible = !(id_type == MasterDirectoryManager.use_type.SONG)
	if id_type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST]:
		page_body.get_child(0).get_child(0).get_child(0).get_child(2).visible = id_type == MasterDirectoryManager.use_type.PLAYLIST
		page_body.get_child(0).get_child(0).get_child(0).get_child(3).visible = id_type == MasterDirectoryManager.use_type.PLAYLIST
		page_body.get_child(0).get_child(0).get_child(0).get_child(4).visible = id_type == MasterDirectoryManager.use_type.PLAYLIST
		page_body = page_body.get_child(0).get_child(0).get_child(2).get_child(0)
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
		var data : Dictionary = {"image": GeneralManager.get_icon_texture(), "title": "Unknown", "subtitle": "None"}
		match id_type:
			MasterDirectoryManager.use_type.ALBUM:
				if MasterDirectoryManager.album_id_dict[id].has("artist") and MasterDirectoryManager.album_id_dict[id]["artist"] != "":
					data["image"] = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["artist"])["image_file_path"]))
					data["title"] = MasterDirectoryManager.artist_id_dict[MasterDirectoryManager.album_id_dict[id]["artist"]]["name"]
					data["subtitle"] = MasterDirectoryManager.album_id_dict[id]["artist"]
			MasterDirectoryManager.use_type.SONG:
				if MasterDirectoryManager.song_id_dict[id].has("album") and MasterDirectoryManager.song_id_dict[id]["album"] != "":
					data["image"] = ImageTexture.create_from_image(GeneralManager.get_image(MasterDirectoryManager.get_object_data.call(MasterDirectoryManager.get_object_data.call(id)["album"])["image_file_path"]))
					data["title"] = MasterDirectoryManager.album_id_dict[MasterDirectoryManager.song_id_dict[id]["album"]]["name"]
					data["subtitle"] = MasterDirectoryManager.song_id_dict[id]["album"]
		%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/ImageContainer/Image.texture = data["image"]
		%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/Title.text = data["title"]
		%MainContainer/Library/Container/Profile/Container/Container/ParentContainer/Container/Subtitle.text = data["subtitle"]
	if id_type == MasterDirectoryManager.use_type.SONG:
		audio_file.get_child(0).find_child("Title", false).text = [MasterDirectoryManager.song_id_dict[id]["song_file_path"].get_file(), "None"][int(MasterDirectoryManager.song_id_dict[id]["song_file_path"] == "")]
	#
	%MainContainer/Library/Container/Profile.visible = true
	GeneralManager.set_mouse_busy_state.call(false)
	return GeneralManager.err.OK

func context_action_button_pressed(args : Array) -> void:
	#print("context action button pressed args: " + str(args))
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
		return GeneralManager.err.OK
	return GeneralManager.err.INVALID_ID

func delete(id : String, create_confirmation_popup : bool = true) -> void:
	#print("delete id is: " + id + ", it starts with: " + id.left(1))
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
			GeneralManager.image_cache.assign({})
			GeneralManager.image_average_cache.assign({})
			for item : Node in %MainContainer/Library/Container/ScrollContainer/ItemList.get_children():
				item.queue_free()
			playing_screen.song_cache.assign({})
		1:
			GeneralManager.image_cache.assign({})
		2:
			GeneralManager.image_average_cache.assign({})
		3:
			for item : Node in %MainContainer/Library/Container/ScrollContainer/ItemList.get_children():
				item.queue_free()
		4:
			playing_screen.song_cache.assign({})
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

func user_setting_changed(number : String, value : Variant) -> int:
	MasterDirectoryManager.user_data_dict[user_setting_keys[int(number)]] = value
	match user_setting_keys[int(number)]:
		"autocomplete", "cli_style":
			cli.set(user_setting_keys[int(number)], value)
	return GeneralManager.err.OK

func accessibility_setting_changed(number: String, value : Variant) -> void:
	MasterDirectoryManager.user_data_dict[accessibility_setting_keys[int(number)]] = value
	match accessibility_setting_keys[int(number)]:
		"cli_size_modifier":
			_apply_cli_size_mod()
		"profile_size_modifier":
			_apply_profile_size_mod()
		"solid_cli":
			cli.style = int(value)
	return

func network_setting_changed(number : String, value : bool) -> void:
	MasterDirectoryManager.user_data_dict[network_setting_keys[int(number)]] = value
	return

func player_widget_changed(number : String, state : bool) -> void:
	MasterDirectoryManager.user_data_dict["player_widgets"][int(number)] = state
	playing_screen.call("set_widgets")
	return

func create_select_pressed(key : String) -> void:
	#print("key pressed in create select: " + key)
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
	#print("button pressed during create: " + button)
	match button:
		"0":
			%SelectImageDialog.visible = true
			await %SelectImageDialog.file_selected
			new_entry_data["image_file_path"] = %SelectImageDialog.current_path
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
				MasterDirectoryManager.get(MasterDirectoryManager.data_types[new_page] + "_id_dict")[id] = new_entry_data
				if new_page == 1 and new_entry_data["artist"] != "":
					MasterDirectoryManager.artist_id_dict[new_entry_data["artist"]]["albums"].append(id)
				create_popup_notif(" Made A New " + MasterDirectoryManager.data_types[new_page].capitalize() + " With The ID [u]" + id + "[/u]. ")
			set_create_screen_page(str(new_page + 1))
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
	$Camera/AspectRatioContainer/GreaterContainer/Hatbar/Container.get_children().filter(func(node : Node) -> bool: return node.get_class() == "PanelContainer")[int(page)].update({"pressed": true})
	var children : Array[Node] = %MainContainer.get_children()
	children.map(func(node : Node) -> Node: node.visible = children.find(node) == int(page); return node)
	if page == "2":
		populate_library_screen(int(library_page))
	return

func set_create_screen_page(page : String) -> void:
	if page == "0":
		%MainContainer/New/Container/LandingPage.visible = true
		%MainContainer/New/Container/Body.visible = false
		%MainContainer/New/Container/Header/TabContainer/Page.text = " Creation Info"
		new_page = 0
		return
	%MainContainer/New/Container/LandingPage.visible = false
	%MainContainer/New/Container/Body.visible = true
	%MainContainer/New/Container/Header/TabContainer.get_children().filter(func(node : Node) -> bool: return node.get_class() == "PanelContainer")[int(page)].update({"pressed": true})
	%MainContainer/New/Container/Header/TabContainer/Page.text = " " + MasterDirectoryManager.data_types[int(page)-1].capitalize()
	new_page = int(page)-1
	new_entry_data = MasterDirectoryManager.get_data_template(new_page)
	song_upload_list = []
	$Camera/AspectRatioContainer/GreaterContainer/MainContainer/New/Container/Body/Container/Container/ParentContainer/Container/SelectBtn.tooltip_text = "Select " + MasterDirectoryManager.data_types[int(new_page)-1].capitalize()
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
	GeneralManager.navigate_node(children[2], "0,0,1").visible = not (children[2].visible and not children[1].visible)
	return

func set_profile_screen_page(page : String) -> void:
	%MainContainer/Profile/Container/Header/TabContainer.get_children().filter(func(node : Node) -> bool: return node.get_class() == "PanelContainer")[int(page)].update({"pressed": true})
	var children : Array[Node] = %MainContainer/Profile/Container/Body.get_children()
	children.map(func(node : Node) -> Node: node.visible = children.find(node) == int(page); return node)
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

func create_alert(text : String, title : String = "ALERT!", alert_size : Vector2 = Vector2(350, 150)) -> void:
	%AlertContainer.add_child(alert.instantiate())
	%AlertContainer.get_child(-1).text = text
	%AlertContainer.get_child(-1).title = title
	%AlertContainer.get_child(-1).custom_minimum_size = alert_size
	%AlertContainer.get_child(-1).size = alert_size
	%AlertContainer.get_child(-1).fire()
	return

func create_popup(title : String, responses : PackedStringArray = ["Yes", "No"]) -> int:
	%PopupContainer/Popup/Container/Title.text = title
	%PopupContainer/Popup/Container/ResponseContainer.get_children().map(func(btn : Control) -> Control: btn.visible = false; return btn)
	for i : int in range(0, mini(len(responses), %PopupContainer/Popup/Container/ResponseContainer.get_child_count())):
		%PopupContainer/Popup/Container/ResponseContainer.get_child(i).visible = true
		%PopupContainer/Popup/Container/ResponseContainer.get_child(i).update({"button_text": responses[i]})
	%PopupContainer.modulate.a = 0
	%PopupContainer.visible = true
	var anim_tween : Tween = create_tween().set_parallel()
	anim_tween.pause()
	anim_tween.tween_property(%PopupContainer/Popup, "modulate:a", 1, 0.2).from(0)
	anim_tween.tween_property(%PopupContainer/Popup, "position:y", 390, 0.2).from(490)
	anim_tween.tween_property(%PopupContainer, "modulate:a", 1, 0.2).from(0)
	anim_tween.play()
	await self.popup_responded
	return popup_response

func popup_response_pressed(arg : String) -> void:
	popup_response = int(arg)
	self.emit_signal("popup_responded")
	var anim_tween : Tween = create_tween().set_parallel()
	anim_tween.pause()
	anim_tween.tween_property(%PopupContainer/Popup, "modulate:a", 0, 0.2).from(1)
	anim_tween.tween_property(%PopupContainer/Popup, "position:y", 290, 0.2).from(390)
	anim_tween.tween_property(%PopupContainer, "modulate:a", 0, 0.2).from(1)
	anim_tween.play()
	await anim_tween.finished
	%PopupContainer.visible = false
	%PopupContainer.modulate.a = 1
	return

func toggle_cli(_arg : String = "") -> void:
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

func _apply_scroll_cursors() -> void:
	for scroll_container : ScrollContainer in get_tree().get_nodes_in_group("ScrollContainer"):
		scroll_container.get_v_scroll_bar().set("mouse_default_cursor_shape", CURSOR_VSIZE)
		scroll_container.get_h_scroll_bar().set("mouse_default_cursor_shape", CURSOR_HSIZE)
	return

func _apply_cli_size_mod() -> void:
	for cli_output_label : RichTextLabel in get_tree().get_nodes_in_group("CLIOutputLabel"):
		for type : String in rich_text_font_size_types:
			cli_output_label.set("theme_override_font_sizes/" + type + "_font_size", 16.0 * MasterDirectoryManager.user_data_dict["cli_size_modifier"])
	return

func _apply_profile_size_mod() -> void:
	for profile_label : RichTextLabel in get_tree().get_nodes_in_group("ProfileLabel"):
		for type : String in rich_text_font_size_types:
			profile_label.set("theme_override_font_sizes/" + type + "_font_size", 16.0 * MasterDirectoryManager.user_data_dict["profile_size_modifier"])
	return

func exit(_arg : String = "0") -> void:
	match await create_popup("Do You Wish To Save Before Quiting?", ["Yes, Save & Quit", "No, Quit Without Saving", "No, Don't Quit"]):
		0:
			await MasterDirectoryManager.save_data()
			get_tree().quit(0)
		1:
			get_tree().quit(0)
		2:
			return
	return
