## ADDED Requirements

### Requirement: App fetches articles from Cloudflare Worker

The app SHALL fetch articles by making an HTTP GET request to the configured Cloudflare Worker API endpoint instead of fetching RSS feeds directly.

#### Scenario: Successful fetch from Worker
- **WHEN** the app calls the Worker API endpoint and receives a successful response
- **THEN** the app SHALL parse the JSON response into Article objects
- **AND** SHALL store the articles in local storage
- **AND** SHALL display them in the feed

#### Scenario: Worker returns cached response
- **WHEN** the Worker returns a cached response (within TTL)
- **THEN** the app SHALL process the cached articles normally
- **AND** no user-facing indication of caching is required

#### Scenario: Worker is unavailable (network error)
- **WHEN** the app cannot reach the Worker API (network timeout, DNS failure)
- **THEN** the app SHALL display an error message to the user
- **AND** SHALL offer a retry button
- **AND** SHALL NOT attempt to fall back to direct RSS fetching

#### Scenario: Worker returns error response
- **WHEN** the Worker returns HTTP status >= 400
- **THEN** the app SHALL display a user-friendly error message
- **AND** SHALL log the error for debugging

#### Scenario: Worker returns empty article list
- **WHEN** the Worker returns a valid response with an empty articles array
- **THEN** the app SHALL show an empty state with appropriate messaging
- **AND** SHALL NOT crash or show an error

### Requirement: Worker API returns complete article data

The Worker API SHALL return JSON containing all fields needed to display articles in the app.

#### Scenario: Worker returns all required fields
- **WHEN** the Worker returns articles
- **THEN** each article SHALL contain: id, title, description, link, sourceId, sourceName, pubDate
- **AND** MAY contain: fullContent, author, imageUrl, sourceCategory, sourceColor, sourceIcon

#### Scenario: Article missing optional fields
- **WHEN** an article from the Worker is missing optional fields
- **THEN** the app SHALL use null/empty defaults for missing fields
- **AND** SHALL still display the article

### Requirement: Worker API is cached

The app SHALL NOT fetch from the Worker on every pull-to-refresh if recent data exists.

#### Scenario: Recent data in local storage
- **WHEN** the user triggers a refresh
- **AND** cached articles exist in local storage
- **THEN** the app MAY show cached articles first
- **AND** THEN fetch fresh data from Worker in the background

#### Scenario: Force refresh requested
- **WHEN** the user explicitly requests a force refresh
- **THEN** the app SHALL fetch from Worker regardless of cache state
- **AND** SHALL update local storage with new articles