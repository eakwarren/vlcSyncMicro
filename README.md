# vlcSyncMicro
 Sync MuseScore Studio 4.5+ to VLC video player 3.0.21+
 
<img width="165" alt="vlcSyncMicro" src="https://github.com/user-attachments/assets/f7305873-3c9e-439b-863b-8dc2c005cb71" />

<img width="1307" alt="Screenshot 2025-04-10 at 9 06 17 PM" src="https://github.com/user-attachments/assets/ed0040bd-2458-4803-a51c-7524e872ebc6" />


Developed with ❤️ by Eric Warren


## Setup
1. Unzip the latest release to your ~/Documents/Musescore4/Plugins directory.

2. In [VLC](https://www.videolan.org/vlc/) click Settings > Interface > Enable HTTP web interface. Check the box for HTTP web interface and set the password to "Test" (or your own password if you change it in VLC Sync Micro.qml).

Enable the plugin in MuseScore Studio under Plugins > Manage plugins. Click the plugin and click Enable. Perhaps set a shortcut in Preferences > Shortcuts. (I use Cmd+Shift+M.) Load a score and open the plugin with the shortcut or under Plugins > Playback. In the Micro window, set an offset if needed.


## Known Issues
View known issues on [GitHub](https://github.com/eakwarren/vlcSyncMicro/issues)

At this time, VLC doesn't support timecode so playback sync won't be frame accurate.


## To Do
If you have a suggestion, or find a bug, please report it on [GitHub](https://github.com/eakwarren/vlcSyncMicro/issues). I don’t promise a fix or tech support, but I’m happy to take a look. 🙂


## Special Thanks
_“If I have seen further, it is by standing on the shoulders of Giants.” ~Isaac Newton_

MuseScore Studio developers, wherever they may roam.

L'Moose on the [MuseScore Forum](https://musescore.org/en/node/376476) aka ModernMozart on the MuseScore Discord [MuseScore Discord](https://discord.gg/CZnPNyswWq) for writing the original big brother to this micro-sized plugin.



## Release Notes
v0.9 6/2/25 Initial release.
