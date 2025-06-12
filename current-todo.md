# Current TODO Status - POE Leveling Overlay

## Completed Core Features ✅
- **Research Phase**: Analyzed existing codebase structure, POE Vault leveling guide, and client monitoring approaches
- **Main AHK Script**: Created `PoeLevelingOverlay.ahk` with core overlay UI, build selection, and hotkey navigation (F1/F2/F3)
- **JSON Build System**: Implemented `JsonLoader.ahk` for loading build data from JSON files
- **Zone Detection**: Enhanced client log monitoring with automatic step progression based on zone changes
- **Auto-Progression**: Smart progression system that advances steps when entering matching zones
- **Sample Builds**: Created `templar-arc.json` and `ranger-poison.json` as working examples

## Current System Features
- **Build Selection UI**: Choose from 10 different class/build combinations
- **Overlay Display**: Shows current step, description, gear focus, and currency notes
- **Manual Navigation**: F1 (previous step), F2 (next step), F3 (toggle overlay)
- **Auto Zone Detection**: Monitors POE Client.txt for "You have entered" messages
- **Smart Progression**: Automatically advances or jumps to appropriate steps based on current zone
- **Multiple Tooltips**: Shows zone entry notifications and step progression updates

## Immediate Next Steps (In Priority Order)

### High Priority
1. **Create Remaining Build JSONs**: Need to complete witch-arc, witch-fire, duelist-melee, marauder-melee, shadow-poison, scion-melee builds
2. **Enhance Overlay UI**: Add gem link display areas, socket color indicators, better visual styling
3. **Add Gem Display**: Show current step's gem requirements with links and socket colors

### Medium Priority  
4. **Testing**: Test with actual POE client to verify zone detection accuracy
5. **Error Handling**: Add better error handling for missing files, invalid JSON, POE path detection
6. **Build Validation**: Cross-reference gem data with official POE wiki

### Low Priority
7. **Documentation**: Create comprehensive README with setup instructions
8. **Gear Images**: Add visual gear link representations
9. **Advanced Features**: Currency tracking, passive tree reminders, lab suggestions

## Technical Architecture
- **Main Script**: `PoeLevelingOverlay.ahk` - Core application logic
- **JSON Loader**: `JsonLoader.ahk` - Parses build data files  
- **Build Data**: `/builds/*.json` - Individual build step definitions
- **Zone Triggers**: Each step has zone_trigger field for auto-progression
- **POE Integration**: Monitors Client.txt log file for zone changes

## Current File Structure
```
beachys-leveling-ahk/
├── PoeLevelingOverlay.ahk     # Main application
├── JsonLoader.ahk             # JSON parsing utilities  
├── builds/
│   ├── templar-arc.json       # Templar Archmage Arc build
│   └── ranger-poison.json     # Ranger Poisonous Concoction build
├── levelingPaths.md           # Original gem progression data
├── clientLogMonitoring.md     # POE client integration research
└── CLAUDE.md                  # Project guidelines
```

## Known Issues to Address
- JSON parser is basic - may need refinement for complex gem data
- Need to test POE path detection on different installations
- Overlay positioning/styling could be improved
- Missing builds need to be created from levelingPaths.md data

## Connection Recovery Notes
If disconnected, the system is at a functional state with:
- Working overlay UI with build selection
- Zone detection and auto-progression  
- Two complete build examples (Templar Arc, Ranger Poison)
- Manual navigation via hotkeys
- JSON loading infrastructure in place

Next immediate action would be creating the remaining 8 build JSON files to complete the build selection options.