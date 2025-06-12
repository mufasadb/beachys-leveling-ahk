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
    
    ; Find the steps array
    RegExMatch(jsonText, """steps"":\s*\[(.*)\]", stepsMatch)
    stepsContent := stepsMatch1
    
    ; Split steps by step objects
    Loop, Parse, stepsContent, {}
    {
        stepContent := A_LoopField
        if (stepContent = "")
            continue
            
        ; Extract step data
        step := {}
        
        RegExMatch(stepContent, """step"":\s*(\d+)", stepNum)
        step.step := stepNum1
        
        RegExMatch(stepContent, """act"":\s*(\d+)", actNum)
        step.act := actNum1
        
        RegExMatch(stepContent, """zone"":\s*""([^""]+)""", zoneMatch)
        step.zone := zoneMatch1
        
        RegExMatch(stepContent, """zone_trigger"":\s*""([^""]+)""", triggerMatch)
        step.zone_trigger := triggerMatch1
        
        RegExMatch(stepContent, """title"":\s*""([^""]+)""", titleMatch)
        step.title := titleMatch1
        
        RegExMatch(stepContent, """description"":\s*""([^""]+)""", descMatch)
        step.description := descMatch1
        
        RegExMatch(stepContent, """gear_focus"":\s*""([^""]+)""", gearMatch)
        step.gear_focus := gearMatch1
        
        RegExMatch(stepContent, """currency_notes"":\s*""([^""]+)""", currencyMatch)
        step.currency_notes := currencyMatch1
        
        ; Extract gems array (simplified)
        step.gems_available := []
        RegExMatch(stepContent, """gems_available"":\s*\[(.*?)\]", gemsMatch)
        if (gemsMatch1 != "") {
            ; Parse gems (basic implementation for now)
            gemsContent := gemsMatch1
            ; This would need more complex parsing for full gem data
        }
        
        buildData.steps.Push(step)
    }
    
    return buildData
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