; AutoHotkey v1.1 Required
#Requires AutoHotkey v1.1.24+
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
    ; Detect POE installation path first
    Gosub, DetectPOEPath
    
    ; Only proceed if we found/selected the log file
    if (LogFilePath != "")
    {
        ; Create overlay GUI
        Gosub, CreateOverlay
        
        ; Start log monitoring
        SetTimer, WatchLog, 250
        
        ; Start overlay positioning timer
        SetTimer, CheckPOEPosition, 1000
        
        ; Show build selection (will load build data when selected)
        Gosub, ShowBuildSelector
    }
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
            ; Check file size before using it
            FileGetSize, FileSize, %TestPath%
            FileSizeMB := Round(FileSize / (1024 * 1024), 2)
            
            ; If file is over 50MB, suggest renaming to start fresh
            if (FileSize > 52428800)  ; 50MB in bytes
            {
                MsgBox, 48, Large Client.txt File, Client.txt is %FileSizeMB%MB which may cause performance issues.`n`nFor best performance, consider:`n1. Close Path of Exile`n2. Rename Client.txt to Client_old.txt`n3. Restart Path of Exile (creates fresh Client.txt)`n`nContinue with current file?, 4
                IfMsgBox No
                {
                    continue  ; Try next path
                }
            }
            
            LogFilePath := TestPath
            ; Show brief confirmation only
            ToolTip, Found Client.txt (%FileSizeMB%MB) - Starting monitoring..., 0, 0
            SetTimer, RemoveTooltip, 2000
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
            ; Check file size for manually selected file too
            FileGetSize, FileSize, %LogFilePath%
            FileSizeMB := Round(FileSize / (1024 * 1024), 2)
            
            if (FileSize > 52428800)  ; 50MB in bytes
            {
                MsgBox, 48, Large Client.txt File, Selected Client.txt is %FileSizeMB%MB which may cause performance issues.`n`nFor best performance, consider:`n1. Close Path of Exile`n2. Rename Client.txt to Client_old.txt`n3. Restart Path of Exile (creates fresh Client.txt)`n4. Select the new Client.txt`n`nContinue with current file?, 4
                IfMsgBox No
                {
                    ExitApp
                }
            }
            
            ; Show brief confirmation for manual selection
            ToolTip, Selected Client.txt (%FileSizeMB%MB) - Starting monitoring..., 0, 0
            SetTimer, RemoveTooltip, 2000
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
    
    ; Create modern styled overlay with WebBrowser
    Gui, +AlwaysOnTop +ToolWindow -Caption -Border +LastFound
    WinSet, Transparent, 240
    
    ; Set background color
    Gui, Color, 0x0D1117
    
    ; Add WebBrowser control for HTML content
    Gui, Add, ActiveX, x0 y0 w290 h160 vWebBrowser, Shell.Explorer
    
    ; Control buttons with modern styling
    Gui, Font, s8 Normal, Segoe UI
    Gui, Add, Button, x15 y165 w45 h22 gPrevStep, < Prev
    Gui, Add, Button, x65 y165 w45 h22 gNextStep, Next >
    Gui, Add, Button, x115 y165 w45 h22 gChangeBuild, Build
    Gui, Add, Button, x165 y165 w40 h22 gToggleOverlay, Hide
    Gui, Add, Button, x210 y165 w35 h22 gExitApp, Exit
    
    ; Initialize the WebBrowser with local HTML file
    Gosub, InitializeWebBrowser
    
    ; Position overlay to detect POE and stay on top
    Gosub, PositionOverlay
    OverlayGui := WinExist("POE Leveling Overlay")
Return

InitializeWebBrowser:
    ; Get the full path to the HTML file
    HtmlPath := A_ScriptDir . "\overlay.html"
    
    ; Navigate to the local HTML file
    WebBrowser.Navigate("file:///" . StrReplace(HtmlPath, "\", "/"))
    
    ; Wait for the page to load completely
    while (WebBrowser.ReadyState != 4)
        Sleep, 50
    
    ; Wait a bit more for JavaScript to initialize
    Sleep, 200
    
    ; Wait for document to be complete
    while (WebBrowser.document.readyState != "complete")
        Sleep, 50
    
    ; Additional wait for JavaScript functions to be available
    Sleep, 300
    
    try {
        ; Disable context menu and selection
        WebBrowser.document.oncontextmenu := "return false"
        WebBrowser.document.onselectstart := "return false"
        WebBrowser.document.ondragstart := "return false"
        
        ; Test if updateOverlay function is available
        WebBrowser.document.parentWindow.execScript("if (typeof updateOverlay === 'undefined') { window.updateOverlay = function() { console.log('updateOverlay not ready'); }; }")
    } catch e {
        ; If there's an error, continue anyway
    }
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
    
    ; Load the build data and update display
    Gosub, LoadBuildData
    
    ; Show confirmation tooltip
    ToolTip, Loaded: %CurrentBuild%, 0, 0
    SetTimer, RemoveTooltip, 2000
    
    ; Update display
    Gosub, UpdateZoneInfo
Return

UpdateZoneInfo:
    ; Update overlay with zone-based progression information
    if (BuildData.steps.Length() > 0)
    {
        ; Get current information with debug info
        zoneText := "Area: " . CurrentZone
        questInfo := GetCurrentQuestInfo()
        gemInfo := GetCurrentGemInfo()
        gemName := GetCurrentGemName()
        vendorInfo := GetCurrentVendorInfo()
        recentLogText := GetRecentLogText()
        
        ; Add debug info to vendor line temporarily
        vendorInfo := "Following: " . BuildData.name . " (" . BuildData.steps.Length() . " steps)"
    }
    else
    {
        ; Fallback display
        zoneText := "Area: Unknown"
        questInfo := "Next: Select a build"
        gemInfo := "Gems: None available"
        gemName := ""
        vendorInfo := "Vendor: No build loaded"
        recentLogText := "Recent: No log data"
    }
    
    ; Update the HTML content via JavaScript
    Gosub, UpdateWebBrowserContent
Return

UpdateWebBrowserContent:
    ; Check if WebBrowser is ready and document exists
    try {
        if (WebBrowser.ReadyState = 4 && WebBrowser.document.readyState = "complete")
        {
            ; Escape quotes and other special characters for JavaScript
            zoneTextEscaped := StrReplace(StrReplace(StrReplace(zoneText, "\", "\\"), """", "\"""), "`n", "\n")
            questInfoEscaped := StrReplace(StrReplace(StrReplace(questInfo, "\", "\\"), """", "\"""), "`n", "\n")
            gemInfoEscaped := StrReplace(StrReplace(StrReplace(gemInfo, "\", "\\"), """", "\"""), "`n", "\n")
            vendorInfoEscaped := StrReplace(StrReplace(StrReplace(vendorInfo, "\", "\\"), """", "\"""), "`n", "\n")
            recentLogTextEscaped := StrReplace(StrReplace(StrReplace(recentLogText, "\", "\\"), """", "\"""), "`n", "\n")
            gemNameEscaped := StrReplace(StrReplace(StrReplace(gemName, "\", "\\"), """", "\"""), "`n", "\n")
            
            ; First check if the function exists, if not create a simple fallback
            jsCode := "if (typeof updateOverlay === 'undefined') { window.updateOverlay = function(zone, quest, gems, vendor, recent, gemName) { try { if (document.getElementById('zone')) document.getElementById('zone').innerHTML = zone; if (document.getElementById('quest')) document.getElementById('quest').innerHTML = quest; if (document.getElementById('gem-text')) document.getElementById('gem-text').innerHTML = gems; if (document.getElementById('vendor')) document.getElementById('vendor').innerHTML = vendor; if (document.getElementById('recent')) document.getElementById('recent').innerHTML = recent; } catch(e) { } }; }"
            WebBrowser.document.parentWindow.execScript(jsCode)
            
            ; Now call the function
            jsCommand := "updateOverlay(""" . zoneTextEscaped . """, """ . questInfoEscaped . """, """ . gemInfoEscaped . """, """ . vendorInfoEscaped . """, """ . recentLogTextEscaped . """, """ . gemNameEscaped . """)"
            WebBrowser.document.parentWindow.execScript(jsCommand)
        }
    } catch e {
        ; If there's an error, try a simple fallback update
        try {
            WebBrowser.document.getElementById("zone").innerHTML := zoneText
            WebBrowser.document.getElementById("quest").innerHTML := questInfo
            WebBrowser.document.getElementById("gem-text").innerHTML := gemInfo
            WebBrowser.document.getElementById("vendor").innerHTML := vendorInfo
            WebBrowser.document.getElementById("recent").innerHTML := recentLogText
        } catch e2 {
            ; Last resort - just continue silently
        }
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
    ; Show previous step in build progression
    if (BuildData.steps.Length() > 0)
    {
        currentStep := GetCurrentProgressionStep()
        if (currentStep > 1)
        {
            prevStep := currentStep - 1
            step := BuildData.steps[prevStep]
            ToolTip, Previous: %step.title% (%step.zone%), 0, 0
            SetTimer, RemoveTooltip, 3000
        }
        else
        {
            ToolTip, Already at first step, 0, 0
            SetTimer, RemoveTooltip, 2000
        }
    }
Return

NextStep:
    ; Show next step in build progression
    if (BuildData.steps.Length() > 0)
    {
        currentStep := GetCurrentProgressionStep()
        if (currentStep < BuildData.steps.Length())
        {
            nextStep := currentStep + 1
            step := BuildData.steps[nextStep]
            ToolTip, Next: %step.title% (%step.zone%), 0, 0
            SetTimer, RemoveTooltip, 3000
        }
        else
        {
            ToolTip, Already at final step, 0, 0
            SetTimer, RemoveTooltip, 2000
        }
    }
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
        overlayHeight := 195
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
            overlayHeight := 195
            overlayX := poeX + poeW - overlayWidth - IndentAmount
            overlayY := poeY + 30
            Gui, Show, w%overlayWidth% h%overlayHeight% x%overlayX% y%overlayY%, POE Leveling Overlay
        }
        else
        {
            ; POE not found, hide overlay or position in corner
            Gui, Show, w290 h195 x50 y50, POE Leveling Overlay
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
    ; Find the NEXT quest/objective the player should be working towards
    if (BuildData.steps.Length() = 0)
        return "Quest: Select a build"
    
    ; Find current step based on progression
    currentStep := GetCurrentProgressionStep()
    
    ; If we're at step 1, show step 1 info
    if (currentStep = 1)
    {
        step := BuildData.steps[1]
        return "Next: " . step.title . " (" . step.zone . ")"
    }
    
    ; Otherwise show the next step
    nextStep := currentStep + 1
    if (nextStep <= BuildData.steps.Length())
    {
        step := BuildData.steps[nextStep]
        return "Next: " . step.title . " (" . step.zone . ")"
    }
    else
    {
        return "Quest: Build path completed!"
    }
}

FindAvailableGems() {
    ; Find the NEXT gems the player should be working towards
    if (BuildData.steps.Length() = 0)
        return "Gems: None available"
    
    ; Find current step and look for gem rewards
    currentStep := GetCurrentProgressionStep()
    
    ; First check current step for available gems
    if (currentStep <= BuildData.steps.Length())
    {
        step := BuildData.steps[currentStep]
        if (step.gems_available.Length() > 0)
        {
            gem := step.gems_available[1]
            return "Available: " . gem.name . " (" . step.zone . ")"
        }
    }
    
    ; Look for next step with gems (starting from current+1)
    Loop, % (BuildData.steps.Length() - currentStep)
    {
        stepIndex := currentStep + A_Index
        if (stepIndex > BuildData.steps.Length())
            break
            
        step := BuildData.steps[stepIndex]
        if (step.gems_available.Length() > 0)
        {
            gem := step.gems_available[1]
            return "Next Gems: " . gem.name . " from " . step.zone
        }
    }
    
    return "Gems: No more gems in build path"
}

GetCurrentGemName() {
    ; Get the name of the current/next gem for image display
    if (BuildData.steps.Length() = 0)
        return ""
    
    ; Find current step and look for next gem rewards
    currentStep := GetCurrentProgressionStep()
    
    ; Look for next step with gems
    Loop, % (BuildData.steps.Length() - currentStep)
    {
        stepIndex := currentStep + A_Index
        if (stepIndex > BuildData.steps.Length())
            break
            
        step := BuildData.steps[stepIndex]
        if (step.gems_available.Length() > 0)
        {
            gem := step.gems_available[1]
            return gem.name
        }
    }
    
    ; Check current step if no future gems
    if (currentStep <= BuildData.steps.Length())
    {
        step := BuildData.steps[currentStep]
        if (step.gems_available.Length() > 0)
        {
            gem := step.gems_available[1]
            return gem.name
        }
    }
    
    return ""
}

GetCurrentProgressionStep() {
    ; Determine the current step based on zone history and current zone
    if (BuildData.steps.Length() = 0)
        return 0
    
    ; Default to step 1 if we haven't been anywhere yet
    maxCompletedStep := 1
    
    ; Find the highest step we've reached based on zones visited
    Loop, % BuildData.steps.Length()
    {
        stepIndex := A_Index
        step := BuildData.steps[stepIndex]
        
        ; Check if we've been to this zone (current zone or in history)
        if (InStr(CurrentZone, step.zone_trigger))
        {
            if (stepIndex > maxCompletedStep)
                maxCompletedStep := stepIndex
        }
        else
        {
            ; Check zone history for this zone
            Loop, % ZoneHistory.Length()
            {
                historyZone := ZoneHistory[A_Index]
                if (InStr(historyZone, step.zone_trigger))
                {
                    if (stepIndex > maxCompletedStep)
                        maxCompletedStep := stepIndex
                    break
                }
            }
        }
    }
    
    return maxCompletedStep
}

; Exit handlers
GuiClose:
ExitApp

^Esc::ExitApp