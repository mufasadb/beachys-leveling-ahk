# POE Leveling Overlay - Technical Implementation Notes

## Project Overview
A Path of Exile leveling overlay system built with AutoHotkey that provides real-time guidance for gem progression, gear requirements, and currency management. The system monitors POE client logs to automatically advance through leveling steps based on zone changes, while providing manual navigation controls for edge cases.

## Architecture Design

### Core Components
1. **Main Application** (`PoeLevelingOverlay.ahk`)
   - Primary overlay GUI with step display
   - Build selection interface
   - Zone monitoring and auto-progression logic
   - Hotkey handlers for manual navigation

2. **JSON Data System** (`JsonLoader.ahk` + `/builds/*.json`)
   - Custom JSON parser for AutoHotkey (AHK lacks native JSON support)
   - Build data files containing step-by-step progression
   - Zone trigger mapping for automatic advancement

3. **POE Integration** (Client.txt monitoring)
   - Real-time log file monitoring for zone changes
   - Multiple installation path detection
   - Zone name extraction and step matching

### Data Flow
1. User selects build → JSON file loaded → BuildData populated
2. POE client logs zone change → Zone name extracted → Step progression logic triggered
3. Step data updated → Overlay GUI refreshed → User sees current guidance

## File Structure & Dependencies

```
beachys-leveling-ahk/
├── PoeLevelingOverlay.ahk     # Main application (298 lines)
├── JsonLoader.ahk             # JSON parsing utilities (91 lines)
├── builds/                    # Build data directory
│   ├── templar-arc.json       # Templar Archmage Arc (complete)
│   └── ranger-poison.json     # Ranger Poisonous Concoction (complete)
├── levelingPaths.md           # Source gem progression data
├── clientLogMonitoring.md     # POE integration research
├── current-todo.md            # Detailed task tracking
├── tech-notes.md             # This file
└── CLAUDE.md                 # Project guidelines
```

## Technical Implementation Details

### Zone Detection System
**Mechanism**: Monitor POE's `Client.txt` log file for zone change events
**Pattern**: Lines containing `: You have entered [Zone Name].`
**Frequency**: 250ms polling interval via AutoHotkey SetTimer
**Paths Checked**:
- `C:\Program Files (x86)\Grinding Gear Games\Path of Exile\logs\Client.txt`
- `C:\Program Files (x86)\Steam\steamapps\common\Path of Exile\logs\Client.txt`
- `C:\Program Files\Grinding Gear Games\Path of Exile\logs\Client.txt`
- `C:\Program Files\Steam\steamapps\common\Path of Exile\logs\Client.txt`

**Auto-Progression Logic**:
1. Extract zone name from log entry using RegEx: `": You have entered (.*?)\."`
2. Check if next step's `zone_trigger` matches current zone → Auto-advance
3. Search all steps for zone match → Jump to appropriate step if ahead
4. Display tooltips for progression notifications

### JSON Build Data Structure
Each build file contains:
```json
{
  "name": "Build Display Name",
  "class": "Character Class", 
  "build_url": "External build guide URL",
  "video_url": "Video guide URL",
  "steps": [
    {
      "step": 1,
      "act": 1,
      "zone": "Human-readable zone name",
      "zone_trigger": "Exact text for matching",
      "title": "Step title",
      "description": "What to do",
      "gems_available": [
        {
          "name": "Gem Name",
          "quest": "Quest Name", 
          "links": ["Support gems"],
          "notes": "Usage notes"
        }
      ],
      "gear_focus": "Gear priority",
      "currency_notes": "Currency management"
    }
  ]
}
```

### AutoHotkey GUI System
**Main Overlay Controls**:
- `StepHeader`: Shows "Step X/Y: Act Z - Title"
- `StepDescription`: Zone and action description  
- `GearInfo`: Current gear focus
- `CurrencyInfo`: Currency management notes
- Navigation buttons: Previous, Next, Hide/Show, Build Select

**Build Selection Dialog**:
- Radio buttons for 10 class/build combinations
- Mapped to JSON file identifiers (e.g., `templar-arc`)

**Hotkey Bindings**:
- `F1`: Previous step (with bounds checking)
- `F2`: Next step (with bounds checking)  
- `F3`: Toggle overlay visibility
- `Ctrl+Esc`: Exit application

### JSON Parser Implementation
**Challenge**: AutoHotkey lacks native JSON support
**Solution**: Custom regex-based parser in `JsonLoader.ahk`

**Parser Functions**:
- `LoadBuildFromJSON(buildName)`: Main loading function
- `ParseBasicJSON(jsonText)`: Extract build metadata and steps array
- `GetStepData(buildData, stepNumber)`: Retrieve specific step
- `GetStepByZone(buildData, zoneName)`: Find step by zone trigger

**Limitations**: Current parser handles flat structure, may need enhancement for complex nested gem data

## Build Data Sources & Validation

### Primary Sources
1. **levelingPaths.md**: Detailed gem progression tables by class/build
   - Contains quest rewards, vendor availability, link suggestions
   - Organized by character class with multiple build options
   - Includes build URLs and video references

2. **POE Vault Leveling Guide**: Zone progression patterns
   - URL: `https://www.poe-vault.com/guides/quick-reference-leveling-guide-for-path-of-exile`
   - Provides exact zone sequence for Acts 1-10
   - Used for zone_trigger mapping in build steps

### Completed Builds
**Templar Archmage Arc** (`templar-arc.json`):
- 8 complete steps covering Acts 1-4
- Based on pobb.in/SzTQ93UAMxMl build
- Key gems: Rolling Magma → Arc + Archmage Support + Spell Echo
- Focus on mana scaling and lightning damage

**Ranger Poisonous Concoction** (`ranger-poison.json`):
- 8 complete steps covering Acts 1-4  
- Based on pobb.in/t4XCSGNL6RcZ build
- Key gems: Caustic Arrow → Poisonous Concoction + supports
- Focus on poison scaling and life flask management

### Remaining Builds (from levelingPaths.md)
1. **Templar Fire Caster** (Armageddon Brand/Cremation)
2. **Witch Archmage Arc** (identical gems to Templar version)
3. **Witch Fire Caster** (Armageddon Brand/Cremation)
4. **Ranger Lightning Arrow** (Trinity Support build)
5. **Duelist Melee** (Sunder/Boneshatter)
6. **Marauder Melee** (Sunder/Boneshatter)
7. **Shadow Trap/Poison** (Cobra Lash/Explosive Trap)
8. **Scion Melee** (Splitting Steel/Sunder)

## Current System State

### Working Features
✅ **POE Path Detection**: Automatically finds Client.txt across installation types
✅ **Zone Monitoring**: Real-time detection of zone changes via log parsing
✅ **Auto-Progression**: Smart advancement based on zone triggers
✅ **Manual Navigation**: F1/F2 hotkeys with bounds checking
✅ **Build Selection**: Complete UI for choosing builds
✅ **Overlay Display**: All step information visible and updating
✅ **JSON Loading**: Flexible build data system
✅ **Error Handling**: Basic fallbacks for missing data/files

### Known Limitations
⚠️ **JSON Parser**: Basic regex implementation, may need enhancement for complex gem arrays
⚠️ **Build Coverage**: Only 2 of 10 builds completed
⚠️ **UI Styling**: Functional but minimal visual design
⚠️ **Gem Display**: No visual representation of socket colors/links
⚠️ **Testing**: Not yet tested with actual POE client

### Performance Characteristics
- **Memory**: Minimal AHK script footprint
- **CPU**: 250ms timer interval for log monitoring
- **Disk I/O**: Single file read per timer cycle
- **Responsiveness**: Immediate UI updates on step changes

## Integration Points

### POE Client Requirements
- **Log File Access**: Read-only access to Client.txt
- **No Game Modification**: Completely external overlay
- **TOS Compliance**: Read-only log monitoring is explicitly allowed
- **Installation Agnostic**: Works with Steam and standalone clients

### External Dependencies
- **AutoHotkey**: Core runtime requirement
- **JSON Build Files**: Must be present in `/builds/` directory
- **POE Installation**: Client.txt must be accessible

### Future Enhancement Opportunities
1. **Advanced JSON Parser**: Native library or more robust regex
2. **Image Assets**: Gear link visualizations, gem icons
3. **Database Integration**: Dynamic gem/quest data from wiki APIs
4. **Performance Optimization**: Incremental log reading, caching
5. **UI Improvements**: Themes, resizing, positioning options
6. **Multi-Monitor Support**: Overlay positioning controls

## Development Workflow & Best Practices

### Build Creation Process
1. Extract gem data from `levelingPaths.md` for specific class/build
2. Map quest rewards to appropriate acts/zones using POE Vault guide
3. Create zone triggers that match POE's zone naming exactly
4. Test progression flow for logical step advancement
5. Validate gem links and socket color requirements

### Zone Trigger Mapping Strategy
- Use exact zone names as they appear in POE logs
- Consider zone variations (e.g., "The Coast" vs "Coast")
- Map major progression points, not every possible zone
- Focus on quest completion locations and gem acquisition points

### Testing Approach
1. **Offline Testing**: Verify GUI functionality, JSON loading, navigation
2. **Log Simulation**: Create test Client.txt entries for zone detection
3. **Live Integration**: Test with actual POE client during leveling
4. **Build Validation**: Compare progression against source guides

### Code Organization Principles
- **Separation of Concerns**: UI, data loading, and POE integration in separate functions
- **Data-Driven Design**: All build information in external JSON files
- **Error Resilience**: Graceful handling of missing files, invalid data
- **Extensibility**: Easy addition of new builds without code changes

## Troubleshooting & Common Issues

### POE Path Detection Failures
**Symptoms**: "Could not find POE Client.txt file" error
**Solutions**:
1. Verify POE installation location
2. Check file permissions on logs directory
3. Manually select Client.txt via file dialog
4. Ensure POE has been run at least once (creates logs)

### Zone Detection Not Working
**Symptoms**: No tooltips on zone changes, no auto-progression
**Solutions**:
1. Verify Client.txt is being written to (check file modification time)
2. Test with manual zone changes in game
3. Check log file format matches expected pattern
4. Ensure AHK script has file read permissions

### Build Data Loading Issues
**Symptoms**: "Build file not found" or empty overlay display
**Solutions**:
1. Verify JSON file exists in `/builds/` directory
2. Check JSON syntax validity
3. Ensure build identifier matches file name
4. Test JSON parser with simplified data

### Step Progression Problems
**Symptoms**: Steps not advancing or jumping incorrectly
**Solutions**:
1. Verify zone_trigger text matches POE zone names exactly
2. Check step numbering sequence in JSON
3. Test manual navigation to isolate auto-progression issues
4. Review zone detection logs/tooltips

## Future Roadmap & Enhancement Ideas

### Phase 1: Core Completion
- Complete all 8 remaining build JSON files
- Enhanced overlay UI with gem display areas
- Socket color indicators and link visualization
- Comprehensive testing with POE client

### Phase 2: Advanced Features
- Passive tree progression reminders
- Labyrinth completion tracking
- Vendor recipe suggestions
- Currency requirement calculations

### Phase 3: Polish & Distribution
- Installer/setup automation
- User configuration options
- Performance optimizations
- Community build contributions

### Phase 4: Integration Expansion
- Multiple character tracking
- League-specific adaptations
- Build guide generator
- Community sharing platform

This technical documentation provides complete context for resuming development at any point, with sufficient detail for understanding implementation decisions, current state, and future direction.