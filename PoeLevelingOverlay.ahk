#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%

; Include JSON loader
#Include JsonLoader.ahk

; Global variables
LogFilePath := ""
CurrentBuild := ""
OverlayVisible := true
LastZoneEvent := ""
BuildData := {}
CurrentZone := "Unknown"
ZoneHistory := []
CurrentAct := 1
LastTownZone := ""
RecentLogLines := []

; GUI Variables
OverlayGui := ""
StepText := ""
GearText := ""
CurrencyText := ""
ZoneText := ""
TriggerText := ""

; Initialize the application
Gosub, InitializeApp

InitializeApp:
    ; Detect POE installation path
    Gosub, DetectPOEPath
    
    ; Load build data
    Gosub, LoadBuildData
    
    ; Create overlay GUI
    Gosub, CreateOverlay
    
    ; Start log monitoring
    SetTimer, WatchLog, 250
    
    ; Start overlay positioning timer
    SetTimer, CheckPOEPosition, 1000
    
    ; Show build selection
    Gosub, ShowBuildSelector
Return

DetectPOEPath:
    ; Try common POE installation paths
    PossiblePaths := ["C:\Program Files (x86)\Grinding Gear Games\Path of Exile\logs\Client.txt"
                    , "C:\Program Files (x86)\Steam\steamapps\common\Path of Exile\logs\Client.txt"
                    , "C:\Program Files\Grinding Gear Games\Path of Exile\logs\Client.txt"
                    , "C:\Program Files\Steam\steamapps\common\Path of Exile\logs\Client.txt"]
    
    Loop, % PossiblePaths.Length()
    {
        TestPath := PossiblePaths[A_Index]
        IfExist, %TestPath%
        {
            LogFilePath := TestPath
            MsgBox, 64, Found Client.txt, Found POE Client.txt at:`n%LogFilePath%`n`nStarting log monitoring..., 3
            break
        }
    }
    
    if (LogFilePath = "")
    {
        MsgBox, 48, Client.txt Not Found, Could not find POE Client.txt in standard locations.`nPlease select it manually.
        FileSelectFile, LogFilePath, 1, , Select Path of Exile Client.txt, Text Files (*.txt)
        if (LogFilePath = "")
        {
            MsgBox, 16, Error, Could not find POE Client.txt file. Exiting.
            ExitApp
        }
        else
        {
            MsgBox, 64, Found Client.txt, Found POE Client.txt at:`n%LogFilePath%`n`nStarting log monitoring..., 3
        }
    }
Return

LoadBuildData:
    ; Load the selected build data from JSON file
    if (CurrentBuild != "")
    {
        BuildData := LoadBuildFromJSON(CurrentBuild)
        
        ; Reset zone tracking when loading new build
        ZoneHistory := []
        CurrentAct := 1
        LastTownZone := ""
    }
Return

CreateOverlay:
    ; Destroy existing GUI if it exists
    Gui, Destroy
    
    ; Create fully transparent overlay with no title bar
    Gui, +AlwaysOnTop +ToolWindow -Caption -Border +LastFound
    WinSet, Transparent, 180
    
    ; Set darker background color
    Gui, Color, 0x1a1a1a
    
    ; Current zone display
    Gui, Font, s10 Bold cLime
    Gui, Add, Text, x15 y10 w260 h20 vCurrentZone, Area: Unknown
    
    ; Quest/Gem info
    Gui, Font, s9 Bold cYellow
    Gui, Add, Text, x15 y35 w260 h20 vQuestInfo, Next Quest: Select a build
    
    ; Gem selection info
    Gui, Font, s8 Normal cAqua
    Gui, Add, Text, x15 y55 w260 h30 vGemInfo, Gems: None available
    
    ; Vendor/Gear info
    Gui, Font, s8 Normal cSilver
    Gui, Add, Text, x15 y90 w260 h20 vVendorInfo, Vendor: Check for upgrades
    
    ; Recent log entries
    Gui, Font, s7 Normal cGray
    Gui, Add, Text, x15 y115 w260 h40 vRecentLog, Recent: No log data
    
    ; Smaller, modern buttons
    Gui, Font, s8
    Gui, Add, Button, x15 y190 w45 h20 gPrevStep, < Prev
    Gui, Add, Button, x65 y190 w45 h20 gNextStep, Next >
    Gui, Add, Button, x115 y190 w45 h20 gChangeBuild, Build
    Gui, Add, Button, x165 y190 w40 h20 gToggleOverlay, Hide
    Gui, Add, Button, x210 y190 w35 h20 gExitApp, Exit
    
    ; Position overlay to detect POE and stay on top
    Gosub, PositionOverlay
    OverlayGui := WinExist("POE Leveling Overlay")
Return

ShowBuildSelector:
    ; Destroy existing build selector GUI if it exists
    Gui, BuildSelect:Destroy
    
    Gui, BuildSelect:Add, Text, x10 y10 w300 h20, Select your leveling build:
    
    Gui, BuildSelect:Add, Radio, x10 y40 w280 h20 vSelectTempArc Checked, Templar - Archmage Arc
    Gui, BuildSelect:Add, Radio, x10 y65 w280 h20 vSelectTempFire, Templar - Fire Caster (Armageddon Brand)
    Gui, BuildSelect:Add, Radio, x10 y90 w280 h20 vSelectWitchArc, Witch - Archmage Arc  
    Gui, BuildSelect:Add, Radio, x10 y115 w280 h20 vSelectWitchFire, Witch - Fire Caster (Armageddon Brand)
    Gui, BuildSelect:Add, Radio, x10 y140 w280 h20 vSelectRangerPoison, Ranger - Poisonous Concoction
    Gui, BuildSelect:Add, Radio, x10 y165 w280 h20 vSelectRangerLA, Ranger - Lightning Arrow
    Gui, BuildSelect:Add, Radio, x10 y190 w280 h20 vSelectDuelistMelee, Duelist - Melee (Sunder/Boneshatter)
    Gui, BuildSelect:Add, Radio, x10 y215 w280 h20 vSelectMarauderMelee, Marauder - Melee (Sunder/Boneshatter)
    Gui, BuildSelect:Add, Radio, x10 y240 w280 h20 vSelectShadowPoison, Shadow - Trap/Poison
    Gui, BuildSelect:Add, Radio, x10 y265 w280 h20 vSelectScionMelee, Scion - Melee
    
    Gui, BuildSelect:Add, Button, x100 y300 w100 h30 gSelectBuild, Start Leveling
    
    Gui, BuildSelect:Show, w320 h350, Select Build
Return

SelectBuild:
    Gui, BuildSelect:Submit
    
    ; Determine selected build
    if (SelectTempArc)
        CurrentBuild := "templar-arc"
    else if (SelectTempFire)
        CurrentBuild := "templar-fire"
    else if (SelectWitchArc)
        CurrentBuild := "witch-arc"
    else if (SelectWitchFire)
        CurrentBuild := "witch-fire"
    else if (SelectRangerPoison)
        CurrentBuild := "ranger-poison"
    else if (SelectRangerLA)
        CurrentBuild := "ranger-la"
    else if (SelectDuelistMelee)
        CurrentBuild := "duelist-melee"
    else if (SelectMarauderMelee)
        CurrentBuild := "marauder-melee"
    else if (SelectShadowPoison)
        CurrentBuild := "shadow-poison"
    else if (SelectScionMelee)
        CurrentBuild := "scion-melee"
    
    ; Load the build data
    Gosub, LoadBuildData
    Gosub, UpdateZoneInfo
Return

UpdateZoneInfo:
    ; Update overlay with zone-based progression information
    if (BuildData.steps.Length() > 0)
    {
        ; Update current zone display
        zoneText := "Area: " . CurrentZone
        GuiControl,, CurrentZone, %zoneText%
        
        ; Get quest/gem info for current progression
        questInfo := GetCurrentQuestInfo()
        GuiControl,, QuestInfo, %questInfo%
        
        ; Get gem selection info
        gemInfo := GetCurrentGemInfo()
        GuiControl,, GemInfo, %gemInfo%
        
        ; Get vendor/gear info
        vendorInfo := GetCurrentVendorInfo()
        GuiControl,, VendorInfo, %vendorInfo%
        
        ; Update recent log display
        recentLogText := GetRecentLogText()
        GuiControl,, RecentLog, %recentLogText%
    }
    else
    {
        ; Fallback display
        GuiControl,, CurrentZone, Area: Unknown
        GuiControl,, QuestInfo, Next Quest: Select a build
        GuiControl,, GemInfo, Gems: None available
        GuiControl,, VendorInfo, Vendor: N/A
        GuiControl,, RecentLog, Recent: No log data
    }
Return

WatchLog:
    if (LogFilePath = "")
        return
        
    ; Read the entire log file and get last few lines
    FileRead, LogContent, %LogFilePath%
    if (ErrorLevel)
        return
    
    ; Split into lines and get the last 20 lines to check for recent zone changes
    StringSplit, LogLines, LogContent, `n
    
    ; Check the last 20 lines for zone changes
    Loop, 20 {
        LineIndex := LogLines0 - A_Index + 1
        if (LineIndex <= 0)
            break
            
        CurrentLine := LogLines%LineIndex%
        
        ; Track recent log lines
        if (CurrentLine != "" && A_Index <= 5)
        {
            RecentLogLines.Insert(1, CurrentLine)
            if (RecentLogLines.Length() > 3)
                RecentLogLines.Pop()
        }
        
        ; Check if this is a zone change event we haven't seen
        if (InStr(CurrentLine, ": You have entered") && CurrentLine != LastZoneEvent)
        {
            LastZoneEvent := CurrentLine
            
            ; Debug: Show we found a zone change line
            ToolTip, Found zone line: %CurrentLine%, 0, 100
            SetTimer, RemoveDebugTooltip, 2000
            
            ; Extract zone name - format: "timestamp [INFO Client xxxxx] : You have entered ZoneName."
            RegExMatch(CurrentLine, "] : You have entered (.*?)\.", ZoneMatch)
            ZoneName := ZoneMatch1
            
            if (ZoneName != "")
            {
                ; Handle zone change
                Gosub, HandleZoneChange
                break
            }
        }
    }
Return

HandleZoneChange:
    ; Update current zone and add to history
    CurrentZone := ZoneName
    ZoneHistory.Insert(1, ZoneName)
    if (ZoneHistory.Length() > 10)
        ZoneHistory.Pop()
    
    ; Check if this is a town zone
    townZones := ["Lioneye's Watch", "The Forest Encampment", "The City of Sarn", "Highgate", "Overseer's Tower", "The Bridge Encampment", "Karui Shores", "The Templar Courts", "The Canals", "The Harbour Bridge"]
    Loop, % townZones.Length()
    {
        if (InStr(ZoneName, townZones[A_Index]))
        {
            LastTownZone := ZoneName
            break
        }
    }
    
    ; Update overlay information
    Gosub, UpdateZoneInfo
    
    ; Show zone change notification
    ToolTip, Entered: %ZoneName%, 0, 0
    SetTimer, RemoveTooltip, 3000
Return

RemoveTooltip:
    ToolTip
    SetTimer, RemoveTooltip, Off
Return

RemoveTooltip2:
    ToolTip,,,, 2
    SetTimer, RemoveTooltip2, Off
Return

RemoveTooltip3:
    ToolTip,,,, 3
    SetTimer, RemoveTooltip3, Off
Return

RemoveDebugTooltip:
    ToolTip,,,, 4
    SetTimer, RemoveDebugTooltip, Off
Return

; Hotkeys
F1::Gosub, PrevStep
F2::Gosub, NextStep
F3::Gosub, ToggleOverlay

PrevStep:
    ; Show previous zone from history
    if (ZoneHistory.Length() > 1)
    {
        ; Temporarily show info for previous zone
        tempZone := CurrentZone
        CurrentZone := ZoneHistory[2]
        Gosub, UpdateZoneInfo
        ToolTip, Showing info for: %CurrentZone%, 0, 0
        SetTimer, RestoreCurrentZone, 3000
    }
Return

NextStep:
    ; Manual refresh of zone info
    Gosub, UpdateZoneInfo
    ToolTip, Refreshed zone info, 0, 0
    SetTimer, RemoveTooltip, 2000
Return

RestoreCurrentZone:
    CurrentZone := ZoneHistory[1]
    Gosub, UpdateZoneInfo
    ToolTip
    SetTimer, RestoreCurrentZone, Off
Return

ToggleOverlay:
    if (OverlayVisible)
    {
        Gui, Hide
        OverlayVisible := false
        GuiControl,, ToggleOverlay, Show Overlay
    }
    else
    {
        Gui, Show
        OverlayVisible := true
        GuiControl,, ToggleOverlay, Hide Overlay
    }
Return

ChangeBuild:
    Gosub, ShowBuildSelector
Return

PositionOverlay:
    ; Try to position overlay over Path of Exile window ONLY
    WinGet, poeHwnd, ID, Path of Exile
    if (poeHwnd != "")
    {
        ; Get POE window position and size
        WinGetPos, poeX, poeY, poeW, poeH, Path of Exile
        
        ; Get screen width for 10% indent calculation
        SysGet, ScreenWidth, 0
        IndentAmount := ScreenWidth * 0.1
        
        ; Position overlay in top-right of POE window with 10% screen width indent from right edge
        overlayWidth := 290
        overlayHeight := 220
        overlayX := poeX + poeW - overlayWidth - IndentAmount
        overlayY := poeY + 30
        
        ; Ensure overlay stays within POE window bounds
        if (overlayX < poeX + 10)
            overlayX := poeX + 10
        if (overlayY < poeY + 10)
            overlayY := poeY + 10
        if (overlayX + overlayWidth > poeX + poeW)
            overlayX := poeX + poeW - overlayWidth - 10
            
        Gui, Show, w%overlayWidth% h%overlayHeight% x%overlayX% y%overlayY%, POE Leveling Overlay
    }
    else
    {
        ; POE not found, try other common window titles
        WinGet, poeHwnd, ID, ahk_exe PathOfExile.exe
        if (poeHwnd != "")
        {
            WinGetPos, poeX, poeY, poeW, poeH, ahk_exe PathOfExile.exe
            SysGet, ScreenWidth, 0
            IndentAmount := ScreenWidth * 0.1
            overlayWidth := 290
            overlayHeight := 220
            overlayX := poeX + poeW - overlayWidth - IndentAmount
            overlayY := poeY + 30
            Gui, Show, w%overlayWidth% h%overlayHeight% x%overlayX% y%overlayY%, POE Leveling Overlay
        }
        else
        {
            ; POE not found, hide overlay or position in corner
            Gui, Show, w290 h220 x50 y50, POE Leveling Overlay
        }
    }
Return

RepositionOverlay:
    Gosub, PositionOverlay
Return

ExitApp:
    ExitApp
Return

CheckPOEPosition:
    ; Automatically reposition overlay if POE window moves
    if (OverlayVisible)
    {
        WinGet, poeHwnd, ID, Path of Exile
        if (poeHwnd != "")
        {
            WinGetPos, poeX, poeY, poeW, poeH, Path of Exile
            WinGetPos, overlayX, overlayY, overlayW, overlayH, POE Leveling Overlay
            
            ; Calculate expected overlay position with new logic
            SysGet, ScreenWidth, 0
            IndentAmount := ScreenWidth * 0.1
            overlayWidth := 290
            expectedX := poeX + poeW - overlayWidth - IndentAmount
            expectedY := poeY + 30
            
            ; Ensure within POE window bounds
            if (expectedX < poeX + 10)
                expectedX := poeX + 10
            if (expectedY < poeY + 10)
                expectedY := poeY + 10
            if (expectedX + overlayWidth > poeX + poeW)
                expectedX := poeX + poeW - overlayWidth - 10
            
            ; Reposition if overlay is not where it should be (with small tolerance)
            if (Abs(overlayX - expectedX) > 30 || Abs(overlayY - expectedY) > 30)
            {
                WinMove, POE Leveling Overlay, , %expectedX%, %expectedY%
            }
        }
        else
        {
            ; Try alternative window detection
            WinGet, poeHwnd, ID, ahk_exe PathOfExile.exe
            if (poeHwnd != "")
            {
                Gosub, PositionOverlay
            }
        }
    }
Return

; Zone-based helper functions
GetCurrentQuestInfo() {
    if (BuildData.steps.Length() = 0)
        return "Next Quest: Select a build"
    
    ; Find relevant quest based on current zone and progression
    relevantQuest := FindRelevantQuest()
    return relevantQuest
}

GetCurrentGemInfo() {
    if (BuildData.steps.Length() = 0)
        return "Gems: None available"
    
    ; Find gems available for current progression
    gemInfo := FindAvailableGems()
    return gemInfo
}

GetCurrentVendorInfo() {
    if (LastTownZone = "")
        return "Vendor: Not in town"
    
    return "Vendor: Check " . LastTownZone . " for upgrades"
}

GetRecentLogText() {
    if (RecentLogLines.Length() = 0)
        return "Recent: No log data"
    
    recentText := "Recent: "
    Loop, % RecentLogLines.Length()
    {
        if (A_Index = 1)
        {
            ; Extract just the zone name from most recent entry
            RegExMatch(RecentLogLines[A_Index], "] : You have entered (.*?)\.", LogMatch)
            if (LogMatch1 != "")
                recentText .= LogMatch1
            else
                recentText .= "No zone data"
            break
        }
    }
    return recentText
}

FindRelevantQuest() {
    ; Based on current zone progression, find the next relevant quest
    if (InStr(CurrentZone, "Lioneye"))
        return "Quest: Talk to Tarkleigh"
    else if (InStr(CurrentZone, "Coast"))
        return "Quest: Enemy at the Gate"
    else if (InStr(CurrentZone, "Mud Flats"))
        return "Quest: Find the waypoint"
    else if (InStr(CurrentZone, "Ledge"))
        return "Quest: Progress to Prison"
    else
        return "Quest: Continue progression"
}

FindAvailableGems() {
    ; Look through build data to find gems available at current progression
    Loop, % BuildData.steps.Length()
    {
        step := BuildData.steps[A_Index]
        if (InStr(CurrentZone, step.zone) || InStr(LastTownZone, step.zone))
        {
            if (step.gems_available.Length() > 0)
            {
                gem := step.gems_available[1]
                return "Gems: " . gem.name . " available"
            }
        }
    }
    return "Gems: None for current area"
}

; Exit handlers
GuiClose:
ExitApp

^Esc::ExitApp