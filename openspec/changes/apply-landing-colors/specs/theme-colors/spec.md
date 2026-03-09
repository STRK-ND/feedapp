## ADDED Requirements

### Requirement: Dark indigo-purple theme colors
The app SHALL use the dark indigo-purple color scheme from the Curated Feeds landing page, consisting of deep indigo primary colors, coral pink accent, and dark backgrounds.

#### Scenario: Primary colors applied
- **WHEN** app loads
- **THEN** primary color is #1A1B4D (deep indigo)
- **AND** primary light color is #2D2F73 (lighter indigo)
- **AND** primary dark color is #4A3B5C (purple)

#### Scenario: Accent color applied
- **WHEN** app displays interactive elements (buttons, links)
- **THEN** accent color is #FF6B9D (coral pink)
- **AND** accent light color is #FFA0B8

#### Scenario: Dark background colors
- **WHEN** app displays main background
- **THEN** background color is #0D0E1A (dark navy)
- **AND** background secondary is #14162B (darker navy)

#### Scenario: Text colors for dark theme
- **WHEN** app displays text
- **THEN** primary text is #F8FAFC (off-white)
- **AND** secondary text is #94A3B8 (muted gray)
- **AND** tertiary text is #64748B (dark gray)

#### Scenario: Surface colors for cards
- **WHEN** app displays card surfaces
- **THEN** surface color uses semi-transparent white (rgba(255, 255, 255, 0.03))
- **AND** surface hover uses rgba(255, 255, 255, 0.06)
- **AND** surface border uses rgba(255, 255, 255, 0.08)

#### Scenario: Semantic colors
- **WHEN** app displays status indicators
- **THEN** success color is #4ADE80 (green)
- **AND** warning color is #FBBF24 (amber)
- **AND** error color remains #DC3640 (refined red)

#### Scenario: Gradients
- **WHEN** app displays gradient backgrounds
- **THEN** primary gradient is linear-gradient from #1A1B4D to #2D2F73 to #4A3B5C
- **AND** accent gradient is linear-gradient from #FF6B9D to #C9B6DF