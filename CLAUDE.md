# Claude Code Guidelines for Beachies Uploader

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
- Commit and push all completed features to GitHub
- Ensure Docker images are built and pushed to Docker Hub

### Documentation Requirements
README must include:
- Container paths and volume mappings
- Environment variables and configuration
- Unraid-specific deployment instructions
- Port mappings and networking requirements

## Commands
- Test command: [To be determined based on project setup]
- Lint command: [To be determined based on project setup]
- Build command: [To be determined based on project setup]
