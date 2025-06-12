Detecting Zone Changes in Path of Exile: A Technical Overview
Detecting when a player moves between zones in Path of Exile can be accomplished by monitoring the game's client log file in real-time. This method relies on a read-only approach and does not directly interact with the game client, which is a crucial factor for compliance with Grinding Gear Games' Terms of Service.
1. Locating the Client Log File
The primary source of this information is the Client.txt file. This plain text file is located in the logs subdirectory of your Path of Exile installation folder. The default paths are typically:
Standalone Client: C:\Program Files (x86)\Grinding Gear Games\Path of Exile\logs\Client.txt
Steam Client: C:\Program Files (x86)\Steam\steamapps\common\Path of Exile\logs\Client.txt
The exact location may vary depending on the drive where the game was installed.
2. Identifying Zone Change Log Entries
When a player changes zones, the game client writes specific lines to the Client.txt file. A script can "watch" this file for new entries and parse them to identify these specific events. The key log message to monitor contains the phrase:
: You have entered

A complete log entry for a zone change will look similar to this, including a timestamp and other information:
2023/10/27 15:30:00 1234567 89a [INFO Client 1234] : You have entered The Coast.

By detecting any new line that includes ": You have entered", an external tool can reliably determine that a zone transition has just occurred and identify the name of the new area. Other related messages, such as those indicating a connection to an instance server, also appear in the log and can provide context, but the "You have entered" line is the most direct confirmation.
3. Technical Implementation (AutoHotkey Example)
An AutoHotkey script can implement this detection using a file-reading loop. The basic principle is to periodically read the last line of the Client.txt file and check if it contains the target string.
Here is a conceptual code snippet illustrating the logic:
AutoHotkey
#Persistent
SetTimer, WatchLog, 250 ; Check the log file every 250 milliseconds
Return

WatchLog:
    ; Path to your Client.txt file
    logPath := "C:\Program Files (x86)\Grinding Gear Games\Path of Exile\logs\Client.txt"
    
    ; Read only the last line of the file
    FileRead, lastLine, % "*t " logPath

    ; A global variable to prevent re-triggering on the same line
    global lastZoneEvent
    
    ; Check if the last line indicates a zone change and is new
    if (InStr(lastLine, ": You have entered") && lastLine != lastZoneEvent)
    {
        lastZoneEvent := lastLine
        
        ; Extract the zone name
        ; This is a simplified extraction and may need refinement
        RegExMatch(lastLine, ": You have entered (.*)\.", zone)
        
        ; Trigger an action, e.g., show an overlay or a message
        ToolTip, Entered: %zone1%
    }
Return

This script sets a timer to repeatedly execute the WatchLog subroutine. The subroutine reads the last line of Client.txt, and if it finds the key phrase and hasn't processed that exact line before, it extracts the zone name and performs an action. This read-only method is how most third-party leveling guides and informational overlays function without violating game rules.

