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
StateFilePath := A_ScriptDir . "\state.ini"

; State Machine Variables
CurrentStepIndex := 1
CurrentStepState := "STEP_WAITING_FOR_OBJECTIVE"
ZonesVisitedThisStep := []
StepStateHistory := []

; Town zones by act for enhanced detection
TownZonesByAct := {1: ["Lioneye's Watch"]
                 , 2: ["The Forest Encampment"] 
                 , 3: ["The City of Sarn", "The Sarn Encampment"]
                 , 4: ["Highgate"]
                 , 5: ["Overseer's Tower", "The Oriath Square"]
                 , 6: ["Lioneye's Watch"]}

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
        
        ; Load saved state if available
        Gosub, LoadState
        
        ; Reset zone tracking when loading new build if no saved state
        if (CurrentStepIndex = 1) {
            ZoneHistory := []
            CurrentAct := 1
            LastTownZone := ""
        }
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
    Gui, Add, Button, x10 y165 w35 h22 gPrevStep, < Prev
    Gui, Add, Button, x50 y165 w35 h22 gNextStep, Next >
    Gui, Add, Button, x90 y165 w35 h22 gResetProgress, Reset
    Gui, Add, Button, x130 y165 w40 h22 gChangeBuild, Build
    Gui, Add, Button, x175 y165 w35 h22 gToggleOverlay, Hide
    Gui, Add, Button, x215 y165 w35 h22 gExitApp, Exit
    
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
    
    ; Reset state machine for new build
    Gosub, ResetStateMachine
    
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
    
    ; Add zone to current step's visited zones
    ZonesVisitedThisStep.Insert(1, ZoneName)
    if (ZonesVisitedThisStep.Length() > 5)
        ZonesVisitedThisStep.Pop()
    
    ; Check if this is a town zone
    if (IsTownZone(ZoneName))
        LastTownZone := ZoneName
    
    ; Process state machine transitions
    Gosub, ProcessStateMachineTransition
    
    ; Update overlay information
    Gosub, UpdateZoneInfo
    
    ; Show zone change notification with state info
    ToolTip, Entered: %ZoneName% (State: %CurrentStepState%), 0, 0
    SetTimer, RemoveTooltip, 3000
Return

ProcessStateMachineTransition:
    ; Skip if no build loaded
    if (BuildData.steps.Length() = 0 || CurrentStepIndex > BuildData.steps.Length())
        return
        
    currentStep := BuildData.steps[CurrentStepIndex]
    currentState := GetCurrentStepState()
    
    ; State transition logic
    if (currentState = "STEP_WAITING_FOR_OBJECTIVE") {
        ; Check if we entered any of the required zones for this step
        if (CheckMultiZoneObjective(currentStep, ZoneName)) {
            SetStepState("STEP_OBJECTIVE_IN_PROGRESS")
        }
    }
    else if (currentState = "STEP_OBJECTIVE_IN_PROGRESS") {
        ; Check if we returned to town (objective presumably completed)
        if (IsTownZone(ZoneName)) {
            ; Check if all required zones have been visited
            if (IsObjectiveCompleted(currentStep)) {
                ; Check if step has rewards or should auto-advance
                if ((IsObject(currentStep.reward) || currentStep.vendor.Length() > 0) && !currentStep.auto_advance) {
                    SetStepState("STEP_REWARD_AVAILABLE")
                } else {
                    ; No rewards or auto-advance enabled, skip to next step
                    SetStepState("STEP_REWARD_CLAIMED")
                    AdvanceToNextStep()
                }
            }
        }
    }
    else if (currentState = "STEP_REWARD_AVAILABLE") {
        ; Check if we left town (reward claimed/skipped)
        if (!IsTownZone(ZoneName)) {
            SetStepState("STEP_REWARD_CLAIMED")
            AdvanceToNextStep()
        }
    }
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
    ; Navigate to previous step in build progression
    if (BuildData.steps.Length() > 0)
    {
        if (CurrentStepIndex > 1)
        {
            CurrentStepIndex--
            SetStepState("STEP_WAITING_FOR_OBJECTIVE")
            step := BuildData.steps[CurrentStepIndex]
            ToolTip, Previous: %step.title% (%step.zone%), 0, 0
            SetTimer, RemoveTooltip, 3000
            ; Save state after manual navigation
            Gosub, SaveState
            ; Update display
            Gosub, UpdateZoneInfo
        }
        else
        {
            ToolTip, Already at first step, 0, 0
            SetTimer, RemoveTooltip, 2000
        }
    }
Return

NextStep:
    ; Navigate to next step in build progression
    if (BuildData.steps.Length() > 0)
    {
        if (CurrentStepIndex < BuildData.steps.Length())
        {
            CurrentStepIndex++
            SetStepState("STEP_WAITING_FOR_OBJECTIVE")
            step := BuildData.steps[CurrentStepIndex]
            ToolTip, Next: %step.title% (%step.zone%), 0, 0
            SetTimer, RemoveTooltip, 3000
            ; Save state after manual navigation
            Gosub, SaveState
            ; Update display
            Gosub, UpdateZoneInfo
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

ResetProgress:
    ; Reset progression to step 1
    MsgBox, 68, Reset Progress, Reset progression to Step 1?`n`nThis will clear your current progress.
    IfMsgBox Yes
    {
        Gosub, ResetStateMachine
        ToolTip, Progress reset to Step 1, 0, 0
        SetTimer, RemoveTooltip, 2000
        ; Update display
        Gosub, UpdateZoneInfo
    }
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
    
    ; Find gems available for current progression using new reward/vendor/cost structure
    gemInfo := FindAvailableGems()
    return gemInfo
}

GetCurrentVendorInfo() {
    if (BuildData.steps.Length() = 0)
        return "Vendor: No build loaded"
    
    if (CurrentStepIndex > BuildData.steps.Length())
        return "Vendor: Build completed"
        
    currentStep := BuildData.steps[CurrentStepIndex]
    currentState := GetCurrentStepState()
    
    ; Build vendor information with cost and usage
    vendorInfo := ""
    if (currentStep.vendor.Length() > 0) {
        vendorInfo := "Vendor: "
        Loop, % currentStep.vendor.Length() {
            if (A_Index > 1)
                vendorInfo .= ", "
            gem := currentStep.vendor[A_Index]
            vendorInfo .= gem.name
            
            ; Add usage context
            if (gem.usage_type != "") {
                if (gem.usage_type = "support_add" && gem.target_skill != "") {
                    vendorInfo .= " (support for " . gem.target_skill . ")"
                } else if (gem.usage_type = "support_swap" && gem.replaces != "" && gem.target_skill != "") {
                    vendorInfo .= " (swap " . gem.replaces . " on " . gem.target_skill . ")"
                } else if (gem.usage_type = "skill_replace" && gem.replaces != "") {
                    vendorInfo .= " (replaces " . gem.replaces . ")"
                } else if (gem.usage_type = "new_skill") {
                    vendorInfo .= " (new skill)"
                } else if (gem.usage_type = "aura") {
                    vendorInfo .= " (aura)"
                } else if (gem.usage_type = "hold") {
                    vendorInfo .= " (hold for later)"
                }
            }
        }
        if (currentStep.cost != "")
            vendorInfo .= " - " . currentStep.cost
    } else {
        vendorInfo := "Vendor: None needed"
    }
    
    return vendorInfo
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
    ; Find quest info based on current state machine state
    if (BuildData.steps.Length() = 0)
        return "Quest: Select a build"
    
    if (CurrentStepIndex > BuildData.steps.Length())
        return "Quest: Build path completed!"
        
    currentStep := BuildData.steps[CurrentStepIndex]
    currentState := GetCurrentStepState()
    
    ; Return state-appropriate message
    if (currentState = "STEP_WAITING_FOR_OBJECTIVE") {
        return "Next: " . currentStep.title . " (" . currentStep.zone . ")"
    }
    else if (currentState = "STEP_OBJECTIVE_IN_PROGRESS") {
        return "Active: " . currentStep.title . " in " . CurrentZone
    }
    else if (currentState = "STEP_REWARD_AVAILABLE") {
        return "Reward Ready: " . currentStep.title . " completed"
    }
    else if (currentState = "STEP_REWARD_CLAIMED") {
        return "Advancing: Completed " . currentStep.title
    }
    else if (currentState = "BUILD_COMPLETED") {
        return "Quest: Build path completed!"
    }
    
    return "Quest: " . currentStep.title
}

FindAvailableGems() {
    ; Find gem info based on current state machine state using new reward/vendor structure
    if (BuildData.steps.Length() = 0)
        return "Reward: None available"
    
    if (CurrentStepIndex > BuildData.steps.Length())
        return "Reward: Build completed"
        
    currentStep := BuildData.steps[CurrentStepIndex]
    currentState := GetCurrentStepState()
    
    ; Build reward information with usage context
    rewardInfo := ""
    if (currentStep.reward != "" && IsObject(currentStep.reward)) {
        rewardInfo := "Reward: " . currentStep.reward.name
        
        ; Add usage context
        if (currentStep.reward.usage_type != "") {
            if (currentStep.reward.usage_type = "support_add" && currentStep.reward.target_skill != "") {
                rewardInfo .= " (support for " . currentStep.reward.target_skill . ")"
            } else if (currentStep.reward.usage_type = "support_swap" && currentStep.reward.replaces != "" && currentStep.reward.target_skill != "") {
                rewardInfo .= " (swap " . currentStep.reward.replaces . " on " . currentStep.reward.target_skill . ")"
            } else if (currentStep.reward.usage_type = "skill_replace" && currentStep.reward.replaces != "") {
                rewardInfo .= " (replaces " . currentStep.reward.replaces . ")"
            } else if (currentStep.reward.usage_type = "new_skill") {
                rewardInfo .= " (new skill)"
            } else if (currentStep.reward.usage_type = "aura") {
                rewardInfo .= " (aura)"
            } else if (currentStep.reward.usage_type = "hold") {
                rewardInfo .= " (hold for later)"
            }
        }
        
        if (currentStep.reward.quest != "")
            rewardInfo .= " from " . currentStep.reward.quest
    } else {
        rewardInfo := "Reward: None"
    }
    
    return rewardInfo
}

GetCurrentGemName() {
    ; Get the name of the current/next gem for image display
    if (BuildData.steps.Length() = 0)
        return ""
    
    ; Find current step and look for next gem rewards
    currentStep := GetCurrentProgressionStep()
    
    ; Check current step first
    if (currentStep <= BuildData.steps.Length())
    {
        step := BuildData.steps[currentStep]
        if (IsObject(step.reward) && step.reward.name != "")
        {
            return step.reward.name
        }
    }
    
    ; Look for next step with reward gems
    Loop, % (BuildData.steps.Length() - currentStep)
    {
        stepIndex := currentStep + A_Index
        if (stepIndex > BuildData.steps.Length())
            break
            
        step := BuildData.steps[stepIndex]
        if (IsObject(step.reward) && step.reward.name != "")
        {
            return step.reward.name
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

; State Machine Functions
SetStepState(newState) {
    if (newState != CurrentStepState) {
        ; Record state transition in history
        StepStateHistory.Insert(1, {from: CurrentStepState, to: newState, time: A_TickCount, zone: CurrentZone})
        if (StepStateHistory.Length() > 10)
            StepStateHistory.Pop()
        
        ; Update current state
        CurrentStepState := newState
        
        ; Clear zones visited if moving to new step
        if (newState = "STEP_WAITING_FOR_OBJECTIVE")
            ZonesVisitedThisStep := []
    }
}

GetCurrentStepState() {
    return CurrentStepState
}

ResetStateMachine:
    CurrentStepIndex := 1
    CurrentStepState := "STEP_WAITING_FOR_OBJECTIVE"
    ZonesVisitedThisStep := []
    StepStateHistory := []
    ; Save reset state
    Gosub, SaveState
Return

AdvanceToNextStep() {
    if (CurrentStepIndex < BuildData.steps.Length()) {
        CurrentStepIndex++
        SetStepState("STEP_WAITING_FOR_OBJECTIVE")
        
        ; Save state after advancing
        Gosub, SaveState
        
        ; Show advancement notification
        if (CurrentStepIndex <= BuildData.steps.Length()) {
            step := BuildData.steps[CurrentStepIndex]
            ToolTip, Advanced to Step %CurrentStepIndex%: %step.title%, 0, 0
            SetTimer, RemoveTooltip, 3000
        }
    } else {
        ; Build completed
        SetStepState("BUILD_COMPLETED")
        Gosub, SaveState
        ToolTip, Build path completed!, 0, 0
        SetTimer, RemoveTooltip, 5000
    }
}

IsTownZone(zoneName) {
    Loop, % TownZonesByAct.Length() {
        actTowns := TownZonesByAct[A_Index]
        Loop, % actTowns.Length() {
            if (InStr(zoneName, actTowns[A_Index]))
                return true
        }
    }
    return false
}

CheckMultiZoneObjective(step, zoneName) {
    ; Check if the entered zone is one of the required zones for this step
    if (step.zones_required.Length() = 0)
        return false
        
    Loop, % step.zones_required.Length() {
        requiredZone := step.zones_required[A_Index]
        if (InStr(zoneName, requiredZone)) {
            return true
        }
    }
    return false
}

IsObjectiveCompleted(step) {
    ; Check if objective is completed based on zones visited and multi-zone logic
    if (step.zones_required.Length() = 0)
        return true
    
    if (step.zones_required.Length() = 1)
        return true  ; Single zone, already triggered if we're here
    
    ; Multi-zone logic
    multiLogic := step.multi_zone_logic ? step.multi_zone_logic : "all"
    
    if (multiLogic = "any") {
        ; Any one zone visited is sufficient
        return true
    }
    else if (multiLogic = "all") {
        ; All zones must be visited
        zonesCompleted := 0
        Loop, % step.zones_required.Length() {
            requiredZone := step.zones_required[A_Index]
            
            ; Check if this zone was visited in current step
            Loop, % ZonesVisitedThisStep.Length() {
                visitedZone := ZonesVisitedThisStep[A_Index]
                if (InStr(visitedZone, requiredZone)) {
                    zonesCompleted++
                    break
                }
            }
        }
        return (zonesCompleted >= step.zones_required.Length())
    }
    else if (multiLogic = "sequence") {
        ; Zones must be visited in order (future enhancement)
        ; For now, treat as "all"
        return IsObjectiveCompleted(step.multi_zone_logic := "all")
    }
    
    return true  ; Default to completed
}

; State persistence functions
SaveState:
    ; Save current progression state to file
    if (CurrentBuild != "") {
        IniWrite, %CurrentBuild%, %StateFilePath%, State, CurrentBuild
        IniWrite, %CurrentStepIndex%, %StateFilePath%, State, CurrentStepIndex
        IniWrite, %CurrentStepState%, %StateFilePath%, State, CurrentStepState
        IniWrite, %CurrentZone%, %StateFilePath%, State, CurrentZone
        IniWrite, %CurrentAct%, %StateFilePath%, State, CurrentAct
    }
Return

LoadState:
    ; Load saved progression state from file
    if (FileExist(StateFilePath)) {
        IniRead, SavedBuild, %StateFilePath%, State, CurrentBuild, ""
        IniRead, SavedStepIndex, %StateFilePath%, State, CurrentStepIndex, 1
        IniRead, SavedStepState, %StateFilePath%, State, CurrentStepState, "STEP_WAITING_FOR_OBJECTIVE"
        IniRead, SavedZone, %StateFilePath%, State, CurrentZone, "Unknown"
        IniRead, SavedAct, %StateFilePath%, State, CurrentAct, 1
        
        ; Only restore state if it's for the same build
        if (SavedBuild = CurrentBuild) {
            CurrentStepIndex := SavedStepIndex
            CurrentStepState := SavedStepState
            CurrentZone := SavedZone
            CurrentAct := SavedAct
            
            ToolTip, Restored progress: Step %CurrentStepIndex%, 0, 0
            SetTimer, RemoveTooltip, 2000
        }
    }
Return