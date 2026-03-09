## Context

The application is ready for its first official release (v1.0.0). The current codebase has the version set in pubspec.yaml but lacks proper release documentation, changelog, and in-app version display.

## Goals / Non-Goals

**Goals:**
- Document the v1.0.0 release with a CHANGELOG
- Display version information in the app's settings/about section
- Ensure production builds are properly configured

**Non-Goals:**
- Not adding new features - this is a release preparation task
- Not updating any app functionality

## Decisions

1. **Version display location**: Add to Settings screen (accessible from drawer/menu)
   - Alternative: Separate About screen - but Settings is simpler and more discoverable

2. **CHANGELOG format**: Keep it simple with initial release documentation
   - Use standard keepachangelog format for future updates

## Risks / Trade-offs

- Low risk - this is documentation and minor UI addition
- No breaking changes