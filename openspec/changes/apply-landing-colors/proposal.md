## Why

The Flutter app currently uses a default blue theme that doesn't match the brand identity established in the Curated Feeds landing page. Applying the landing page's elegant dark indigo-purple theme will create visual consistency across the product and improve the user experience with a more polished, cohesive design.

## What Changes

- Replace the app's color scheme with the landing page's dark indigo-purple gradient theme
- Update primary colors: deep indigo (#1a1b4d), lighter indigo (#2d2f73), purple (#4a3b5c)
- Apply accent color: coral pink (#ff6b9d)
- Use dark backgrounds: #0d0e1a (main), #14162b (secondary)
- Update text colors for dark theme readability
- Add gradient backgrounds matching the landing page aesthetics

## Capabilities

### New Capabilities

- **theme-colors**: Define the complete color palette matching the Curated Feeds landing page design, including primary, accent, surface, and text colors

### Modified Capabilities

- None - this is a visual refresh of the existing theme

## Impact

- **Files**: lib/utils/constants.dart (color constants), lib/theme/ (Flutter theme configuration)
- **Dependencies**: None - using built-in Flutter theming
- **UI Components**: All screens and widgets will inherit the new color scheme