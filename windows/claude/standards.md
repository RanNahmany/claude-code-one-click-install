# Project Standards

This document outlines standards and guidelines for developing the Claude Code Windows Installer project.

## Documentation Standards

### When to Create Documentation
- Create documentation for any new component, script, or tool added to the project
- Document installation procedures and requirements
- Provide usage examples for scripts and tools
- Document any configuration or setup steps

### Documentation Structure
- Use clear, descriptive headings
- Include code examples where applicable
- Provide step-by-step instructions for complex procedures
- Keep documentation up-to-date with code changes

### File Naming Conventions
- Use lowercase with hyphens for script files (e.g., `install-claude.ps1`)
- Use descriptive names that indicate purpose
- Group related files in appropriate directories

## Code Standards

### PowerShell Scripts
- Use approved verbs for function names
- Include comment-based help for all functions
- Handle errors gracefully with appropriate error messages
- Test scripts on multiple Windows versions when possible

### Batch Files
- Include comments explaining complex operations
- Use consistent indentation
- Provide clear success/failure feedback

## Version Control Standards

- Use descriptive commit messages
- Create feature branches for new functionality
- Test changes before committing
- Keep commits focused on single features or fixes

*This document will be expanded as development standards are established.*