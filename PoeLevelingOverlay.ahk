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

; GUI Variables
OverlayGui := ""
StepText := ""
GearText := ""
CurrencyText := ""

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
    Gui, Add, Text, x10 y10 w400 h30 vStepHeader, Step 1: Starting Area
    Gui, Add, Text, x10 y50 w400 h60 vStepDescription, Kill Hillock and enter Lioneye's Watch
    Gui, Add, Text, x10 y120 w400 h40 vGearInfo, Gear: Starting weapon
    Gui, Add, Text, x10 y170 w400 h40 vCurrencyInfo, Currency: None needed
    Gui, Add, Button, x10 y220 w80 h30 gPrevStep, << Previous
    Gui, Add, Button, x100 y220 w80 h30 gNextStep, Next >>
    Gui, Add, Button, x300 y220 w100 h30 gToggleOverlay, Hide Overlay
    Gui, Add, Button, x200 y220 w80 h30 gChangeBuild, Build
    
    Gui, Show, w420 h270 x50 y50, POE Leveling Overlay
    OverlayGui := WinExist("POE Leveling Overlay")
Return

ShowBuildSelector:
    Gui, BuildSelect:Add, Text, x10 y10 w300 h20, Select your leveling build:
    
    Gui, BuildSelect:Add, Radio, x10 y40 w280 h20 vTempArc Checked, Templar - Archmage Arc
    Gui, BuildSelect:Add, Radio, x10 y65 w280 h20 vTempFire, Templar - Fire Caster (Armageddon Brand)
    Gui, BuildSelect:Add, Radio, x10 y90 w280 h20 vWitchArc, Witch - Archmage Arc  
    Gui, BuildSelect:Add, Radio, x10 y115 w280 h20 vWitchFire, Witch - Fire Caster (Armageddon Brand)
    Gui, BuildSelect:Add, Radio, x10 y140 w280 h20 vRangerPoison, Ranger - Poisonous Concoction
    Gui, BuildSelect:Add, Radio, x10 y165 w280 h20 vRangerLA, Ranger - Lightning Arrow
    Gui, BuildSelect:Add, Radio, x10 y190 w280 h20 vDuelistMelee, Duelist - Melee (Sunder/Boneshatter)
    Gui, BuildSelect:Add, Radio, x10 y215 w280 h20 vMarauderMelee, Marauder - Melee (Sunder/Boneshatter)
    Gui, BuildSelect:Add, Radio, x10 y240 w280 h20 vShadowPoison, Shadow - Trap/Poison
    Gui, BuildSelect:Add, Radio, x10 y265 w280 h20 vScionMelee, Scion - Melee
    
    Gui, BuildSelect:Add, Button, x100 y300 w100 h30 gSelectBuild, Start Leveling
    
    Gui, BuildSelect:Show, w320 h350, Select Build
Return

SelectBuild:
    Gui, BuildSelect:Submit
    
    ; Determine selected build
    if (TempArc)
        CurrentBuild := "templar-arc"
    else if (TempFire)
        CurrentBuild := "templar-fire"
    else if (WitchArc)
        CurrentBuild := "witch-arc"
    else if (WitchFire)
        CurrentBuild := "witch-fire"
    else if (RangerPoison)
        CurrentBuild := "ranger-poison"
    else if (RangerLA)
        CurrentBuild := "ranger-la"
    else if (DuelistMelee)
        CurrentBuild := "duelist-melee"
    else if (MarauderMelee)
        CurrentBuild := "marauder-melee"
    else if (ShadowPoison)
        CurrentBuild := "shadow-poison"
    else if (ScionMelee)
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
        if (stepData.zone != "")
            descText := descText . "`nZone: " . stepData.zone
        GuiControl,, StepDescription, %descText%
        
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
                ToolTip, Advanced to Step %CurrentStep%: %stepTitle%, 0, 30
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
            ToolTip, Jumped to Step %CurrentStep%: %stepTitle%, 0, 60
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

; Exit handlers
GuiClose:
ExitApp

^Esc::ExitApp