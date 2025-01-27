# Nat Music Programme #
 
To use the programme, please see the 'Exported' folder and select the version for your machine, for more information on the app, please see below;

The NMP (Nat Music Programme) is an app made in Godot (4.3) which allows you to upload and listen to songs (.mp3, .wav and .oog), you can sort them by Artist and Album, and also create and manage Playlists. You can also use the built-in CLI (Command Line Interface) to get more granular control and specific information. It's very customizable and easy to use while being entirely offline, and easily modifiable from being open-source.

## Project Details ##

This is made entirely using Godot 4.3, which GDScript (all statically-typed) as the language. The project is organized into the following folders:
- Assets:
  - Fonts:
    = The main font used by the app (JetBrains Mono Light (Light))
  - Icons
    = All the icons (.svg) used by the app, when the app is launched these are all read and imported into a dictionary with their names as the keys
  = Everything else is misc. assets including Styleboxes and ButtonGroups
- Exported:
  = Latest stable version of the app for all available platforms (Windows & Linux)
- Scenes:
  = All the scene files.
- Scripts:
  - Globals:
    = All the global/manager scripts
  = All other script files.

## Data Management ##

When launched the app will check for 'NMP_Data.dat' in the same directory for all of its information, including Artist, Album, Song, Playlist and User data, this is also where data will be saved. Only the directory the app is located in will be checked, so moving the app will require the data file to be moved to continue using said data. You can create backups of your data inside the app which will be named 'NMP_Data_{unix_time_according_to_system}.dat' and saved in the same directory as where the app is.
The data is saved using Godot's ConfigFile class.