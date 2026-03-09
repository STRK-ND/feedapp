## Context

The app currently lacks a proper Android application icon. Android requires icons in multiple densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi) to display correctly on different screen resolutions. Additionally, Android 8.0+ (API 26+) requires adaptive icons with foreground and background layers.

The provided SVG design features:
- A circular gradient border (pink #ff6b9d to purple #c9b6df)
- A center eye/window shape representing the RSS reader functionality
- A filled center circle

## Goals / Non-Goals

**Goals:**
- Generate all required PNG icon sizes from the SVG design
- Configure adaptive icon for Android 8.0+ devices
- Fallback to simple launcher icon for older Android versions
- Ensure the icon displays correctly across all Android devices

**Non-Goals:**
- iOS icon generation (separate platform)
- Dynamic icon themes
- Customization UI for users to change icons

## Decisions

### Icon Format
- **Decision**: Use PNG files for legacy icons and adaptive icon XML for modern Android
- **Rationale**: Android requires PNG for mipmap directories. Adaptive icons provide better visual effects on Android 8+.

### Density Sizes
- **Decision**: Generate icons for all 5 standard Android densities
- **Rationale**: Ensures crisp display on all devices from low to ultra-high density screens.

### Icon Placement
- **Decision**: Place icons in `android/app/src/main/res/mipmap-*` directories
- **Rationale**: Standard Android location for launcher icons. Flutter/Gradle will automatically use these.

## Risks / Trade-offs

- **Risk**: SVG to PNG conversion may lose quality
  - **Mitigation**: Use high-resolution source (192x192 xxxhdpi) and scale down for smaller densities
- **Risk**: Adaptive icon may not display correctly on some launchers
  - **Mitigation**: Provide both adaptive icon and legacy PNG icons as fallback