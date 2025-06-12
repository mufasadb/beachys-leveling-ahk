#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%

; Global variables
LogFilePath := ""
LastLine := ""
LastCheckedTime := ""

; Initialize the test
Gosub, CreateTestGUI
Gosub, FindClientTxt

CreateTestGUI:
    ; Create simple test GUI
    Gui, +Resize +MinSize400x300
    Gui, Font, s10 Bold
    Gui, Add, Text, x10 y10 w380 h20, Client.txt Test Application
    
    Gui, Font, s9 Normal
    Gui, Add, Text, x10 y40 w80 h20, File Status:
    Gui, Add, Text, x100 y40 w280 h20 vFileStatus cRed, Not Found
    
    Gui, Add, Text, x10 y65 w80 h20, File Path:
    Gui, Add, Edit, x100 y65 w280 h20 vFilePath ReadOnly
    
    Gui, Add, Text, x10 y95 w80 h20, File Size:
    Gui, Add, Text, x100 y95 w280 h20 vFileSize, Unknown
    
    Gui, Add, Text, x10 y125 w80 h20, Last Line:
    Gui, Add, Edit, x100 y125 w280 h40 vLastLineText ReadOnly
    
    Gui, Add, Text, x10 y175 w80 h20, Current Line:
    Gui, Add, Edit, x100 y175 w280 h40 vCurrentLineText ReadOnly
    
    Gui, Add, Text, x10 y225 w80 h20, Last Check:
    Gui, Add, Text, x100 y225 w280 h20 vLastCheckTime, Never
    
    Gui, Add, Button, x10 y255 w80 h25 gRefreshFile, Refresh
    Gui, Add, Button, x100 y255 w80 h25 gSelectFile, Select File
    Gui, Add, Button, x300 y255 w80 h25 gExitTest, Exit
    
    Gui, Show, w400 h300, Client.txt Test
Return

FindClientTxt:
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
            Gosub, UpdateFileInfo
            GuiControl,, FileStatus, Found!
            GuiControl, +cGreen, FileStatus
            
            ; Start monitoring timer
            SetTimer, CheckCurrentLine, 5000
            return
        }
    }
    
    ; Not found in standard locations
    GuiControl,, FileStatus, Not Found - Click Select File
    GuiControl, +cRed, FileStatus
Return

UpdateFileInfo:
    if (LogFilePath != "")
    {
        GuiControl,, FilePath, %LogFilePath%
        
        ; Get file size
        FileGetSize, FileSize, %LogFilePath%
        if (FileSize >= 0)
        {
            FileSizeKB := Round(FileSize / 1024, 2)
            GuiControl,, FileSize, %FileSizeKB% KB
            
            ; Read last line
            Gosub, ReadLastLine
        }
        else
        {
            GuiControl,, FileSize, Error reading file
        }
    }
Return

ReadLastLine:
    if (LogFilePath = "")
        return
    
    ; Read the entire file and get the last line
    FileRead, FileContent, %LogFilePath%
    if (ErrorLevel)
    {
        GuiControl,, LastLineText, Error reading file
        return
    }
    
    ; Split into lines and get the last non-empty line
    StringSplit, Lines, FileContent, `n
    
    ; Find the last non-empty line
    Loop, % Lines0
    {
        LineIndex := Lines0 - A_Index + 1
        if (LineIndex <= 0)
            break
        
        CurrentLine := Lines%LineIndex%
        StringReplace, CurrentLine, CurrentLine, `r, , All  ; Remove carriage returns
        
        if (CurrentLine != "")
        {
            LastLine := CurrentLine
            GuiControl,, LastLineText, %LastLine%
            break
        }
    }
Return

CheckCurrentLine:
    if (LogFilePath = "")
        return
    
    ; Read current last line
    FileRead, FileContent, %LogFilePath%
    if (ErrorLevel)
    {
        GuiControl,, CurrentLineText, Error reading file
        return
    }
    
    ; Split into lines and get the last non-empty line
    StringSplit, Lines, FileContent, `n
    
    ; Find the last non-empty line
    Loop, % Lines0
    {
        LineIndex := Lines0 - A_Index + 1
        if (LineIndex <= 0)
            break
        
        CurrentLine := Lines%LineIndex%
        StringReplace, CurrentLine, CurrentLine, `r, , All  ; Remove carriage returns
        
        if (CurrentLine != "")
        {
            GuiControl,, CurrentLineText, %CurrentLine%
            
            ; Update timestamp
            FormatTime, CurrentTime, , yyyy-MM-dd HH:mm:ss
            GuiControl,, LastCheckTime, %CurrentTime%
            
            ; Check if this is a zone change
            if (InStr(CurrentLine, ": You have entered"))
            {
                GuiControl, +cGreen, CurrentLineText
                ; Extract zone name
                RegExMatch(CurrentLine, "] : You have entered (.*?)\.", ZoneMatch)
                if (ZoneMatch1 != "")
                {
                    ToolTip, Zone Change Detected: %ZoneMatch1%, 0, 0
                    SetTimer, RemoveTooltip, 3000
                }
            }
            else
            {
                GuiControl, +cDefault, CurrentLineText
            }
            break
        }
    }
Return

RemoveTooltip:
    ToolTip
    SetTimer, RemoveTooltip, Off
Return

RefreshFile:
    Gosub, UpdateFileInfo
Return

SelectFile:
    FileSelectFile, SelectedPath, 1, , Select Path of Exile Client.txt, Text Files (*.txt)
    if (SelectedPath != "")
    {
        LogFilePath := SelectedPath
        Gosub, UpdateFileInfo
        GuiControl,, FileStatus, Found!
        GuiControl, +cGreen, FileStatus
        
        ; Start monitoring timer
        SetTimer, CheckCurrentLine, 5000
    }
Return

ExitTest:
    SetTimer, CheckCurrentLine, Off
    ExitApp
Return

GuiClose:
    SetTimer, CheckCurrentLine, Off
    ExitApp

^Esc::ExitApp