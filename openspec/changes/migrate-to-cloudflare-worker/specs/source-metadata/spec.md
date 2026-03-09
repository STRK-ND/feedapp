## ADDED Requirements

### Requirement: Source metadata accompanies each article

The app SHALL receive source metadata (category, color, icon) alongside each article from the Worker API.

#### Scenario: Source metadata present in response
- **WHEN** the Worker returns articles with source metadata
- **THEN** the app SHALL use the provided category for filtering
- **AND** SHALL use the provided color for UI theming
- **AND** SHALL use the provided icon for source display

#### Scenario: Source metadata missing from response
- **WHEN** an article lacks source metadata fields
- **THEN** the app SHALL use a default category of "Tech"
- **AND** SHALL use a default color (#1A1B4D - primary)
- **AND** SHALL use a default icon (article icon)

### Requirement: Category filtering uses source metadata

The app SHALL filter articles by category using the metadata from the Worker response.

#### Scenario: Filter by category
- **WHEN** user selects a category filter (e.g., "Tech")
- **THEN** the app SHALL show only articles where sourceCategory matches
- **AND** SHALL update the UI to reflect the active filter

### Requirement: Source display in cards

The app SHALL display source information on article cards using the metadata from the response.

#### Scenario: Display source on card
- **WHEN** rendering an article card
- **THEN** the app SHALL show the source name (sourceName)
- **AND** SHALL apply the source color as a visual accent
- **AND** SHALL display the source icon if available