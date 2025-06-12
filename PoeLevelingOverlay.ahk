#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%

; Include JSON loader
#Include JsonLoader.ahk

; Global variables
LogFilePath := ""
CurrentStep := 1
CurrentBuild := ""
OverlayVisible := true
LastZoneEvent := ""
BuildData := {}
MaxSteps := 1
CurrentZone := "Unknown"
NextTrigger := ""

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
            break
        }
    }
    
    if (LogFilePath = "")
    {
        FileSelectFile, LogFilePath, 1, , Select Path of Exile Client.txt, Text Files (*.txt)
        if (LogFilePath = "")
        {
            MsgBox, 16, Error, Could not find POE Client.txt file. Exiting.
            ExitApp
        }
    }
Return

LoadBuildData:
    ; Load the selected build data from JSON file
    if (CurrentBuild != "")
    {
        BuildData := LoadBuildFromJSON(CurrentBuild)
        MaxSteps := BuildData.steps.Length()
        
        ; Reset to step 1 when loading new build
        CurrentStep := 1
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
    
    ; Header with larger, bold font
    Gui, Font, s12 Bold cLime
    Gui, Add, Text, x15 y10 w450 h25 vStepHeader, ⚡ Step 1: Starting Area
    
    ; Description with normal font
    Gui, Font, s9 Normal cWhite
    Gui, Add, Text, x15 y35 w450 h40 vStepDescription, Kill Hillock and enter Lioneye's Watch
    
    ; Zone info with colored text
    Gui, Font, s9 Normal cAqua
    Gui, Add, Text, x15 y80 w450 h20 vCurrentZone, 🌍 Current Area: Unknown
    
    ; Next trigger with accent color
    Gui, Font, s9 Normal cYellow
    Gui, Add, Text, x15 y105 w450 h30 vNextTrigger, 🎯 Looking for: Zone change
    
    ; Gear and currency info
    Gui, Font, s8 Normal cSilver
    Gui, Add, Text, x15 y140 w450 h20 vGearInfo, ⚔️ Gear: Starting weapon
    Gui, Add, Text, x15 y160 w450 h20 vCurrencyInfo, 💰 Currency: None needed
    
    ; Smaller, modern buttons
    Gui, Font, s7
    Gui, Add, Button, x15 y190 w50 h20 gPrevStep, ◀ Prev
    Gui, Add, Button, x70 y190 w50 h20 gNextStep, Next ▶
    Gui, Add, Button, x125 y190 w50 h20 gChangeBuild, Build
    Gui, Add, Button, x180 y190 w50 h20 gToggleOverlay, Hide
    Gui, Add, Button, x235 y190 w40 h20 gExitApp, Exit
    
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
    Gosub, UpdateStep
Return

UpdateStep:
    ; Update overlay with current step information from JSON data
    if (BuildData.steps.Length() > 0 && CurrentStep <= BuildData.steps.Length())
    {
        stepData := GetStepData(BuildData, CurrentStep)
        
        ; Update header with enhanced formatting
        headerText := "⚡ Step " . CurrentStep . "/" . MaxSteps . ": Act " . stepData.act . " - " . stepData.title
        GuiControl,, StepHeader, %headerText%
        
        ; Update description
        descText := stepData.description
        GuiControl,, StepDescription, %descText%
        
        ; Update current zone display with emoji
        zoneText := "🌍 Current Area: " . CurrentZone
        GuiControl,, CurrentZone, %zoneText%
        
        ; Update next trigger indicator with enhanced formatting
        if (CurrentStep < MaxSteps) {
            nextStepData := GetStepData(BuildData, CurrentStep + 1)
            triggerText := "🎯 Looking for: Enter " . nextStepData.zone_trigger
            NextTrigger := nextStepData.zone_trigger
        } else {
            triggerText := "🏆 Build Complete! Well done!"
            NextTrigger := ""
        }
        GuiControl,, NextTrigger, %triggerText%
        
        ; Update gear info with emoji
        gearText := "⚔️ Gear: " . stepData.gear_focus
        GuiControl,, GearInfo, %gearText%
        
        ; Update currency info with emoji
        currencyText := "💰 Currency: " . stepData.currency_notes
        GuiControl,, CurrencyInfo, %currencyText%
    }
    else
    {
        ; Fallback display with enhanced formatting
        GuiControl,, StepHeader, ⚡ Step %CurrentStep%: Select a build
        GuiControl,, StepDescription, Please select a leveling build to begin
        GuiControl,, CurrentZone, 🌍 Current Area: Unknown
        GuiControl,, NextTrigger, 🎯 Looking for: Select a build first
        GuiControl,, GearInfo, ⚔️ Gear: N/A
        GuiControl,, CurrencyInfo, 💰 Currency: N/A
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
        
        ; Check if this is a zone change event we haven't seen
        if (InStr(CurrentLine, ": You have entered") && CurrentLine != LastZoneEvent)
        {
            LastZoneEvent := CurrentLine
            
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
    ; Update current zone display
    CurrentZone := ZoneName
    Gosub, UpdateStep
    
    ; Handle automatic step progression based on zone
    ToolTip, Entered: %ZoneName%, 0, 0
    SetTimer, RemoveTooltip, 3000
    
    ; Check if we should auto-advance to next step
    if (BuildData.steps.Length() > 0)
    {
        ; Look ahead to see if next step matches this zone
        nextStep := CurrentStep + 1
        if (nextStep <= BuildData.steps.Length())
        {
            nextStepData := GetStepData(BuildData, nextStep)
            if (InStr(ZoneName, nextStepData.zone_trigger))
            {
                CurrentStep := nextStep
                Gosub, UpdateStep
                
                ; Show progression notification
                stepTitle := nextStepData.title
                ToolTip, ✓ Advanced to Step %CurrentStep%: %stepTitle%, 0, 30
                SetTimer, RemoveTooltip2, 5000
            }
        }
        
        ; Also check if we should jump to a specific step for this zone
        foundStep := GetStepByZone(BuildData, ZoneName)
        if (foundStep > CurrentStep && foundStep <= BuildData.steps.Length())
        {
            CurrentStep := foundStep
            Gosub, UpdateStep
            
            stepData := GetStepData(BuildData, CurrentStep)
            stepTitle := stepData.title
            ToolTip, ⚡ Jumped to Step %CurrentStep%: %stepTitle%, 0, 60
            SetTimer, RemoveTooltip3, 5000
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

; Hotkeys
F1::Gosub, PrevStep
F2::Gosub, NextStep
F3::Gosub, ToggleOverlay

PrevStep:
    if (CurrentStep > 1)
    {
        CurrentStep--
        Gosub, UpdateStep
    }
Return

NextStep:
    if (CurrentStep < MaxSteps)
    {
        CurrentStep++
        Gosub, UpdateStep
    }
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

; Exit handlers
GuiClose:
ExitApp

^Esc::ExitApp