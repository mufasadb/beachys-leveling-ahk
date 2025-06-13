; Simple JSON parser for AutoHotkey
; This is a basic implementation to parse our build JSON files

; Load build data from JSON file
LoadBuildFromJSON(buildName) {
    filePath := A_ScriptDir . "\builds\" . buildName . ".json"
    
    IfNotExist, %filePath%
    {
        MsgBox, 16, Error, Build file not found: %filePath%
        return {}
    }
    
    FileRead, jsonContent, %filePath%
    
    ; Parse JSON content (basic implementation)
    buildData := ParseBasicJSON(jsonContent)
    return buildData
}

; Basic JSON parser - handles our specific JSON structure
ParseBasicJSON(jsonText) {
    buildData := {}
    
    ; Extract name
    RegExMatch(jsonText, """name"":\s*""([^""]+)""", nameMatch)
    buildData.name := nameMatch1
    
    ; Extract class
    RegExMatch(jsonText, """class"":\s*""([^""]+)""", classMatch)
    buildData.class := classMatch1
    
    ; Extract build_url
    RegExMatch(jsonText, """build_url"":\s*""([^""]+)""", urlMatch)
    buildData.build_url := urlMatch1
    
    ; Extract steps array
    buildData.steps := []
    
    ; Find steps array content more carefully
    stepStart := InStr(jsonText, """steps"":")
    if (stepStart = 0)
        return buildData
        
    ; Find the opening bracket of steps array
    bracketStart := InStr(jsonText, "[", stepStart)
    if (bracketStart = 0)
        return buildData
    
    ; Find matching closing bracket
    bracketCount := 1
    pos := bracketStart + 1
    bracketEnd := 0
    
    while (pos <= StrLen(jsonText) && bracketCount > 0) {
        char := SubStr(jsonText, pos, 1)
        if (char = "[")
            bracketCount++
        else if (char = "]")
            bracketCount--
        
        if (bracketCount = 0)
            bracketEnd := pos
        
        pos++
    }
    
    if (bracketEnd = 0)
        return buildData
    
    ; Extract steps content
    stepsContent := SubStr(jsonText, bracketStart + 1, bracketEnd - bracketStart - 1)
    
    ; Parse individual step objects
    stepObjs := ParseStepsArray(stepsContent)
    
    Loop, % stepObjs.Length() {
        stepData := ParseStepObject(stepObjs[A_Index])
        buildData.steps.Push(stepData)
    }
    
    return buildData
}

; Parse steps array into individual step objects
ParseStepsArray(stepsContent) {
    steps := []
    braceCount := 0
    stepStart := 1
    pos := 1
    
    while (pos <= StrLen(stepsContent)) {
        char := SubStr(stepsContent, pos, 1)
        
        if (char = "{") {
            braceCount++
            if (braceCount = 1)
                stepStart := pos
        }
        else if (char = "}") {
            braceCount--
            if (braceCount = 0) {
                stepContent := SubStr(stepsContent, stepStart, pos - stepStart + 1)
                steps.Push(stepContent)
            }
        }
        
        pos++
    }
    
    return steps
}

; Parse individual step object
ParseStepObject(stepText) {
    step := {}
    
    ; Extract basic properties
    RegExMatch(stepText, """step"":\s*(\d+)", stepNum)
    step.step := stepNum1
    
    RegExMatch(stepText, """act"":\s*(\d+)", actNum)
    step.act := actNum1
    
    RegExMatch(stepText, """zone"":\s*""([^""]+)""", zoneMatch)
    step.zone := zoneMatch1
    
    RegExMatch(stepText, """zone_trigger"":\s*""([^""]+)""", triggerMatch)
    step.zone_trigger := triggerMatch1
    
    RegExMatch(stepText, """title"":\s*""([^""]+)""", titleMatch)
    step.title := titleMatch1
    
    RegExMatch(stepText, """description"":\s*""([^""]+)""", descMatch)
    step.description := descMatch1
    
    RegExMatch(stepText, """gear_focus"":\s*""([^""]+)""", gearMatch)
    step.gear_focus := gearMatch1
    
    RegExMatch(stepText, """currency_notes"":\s*""([^""]+)""", currencyMatch)
    step.currency_notes := currencyMatch1
    
    ; Extract gems array
    step.gems_available := []
    gemsStart := InStr(stepText, """gems_available"":")
    if (gemsStart > 0) {
        bracketStart := InStr(stepText, "[", gemsStart)
        if (bracketStart > 0) {
            ; Find matching closing bracket for gems array
            bracketCount := 1
            pos := bracketStart + 1
            bracketEnd := 0
            
            while (pos <= StrLen(stepText) && bracketCount > 0) {
                char := SubStr(stepText, pos, 1)
                if (char = "[")
                    bracketCount++
                else if (char = "]")
                    bracketCount--
                
                if (bracketCount = 0)
                    bracketEnd := pos
                
                pos++
            }
            
            if (bracketEnd > 0) {
                gemsContent := SubStr(stepText, bracketStart + 1, bracketEnd - bracketStart - 1)
                if (Trim(gemsContent) != "") {
                    gemObjs := ParseGemsArray(gemsContent)
                    Loop, % gemObjs.Length() {
                        gemData := ParseGemObject(gemObjs[A_Index])
                        step.gems_available.Push(gemData)
                    }
                }
            }
        }
    }
    
    return step
}

; Parse gems array into individual gem objects
ParseGemsArray(gemsContent) {
    gems := []
    braceCount := 0
    gemStart := 1
    pos := 1
    
    while (pos <= StrLen(gemsContent)) {
        char := SubStr(gemsContent, pos, 1)
        
        if (char = "{") {
            braceCount++
            if (braceCount = 1)
                gemStart := pos
        }
        else if (char = "}") {
            braceCount--
            if (braceCount = 0) {
                gemContent := SubStr(gemsContent, gemStart, pos - gemStart + 1)
                gems.Push(gemContent)
            }
        }
        
        pos++
    }
    
    return gems
}

; Parse individual gem object
ParseGemObject(gemText) {
    gem := {}
    
    RegExMatch(gemText, """name"":\s*""([^""]+)""", gemNameMatch)
    gem.name := gemNameMatch1
    
    RegExMatch(gemText, """quest"":\s*""([^""]+)""", gemQuestMatch)
    gem.quest := gemQuestMatch1
    
    RegExMatch(gemText, """notes"":\s*""([^""]+)""", gemNotesMatch)
    gem.notes := gemNotesMatch1
    
    return gem
}

; Get step by number
GetStepData(buildData, stepNumber) {
    if (buildData.steps.Length() >= stepNumber && stepNumber > 0) {
        return buildData.steps[stepNumber]
    }
    return {}
}

; Get current step based on zone
GetStepByZone(buildData, zoneName) {
    Loop, % buildData.steps.Length() {
        step := buildData.steps[A_Index]
        if (InStr(zoneName, step.zone_trigger)) {
            return A_Index
        }
    }
    return 1
}