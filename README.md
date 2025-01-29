# Nat Music Programme #
 
To use the programme, please see the 'Exported' folder and select the version for your machine, for more information on the app, please see below;

The NMP (Nat Music Programme) is an app made in Godot (4.3) which allows you to upload and listen to songs (.mp3, .wav and .oog), you can sort them by Artist and Album, and also create and manage Playlists. You can also use the built-in CLI (Command Line Interface) to get more granular control and specific information.
__The app is entirely offline and modifiable.

## Scalability / ID's ##

This project has been made with scalability in mind; As such many efforts have been made to ensure that the app doesn't limit your ability to listen to and organise music, including the ID system for every item.
__Each either Artist, Album, Song or Playlist uses a unique ID to identify itself, which is 17 characters long. The first character is a number ranged 0-3 which signs/indicates the type of the ID, and the other 16 are picked from a list of 120 characters, giving each data type 16**120 or 3.121749e+144 unique items available.
__Other smaller efforts have been made to make the app able to handle itself despite the way you want to use it, including giving multiple functions to the CLI to help make your management of the app and its data easier.

## Project Details ##

This is made entirely using Godot 4.3, which GDScript (all statically-typed) as the language. The project is organized into the following folders:
- Assets:
  - Fonts: The main font used by the app (JetBrains Mono Light (Light))
  - Icons: All the icons (.svg) used by the app, when the app is launched these are all read and imported into a dictionary with their names as the keys
  - Everything else is misc. assets including Styleboxes and ButtonGroups
- Exported:
  - Latest stable version of the app for all available platforms (Windows & Linux)
- Scenes:
  - All the scene files.
- Scripts:
  - Globals: All the global/manager scripts
  - All other script files.

## Data Management ##

When launched the app will check for 'NMP_Data.dat' in the same directory for all of its information, including Artist, Album, Song, Playlist and User data, this is also where data will be saved. __Only the directory the app is located in will be checked, so moving the app will require the data file to be moved to continue using said data. You can create backups of your data inside the app which will be named 'NMP_Data_{unix_time_according_to_system}.dat' and saved in the same directory as where the app is.
__The data is saved using Godot's ConfigFile class.