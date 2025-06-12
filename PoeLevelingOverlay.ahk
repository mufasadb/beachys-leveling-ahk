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
    
    ; Create semi-transparent overlay that stays on top
    Gui, +AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox +LastFound
    WinSet, Transparent, 220
    
    ; Set background color for better visibility
    Gui, Color, 0x2D2D30
    
    Gui, Font, s10 cWhite
    Gui, Add, Text, x10 y10 w450 h25 vStepHeader, Step 1: Starting Area
    Gui, Add, Text, x10 y40 w450 h50 vStepDescription, Kill Hillock and enter Lioneye's Watch
    Gui, Add, Text, x10 y95 w450 h20 vCurrentZone, Current Area: Unknown
    Gui, Add, Text, x10 y120 w450 h35 vNextTrigger, Looking for: Zone change
    Gui, Add, Text, x10 y160 w450 h25 vGearInfo, Gear: Starting weapon
    Gui, Add, Text, x10 y185 w450 h25 vCurrencyInfo, Currency: None needed
    
    Gui, Font, s8
    Gui, Add, Button, x10 y220 w70 h25 gPrevStep, << Prev
    Gui, Add, Button, x85 y220 w70 h25 gNextStep, Next >>
    Gui, Add, Button, x160 y220 w70 h25 gChangeBuild, Build
    Gui, Add, Button, x235 y220 w80 h25 gToggleOverlay, Hide
    Gui, Add, Button, x320 y220 w80 h25 gRepositionOverlay, Reposition
    Gui, Add, Button, x405 y220 w50 h25 gExitApp, Exit
    
    ; Position overlay to detect POE and stay on top
    Gosub, PositionOverlay
    OverlayGui := WinExist("POE Leveling Overlay")
Return

ShowBuildSelector:
    Gui, BuildSelect:Add, Text, x10 y10 w300 h20, Select your leveling build:
    
    Gui, BuildSelect:Add, Radio, x10 y40 w280 h20 vBuildTempArc Checked, Templar - Archmage Arc
    Gui, BuildSelect:Add, Radio, x10 y65 w280 h20 vBuildTempFire, Templar - Fire Caster (Armageddon Brand)
    Gui, BuildSelect:Add, Radio, x10 y90 w280 h20 vBuildWitchArc, Witch - Archmage Arc  
    Gui, BuildSelect:Add, Radio, x10 y115 w280 h20 vBuildWitchFire, Witch - Fire Caster (Armageddon Brand)
    Gui, BuildSelect:Add, Radio, x10 y140 w280 h20 vBuildRangerPoison, Ranger - Poisonous Concoction
    Gui, BuildSelect:Add, Radio, x10 y165 w280 h20 vBuildRangerLA, Ranger - Lightning Arrow
    Gui, BuildSelect:Add, Radio, x10 y190 w280 h20 vBuildDuelistMelee, Duelist - Melee (Sunder/Boneshatter)
    Gui, BuildSelect:Add, Radio, x10 y215 w280 h20 vBuildMarauderMelee, Marauder - Melee (Sunder/Boneshatter)
    Gui, BuildSelect:Add, Radio, x10 y240 w280 h20 vBuildShadowPoison, Shadow - Trap/Poison
    Gui, BuildSelect:Add, Radio, x10 y265 w280 h20 vBuildScionMelee, Scion - Melee
    
    Gui, BuildSelect:Add, Button, x100 y300 w100 h30 gSelectBuild, Start Leveling
    
    Gui, BuildSelect:Show, w320 h350, Select Build
Return

SelectBuild:
    Gui, BuildSelect:Submit
    
    ; Determine selected build
    if (BuildTempArc)
        CurrentBuild := "templar-arc"
    else if (BuildTempFire)
        CurrentBuild := "templar-fire"
    else if (BuildWitchArc)
        CurrentBuild := "witch-arc"
    else if (BuildWitchFire)
        CurrentBuild := "witch-fire"
    else if (BuildRangerPoison)
        CurrentBuild := "ranger-poison"
    else if (BuildRangerLA)
        CurrentBuild := "ranger-la"
    else if (BuildDuelistMelee)
        CurrentBuild := "duelist-melee"
    else if (BuildMarauderMelee)
        CurrentBuild := "marauder-melee"
    else if (BuildShadowPoison)
        CurrentBuild := "shadow-poison"
    else if (BuildScionMelee)
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
        
        ; Update header
        headerText := "Step " . CurrentStep . "/" . MaxSteps . ": Act " . stepData.act . " - " . stepData.title
        GuiControl,, StepHeader, %headerText%
        
        ; Update description
        descText := stepData.description
        GuiControl,, StepDescription, %descText%
        
        ; Update current zone display
        zoneText := "Current Area: " . CurrentZone
        GuiControl,, CurrentZone, %zoneText%
        
        ; Update next trigger indicator
        if (CurrentStep < MaxSteps) {
            nextStepData := GetStepData(BuildData, CurrentStep + 1)
            triggerText := "Looking for: Enter " . nextStepData.zone_trigger
            NextTrigger := nextStepData.zone_trigger
        } else {
            triggerText := "Looking for: Build Complete!"
            NextTrigger := ""
        }
        GuiControl,, NextTrigger, %triggerText%
        
        ; Update gear info
        gearText := "Gear: " . stepData.gear_focus
        GuiControl,, GearInfo, %gearText%
        
        ; Update currency info
        currencyText := "Currency: " . stepData.currency_notes
        GuiControl,, CurrencyInfo, %currencyText%
    }
    else
    {
        ; Fallback display
        GuiControl,, StepHeader, Step %CurrentStep%: Select a build
        GuiControl,, StepDescription, Please select a leveling build to begin
        GuiControl,, CurrentZone, Current Area: Unknown
        GuiControl,, NextTrigger, Looking for: Select a build first
        GuiControl,, GearInfo, Gear: N/A
        GuiControl,, CurrencyInfo, Currency: N/A
    }
Return

WatchLog:
    if (LogFilePath = "")
        return
        
    ; Read the last few lines of the log file
    FileReadLine, LastLine, %LogFilePath%, 0
    
    ; Check if this is a zone change event
    if (InStr(LastLine, ": You have entered") && LastLine != LastZoneEvent)
    {
        LastZoneEvent := LastLine
        
        ; Extract zone name
        RegExMatch(LastLine, ": You have entered (.*?)\.", ZoneMatch)
        ZoneName := ZoneMatch1
        
        ; Handle zone change
        Gosub, HandleZoneChange
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
    ; Try to position overlay over Path of Exile window
    WinGet, poeHwnd, ID, Path of Exile
    if (poeHwnd != "")
    {
        ; Get POE window position and size
        WinGetPos, poeX, poeY, poeW, poeH, Path of Exile
        
        ; Position overlay in top-right corner of POE window
        overlayX := poeX + poeW - 480
        overlayY := poeY + 10
        
        ; Ensure overlay stays within screen bounds
        if (overlayX < 0)
            overlayX := 10
        if (overlayY < 0)
            overlayY := 10
            
        Gui, Show, w470 h255 x%overlayX% y%overlayY%, POE Leveling Overlay
    }
    else
    {
        ; POE not found, position in default location
        Gui, Show, w470 h255 x50 y50, POE Leveling Overlay
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
            
            ; Calculate expected overlay position
            expectedX := poeX + poeW - 480
            expectedY := poeY + 10
            
            ; Ensure within bounds
            if (expectedX < 0)
                expectedX := 10
            if (expectedY < 0)
                expectedY := 10
            
            ; Reposition if overlay is not where it should be (with small tolerance)
            if (Abs(overlayX - expectedX) > 20 || Abs(overlayY - expectedY) > 20)
            {
                WinMove, POE Leveling Overlay, , %expectedX%, %expectedY%
            }
        }
    }
Return

; Exit handlers
GuiClose:
ExitApp

^Esc::ExitApp