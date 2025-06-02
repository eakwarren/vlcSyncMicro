import MuseScore 3.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import MuseScore.Playback 1.0 //loaded dynamically when testing playback model
import Muse.UiComponents 1.0
import Muse.Ui 1.0




MuseScore {
    version: "0.9"
    id: vlcSyncPlugin
    description: "Syncs VLC media player to MuseScore Studio playback"
    
    requiresScore: true
    pluginType: "dialog"
    
    width: 165
    height: 50
    visible: true
    
    // Properties for 4.4
    title:"vlcSyncMicro"
    categoryCode:"playback"
    thumbnailName:"vlc.png"
    
    // VLC connection parameters (match your VLC's HTTP interface settings)
    property string vlcHost: "127.0.0.1"
    property int vlcPort: 8080
    property string vlcPassword: "Test"
    
    // Plugin state properties
    property bool mssIsPlaying: false
    property bool mssWasPlayingPreviously: false
    property int offsetHours: 0
    property int offsetMinutes: 0
    property int offsetSeconds: 0
    property int offsetMilliseconds: 025
    property int offsetTotalSeconds: 0
    property var playbackModel: null
    property real previousPlaybackPosition: 0
    property var statusColor: ui.theme.fontPrimaryColor
    property string statusMessage: ""
    property bool useDirectPlaybackAPI: false


    
    // Initialize plugin
    Component.onCompleted: {

        console.log("Hello VLC Sync Micro");

        mssCheckVersion();
        
        try { // Try to use the direct playback API

            console.log("Testing playback model...");

            playbackModel = Qt.createQmlObject(
                'import MuseScore.Playback 1.0
                 PlaybackToolBarModel {}',
                vlcSyncPlugin,
                "dynamicPlaybackModel"
            );
            
            if (playbackModel) {
                playbackModel.load();
                useDirectPlaybackAPI = true;
                console.log("Loaded playback model");
                statusMessage = "Loaded playback model";
            }

        } catch (error) {

            console.log("Error loading playback model: " + error);
        }

    }

    onRun: {

        mssSetupPlaybackMonitoring();

    }
    


    /*===============
        Functions
    ================*/

    function getOffsetTotalSeconds() {

        offsetTotalSeconds = (offsetHours * 3600) +
                             (offsetMinutes * 60) +
                             offsetSeconds +
                             Math.round(offsetMilliseconds / 1000); // round to nearest second

        return offsetTotalSeconds

    }

    function jumpToCurrentSecond() { // floor to nearest second

        // Get current time from playback model
        var currentTime = playbackModel.playTime;
        var hours = currentTime.getHours();
        var minutes = currentTime.getMinutes();
        var seconds = currentTime.getSeconds();
        // don't get milliseconds (offset)
        console.log("Jumping to current second: " + hours + ":" + minutes + ":" + seconds + ".00");

        // Calculate total seconds
        var totalSeconds = hours * 3600 + minutes * 60 + seconds;
        offsetTotalSeconds = getOffsetTotalSeconds(); // getOffsetTotalSeconds already rounded

        // Apply video offset for VLC positioning
        var adjustedSeconds = totalSeconds + offsetTotalSeconds;
        console.log("Applying offset: " + offsetTotalSeconds + " seconds, New VLC position: " + adjustedSeconds);

        // Calculate the next second (ceiling of current time)
        var nextSecond = Math.ceil(adjustedSeconds);
        var millisecondsToNextSecond = ((nextSecond - adjustedSeconds) * 1000);

        vlcSeek(nextSecond);

        console.log("Next second: " + nextSecond + ", ms until then: " + millisecondsToNextSecond);

        // Set up a timer to start playback at the exact next even second
        var playTimer = Qt.createQmlObject(
            'import QtQuick 2.2; Timer { interval: ' + Math.floor(millisecondsToNextSecond) + '; running: true; repeat: false; }',
            vlcSyncPlugin, "syncPlayTimer"
        );

        // Trigger play at the next second
        playTimer.triggered.connect(function() {

            // Position MuseScore at the same time (without offset)
            var newTime = new Date();
            newTime.setHours(hours);
            newTime.setMinutes(minutes);
            newTime.setSeconds(seconds);
            newTime.setMilliseconds(0); // Set to exact second

            // Set the play time directly
            playbackModel.playTime = newTime;

            statusMessage = "Jumped to current time";
            settingsStatusMessage.text = statusMessage;

            console.log("Next second reached, starting VLC");
            vlcPlay();
            playTimer.destroy();

            statusMessage = "VLC synced";
            settingsStatusMessage.text = statusMessage;
        });
    }

    function mssCheckVersion() {

        if (mscoreMajorVersion < 4) {

            statusMessage = "Plugin for MuseScore 4.x";
            statusColor = "red";
            settingsStatusMessage.text = statusMessage;
            settingsStatusMessage.color = statusColor;

        } else {

            // For 4.0-4.3 compatibility
            if (mscoreMajorVersion >= 4 && mscoreMinorVersion <= 3) {

                // No space between property name and colon is critical for 4.4+ declared above
                title = "VLC Sync Micro";
                categoryCode = "playback";
                thumbnailName = "vlc.png"

            }
        }
    }

    function mssGetCurrentPlaybackTimeInSeconds() {

        var currentTime = playbackModel.playTime;
        var hours = currentTime.getHours();
        var minutes = currentTime.getMinutes();
        var seconds = currentTime.getSeconds();
        var ms = currentTime.getMilliseconds();

        return hours * 3600 + minutes * 60 + seconds + (ms / 1000);

    }

    function mssSetupPlaybackMonitoring() {

        var timer = Qt.createQmlObject(`
            import QtQuick 2.15

            Timer {
                interval: 100 // ms
                running: true
                repeat: true

                property bool lastPlayingState: false

                onTriggered: {

                    if (!playbackModel || !playbackModel.items || playbackModel.items.length < 2) return;

                    // Get the play/pause button (Item 1), check icon value to determine play state
                    var playButton = playbackModel.items[1];
                    var currentlyPlaying = (playButton.icon === 62409); // Pause icon indicates playing

                    var currentPosition = mssGetCurrentPlaybackTimeInSeconds();

                    // Check for significant time jump while playing
                    if (currentlyPlaying && mssWasPlayingPreviously && Math.abs(currentPosition - previousPlaybackPosition) >= 1) {

                        console.log("Significant time jump detected: " +
                           Math.abs(currentPosition - previousPlaybackPosition) +
                           " seconds. Re-syncing.");

                        // Re-sync by jumping to current second
                        jumpToCurrentSecond();

                    }

                    // Update tracking variables
                    if (lastPlayingState !== currentlyPlaying) {

                        mssIsPlaying = currentlyPlaying;
                        console.log("Playback state changed: " + (mssIsPlaying ? "now playing" : "now stopped"));

                        // Trigger VLC sync when MuseScore starts playing
                        if (mssIsPlaying) {

                            syncWithMuseScorePlayback();

                        } else if (!mssIsPlaying) {

                            vlcForcePause();
                        }

                        lastPlayingState = currentlyPlaying;
                    }

                    // Always update previous position if playing
                    if (currentlyPlaying) {

                        previousPlaybackPosition = currentPosition;
                        mssWasPlayingPreviously = true;

                    } else {

                        mssWasPlayingPreviously = false;

                    }
                }
            }
        `, parent, "mssPlaybackMonitoringTimer");
    }

    function syncWithMuseScorePlayback() {

        var playbackTime = mssGetCurrentPlaybackTimeInSeconds(); // ms not rounded
        offsetTotalSeconds = getOffsetTotalSeconds(); // getOffsetTotalSeconds ms already rounded

        // Apply VLC forward offset
        var adjustedSeconds = playbackTime + offsetTotalSeconds;
        console.log("Synchronizing VLC to " + adjustedSeconds + " seconds (with offset: " + offsetTotalSeconds + ")");

        // Calculate the next second (ceiling of current time)
        var nextSecond = Math.ceil(adjustedSeconds);
        var millisecondsToNextSecond = ((nextSecond - adjustedSeconds) * 1000);

        vlcSeek(nextSecond);

        console.log("Next second: " + nextSecond + ", ms until then: " + millisecondsToNextSecond);

        // Set up a timer to start playback at the exact next even second
        var playTimer = Qt.createQmlObject(
            'import QtQuick 2.2; Timer { interval: ' + Math.floor(millisecondsToNextSecond) + '; running: true; repeat: false; }',
            vlcSyncPlugin, "syncPlayTimer"
        );

        // Trigger play at the next second
        playTimer.triggered.connect(function() {

            console.log("Next second reached, starting VLC");
            vlcPlay();
            playTimer.destroy();

            statusMessage = "VLC synced";
            settingsStatusMessage.text = statusMessage;

        });
    }

    /*
    This is a shortened list from /Applications/VLC.app/Contents/MacOS/share/lua/http/requests/README.txt
    which describes commands available through the requests/ files. Additional notes for some items
    pulled from https://wiki.videolan.org/VLC_HTTP_requests/

    Lines starting with < describe what the page sends back
    Lines starting with > describe what you can send to the page

    All parameters need to be URL encoded.
    Examples:
     # -> %23
     % -> %25
     + -> %2B
     space -> +

    status.xml or status.json
    ===========
    < Get VLC status information, current item info and meta.
    < Get VLC version, and http api version

    > play playlist item <id>:  NB: ?command=pl_play also works (no ID needed).
     ?command=pl_play&id=<id>

    > toggle pause: If current state was 'stop', play item <id>, if no <id> specified, play current item.
      If no current item, play 1st item in the playlist:
      NB: ?command=pl_pause seems largely ignored ? stream often continues. (May depend on whether camera obeys pause command.
      This command may only cause a PAUSE to be sent out to the video stream source, so result will depend on whether source obeys.)
      ?command=pl_pause&id=<id>

    > resume playback if paused, else do nothing
      ?command=pl_forceresume

    > pause playback, do nothing if already paused
      ?command=pl_forcepause

    > stop playback: NB: seems not to clear the playlist. If in doubt clear the playlist and reload to start.
      ?command=pl_stop

    > toggle loop:
      ?command=pl_loop

    > seek to <val>:
      ?command=seek&val=<val>
      Allowed values are of the form:
        [+ or -][<int><H or h>:][<int><M or m or '>:][<int><nothing or S or s or ">]
        or [+ or -]<int>%
        (value between [ ] are optional, value between < > are mandatory)
      examples:
        1000 -> seek to the 1000th second
        +1H:2M -> seek 1 hour and 2 minutes forward
        -10% -> seek 10% back
    */

    function vlcPlay() {

        vlcSendCommand("pl_play");

    }

    function vlcForcePause() {

        vlcSendCommand("pl_forcepause"); // pause playback, do nothing if already paused (regular pl_pause not reliable)

    }

    function vlcForceResume() {

        vlcSendCommand("pl_forceresume") //resume playback if paused, else do nothing

    }

    function vlcSendCommand(command, params) {

        // Create a timer to add the delay
        var timer = Qt.createQmlObject(`
            import QtQuick 2.15
            Timer {
                interval: ${offsetMilliseconds}
                running: true
                onTriggered: {
                    var xhr = new XMLHttpRequest();
                    var url = "http://${vlcHost}:${vlcPort}/requests/status.xml?command=${command}";
                    ${params ? `url += "&${params}";` : ""}

                    xhr.open("GET", url, true);
                    xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(":" + vlcPassword));
                    xhr.send();

                    destroy(); // Clean up the timer
                }
            }
        `, vlcSyncPlugin, "vlcCommandTimer");

    }

    function vlcSeek(seconds) {

        // Use direct seconds-based positioning
        vlcSendCommand("seek", "val=" + seconds);

    }

    function vlcTestConnection() {

        statusMessage = "Testing connection...";
        statusColor = ui.theme.fontPrimaryColor;

        settingsStatusMessage.text = statusMessage;


        var xhr = new XMLHttpRequest();
        var url = "http://" + vlcHost + ":" + vlcPort + "/requests/status.xml";

        console.log("Testing connection to " + url);
        xhr.onreadystatechange = function() {

            if (xhr.readyState === XMLHttpRequest.DONE) {

                if (xhr.status === 200) {

                    statusMessage = "Connected to VLC";

                } else {

                    statusMessage = "Can't find VLC!";
                    statusColor = "red";

                }

                settingsStatusMessage.text = statusMessage;
                settingsStatusMessage.color = statusColor;

            }
        };

        xhr.ontimeout = function() {

                statusMessage = "Test timed out!";
                statusColor = "red";

                settingsStatusMessage.text = statusMessage;
                settingsStatusMessage.color = statusColor;

            };

        xhr.open("GET", url, true);
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(":" + vlcPassword));
        xhr.timeout = 10000; // 10 seconds
        xhr.send();

    }



    /*===================
        UI Layout
    ===================*/

    Item {
        id: mainItem
        anchors.fill: parent
        anchors.margins: 3
        anchors.topMargin: 0

        Column {
            id: mainColumn
            spacing: 0
            width: parent.width
            height: parent.height

            RowLayout {
                height: 30
                Layout.fillWidth: true

                FlatButton {
                    id: test
                    toolTipTitle: "Test VLC Connection"
                    icon: IconCode.UPDATE
                    isNarrow: true
                    transparent: true
                    Layout.alignment: Qt.AlignLeft
                    onClicked: {
                        vlcTestConnection();
                        settingsStatusMessage.text = statusMessage;
                    }
                }

                FlatButton {
                    id: offset
                    toolTipTitle: "Set Video Offset"
                    toolTipDescription: "Set offset (ms for playback lag)"
                    icon: IconCode.CONTINUOUS_VIEW
                    transparent: true
                    Layout.alignment: Qt.AlignLeft
                }

                TimeInputField {
                    id: timeField
                    Layout.alignment: Qt.AlignLeft
                    width: 94
                    maxMillisecondsNumber: 999
                    time: new Date(0, 0, 0, 0, 0, 0, 025) // y, m, d, h, m, s, ms
                    onTimeEdited: function(newTime) {
                        console.log("TimeInputField Edited! New value:", newTime);

                        if (!(newTime instanceof Date) || isNaN(newTime.getTime())) {
                            console.log("Error: Invalid time value from TimeInputField");
                            return;
                        }

                        // Explicitly set the timeField's time to ensure it's updated
                        timeField.time = newTime;

                        offsetHours = newTime.getHours();
                        offsetMinutes = newTime.getMinutes();
                        offsetSeconds = newTime.getSeconds();
                        offsetMilliseconds = newTime.getMilliseconds();

                        // Stringify log to match display
                        console.log("Settings Saved. New Offset: ",
                                    String(offsetHours).padStart(1, "0") + ":" +
                                    String(offsetMinutes).padStart(2, "0") + ":" +
                                    String(offsetSeconds).padStart(2, "0") + ":" +
                                    String(offsetMilliseconds).padStart(3, "0")
                                    );
                    }
                }

            }

            RowLayout {
                width: parent.width
                height: 12

                StyledTextLabel {
                    id: settingsStatusMessage
                    Layout.alignment: Qt.AlignLeft
                    // anchors.right: saveButton.left
                    Layout.rightMargin: 10
                    Layout.leftMargin: 6
                    text: statusMessage
                    color: statusColor
                    elide: Text.ElideRight
                }
            }

        }
    }
}        
