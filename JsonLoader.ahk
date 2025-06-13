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
    
    ; Extract enhanced optional fields
    RegExMatch(stepText, """objective_type"":\s*""([^""]+)""", objTypeMatch)
    step.objective_type := objTypeMatch1 ? objTypeMatch1 : "quest_complete"
    
    RegExMatch(stepText, """reward_vendor"":\s*""([^""]+)""", vendorMatch)
    step.reward_vendor := vendorMatch1 ? vendorMatch1 : ""
    
    RegExMatch(stepText, """auto_advance"":\s*(true|false)", autoAdvanceMatch)
    step.auto_advance := (autoAdvanceMatch1 = "true") ? true : false
    
    RegExMatch(stepText, """zone_sequence"":\s*(true|false)", sequenceMatch)
    step.zone_sequence := (sequenceMatch1 = "true") ? true : false
    
    RegExMatch(stepText, """multi_zone_logic"":\s*""([^""]+)""", multiLogicMatch)
    step.multi_zone_logic := multiLogicMatch1 ? multiLogicMatch1 : "all"
    
    ; Extract zones_required array (fallback to zone_trigger if not specified)
    step.zones_required := []
    zonesStart := InStr(stepText, """zones_required"":")
    if (zonesStart > 0) {
        bracketStart := InStr(stepText, "[", zonesStart)
        if (bracketStart > 0) {
            ; Find matching closing bracket for zones array
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
                zonesContent := SubStr(stepText, bracketStart + 1, bracketEnd - bracketStart - 1)
                if (Trim(zonesContent) != "") {
                    ; Parse zone strings from array
                    pos := 1
                    while (pos <= StrLen(zonesContent)) {
                        quoteStart := InStr(zonesContent, """", pos)
                        if (quoteStart = 0)
                            break
                        quoteEnd := InStr(zonesContent, """", quoteStart + 1)
                        if (quoteEnd = 0)
                            break
                        
                        zoneName := SubStr(zonesContent, quoteStart + 1, quoteEnd - quoteStart - 1)
                        step.zones_required.Push(zoneName)
                        pos := quoteEnd + 1
                    }
                }
            }
        }
    }
    
    ; If no zones_required specified, fallback to zone_trigger
    if (step.zones_required.Length() = 0 && step.zone_trigger != "") {
        step.zones_required.Push(step.zone_trigger)
    }
    
    ; Extract reward (single gem or null)
    step.reward := ""
    rewardStart := InStr(stepText, """reward"":")
    if (rewardStart > 0) {
        ; Check if reward is null
        nullMatch := InStr(stepText, "null", rewardStart)
        braceMatch := InStr(stepText, "{", rewardStart)
        
        if (nullMatch > 0 && (braceMatch = 0 || nullMatch < braceMatch)) {
            step.reward := ""
        } else if (braceMatch > 0) {
            ; Parse reward object
            braceCount := 1
            pos := braceMatch + 1
            braceEnd := 0
            
            while (pos <= StrLen(stepText) && braceCount > 0) {
                char := SubStr(stepText, pos, 1)
                if (char = "{")
                    braceCount++
                else if (char = "}")
                    braceCount--
                
                if (braceCount = 0)
                    braceEnd := pos
                
                pos++
            }
            
            if (braceEnd > 0) {
                rewardContent := SubStr(stepText, braceMatch, braceEnd - braceMatch + 1)
                step.reward := ParseGemObject(rewardContent)
            }
        }
    }
    
    ; Extract vendor array
    step.vendor := []
    vendorStart := InStr(stepText, """vendor"":")
    if (vendorStart > 0) {
        bracketStart := InStr(stepText, "[", vendorStart)
        if (bracketStart > 0) {
            ; Find matching closing bracket for vendor array
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
                vendorContent := SubStr(stepText, bracketStart + 1, bracketEnd - bracketStart - 1)
                if (Trim(vendorContent) != "") {
                    vendorObjs := ParseGemsArray(vendorContent)
                    Loop, % vendorObjs.Length() {
                        vendorData := ParseGemObject(vendorObjs[A_Index])
                        step.vendor.Push(vendorData)
                    }
                }
            }
        }
    }
    
    ; Extract cost
    RegExMatch(stepText, """cost"":\s*""([^""]*)""", costMatch)
    step.cost := costMatch1 ? costMatch1 : ""
    
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
    
    RegExMatch(gemText, """vendor_npc"":\s*""([^""]+)""", gemVendorMatch)
    gem.vendor_npc := gemVendorMatch1 ? gemVendorMatch1 : ""
    
    RegExMatch(gemText, """priority"":\s*(\d+)", gemPriorityMatch)
    gem.priority := gemPriorityMatch1 ? gemPriorityMatch1 : 1
    
    ; Extract links array
    gem.links := []
    linksStart := InStr(gemText, """links"":")
    if (linksStart > 0) {
        bracketStart := InStr(gemText, "[", linksStart)
        if (bracketStart > 0) {
            ; Find matching closing bracket for links array
            bracketCount := 1
            pos := bracketStart + 1
            bracketEnd := 0
            
            while (pos <= StrLen(gemText) && bracketCount > 0) {
                char := SubStr(gemText, pos, 1)
                if (char = "[")
                    bracketCount++
                else if (char = "]")
                    bracketCount--
                
                if (bracketCount = 0)
                    bracketEnd := pos
                
                pos++
            }
            
            if (bracketEnd > 0) {
                linksContent := SubStr(gemText, bracketStart + 1, bracketEnd - bracketStart - 1)
                if (Trim(linksContent) != "") {
                    ; Parse link strings from array
                    pos := 1
                    while (pos <= StrLen(linksContent)) {
                        quoteStart := InStr(linksContent, """", pos)
                        if (quoteStart = 0)
                            break
                        quoteEnd := InStr(linksContent, """", quoteStart + 1)
                        if (quoteEnd = 0)
                            break
                        
                        linkName := SubStr(linksContent, quoteStart + 1, quoteEnd - quoteStart - 1)
                        gem.links.Push(linkName)
                        pos := quoteEnd + 1
                    }
                }
            }
        }
    }
    
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