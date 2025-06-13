# Claude Code Guidelines for Beachies Leveling Helper

## Application Overview
This AutoHotkey application tracks skill progression for Path of Exile leveling builds. The core functionality centers around:

### Skill Progression Tracking
- **Active Skills**: The main abilities being used at each character level
- **Support Gems**: Gems that enhance active skills, organized in linked groups
- **Quest Rewards**: Gems obtained from completing specific quests
- **Vendor Purchases**: Gems that must be bought from NPCs with specific currency costs

### Data Structure Pattern
Each progression step should include:
- **Reward**: Single gem (or none) obtained from quest completion for that tier
- **Vendor**: List of gems that need to be purchased from vendors
- **Cost**: Total currency cost for all vendor gems (usually same currency type, e.g., "3 Alchemy Orbs")

### State Management
- Persistent state tracking current progression step
- Navigation between steps independent of overall application state
- Reset functionality to restart progression tracking

## Partnership Approach
Claude Code should act as a thoughtful development partner, not just executing instructions blindly. Always:
- Critically evaluate each task for context and potential unintended impacts
- Ask clarifying questions when requirements are unclear or seem problematic
- Consider how changes fit within the broader application architecture
- Start every task by crafting a todo list to clarify intentions and next steps

## Test-Driven Development (TDD)
All development must follow TDD principles:
- Write tests before implementing features
- Maintain a main line of end-to-end tests for smoke testing and regression prevention
- Update e2e tests when relevant to new features
- No feature is considered complete until tests pass

## Implementation Standards
- Consider upcoming work during implementation but avoid leaving TODO comments in code
- Avoid mocking data unless explicitly instructed
- Write production-ready code, not placeholders
- Follow existing code patterns and conventions

## Technical Documentation
Maintain a `tech-notes.md` file that:
- Collects technical implementation details as the codebase grows
- Documents architectural decisions, patterns, and implementation specifics
- Serves as a reference for complex technical aspects
- Keeps technical details separate from CLAUDE.md
- Should be updated continuously as features are developed

## Task Management
Maintain a `current-todo.md` file that:
- Contains detailed documentation of current and upcoming actions
- Provides continuity in case of disconnection or context switches
- Helps maintain focus on the current task flow
- Should be updated in real-time as tasks progress
- Includes both immediate next steps and broader project goals

## Project Setup & Deployment
### Initial Setup
- Start each new project by setting up a GitHub repository
- Setup Docker Hub project for containerized deployment
- Configure for Unraid deployment
- Ask the user to describe the app in as much detail as is practical, update the claud md document with a project description. Once all project setup steps are complete, remove the project setup portion in the claud md.
- use create-docker-image $docker-image-name 

### Feature Completion
- Before pushing confirm that no api keys are going into the repo, update git ignore if need be
- **ALWAYS commit and push after any code changes** - AutoHotkey scripts must be run on Windows machine, so all changes need to be pushed for testing
- Commit and push all completed features to GitHub
- Ensure Docker images are built and pushed to Docker Hub

### Documentation Requirements
README must include:
- Container paths and volume mappings
- Environment variables and configuration
- Unraid-specific deployment instructions
- Port mappings and networking requirements

## AutoHotkey Development Guidelines
When working with AutoHotkey (.ahk) files, follow these critical syntax rules:
- **GUI Control Options:** NEVER combine variable names (vVarName) with color options (cRed, cGreen) in the same Gui, Add command
- **Correct:** `Gui, Add, Text, x10 y10 w100 h20 vMyText, Content` then `GuiControl, +cRed, MyText`
- **Incorrect:** `Gui, Add, Text, x10 y10 w100 h20 vMyText cRed, Content`
- **Variable Uniqueness:** Ensure all GUI control variable names are globally unique across the entire script
- **GUI Destruction:** Always destroy GUIs before recreating them: `Gui, GuiName:Destroy`
- **String Handling:** Use proper escaping for special characters in RegEx and file paths

## Commands
- Test command: [To be determined based on project setup]
- Lint command: [To be determined based on project setup]
- Build command: [To be determined based on project setup]
