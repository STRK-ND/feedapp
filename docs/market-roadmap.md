# Market-driven feature roadmap

Derived from the 2025–2026 RSS reader market (Inoreader, Feedly, Feedbin,
NewsBlur, FeedSpot, Reeder, Readwise Reader, NewsNinja, self-hosted Miniflux/
FreshRSS) mapped against what Curated Feeds already ships. Sources are listed
at the bottom.

## Where the market is

- **AI summaries are the paid-tier battleground.** Inoreader Intelligence
  (Mar 2025), Feedly's Leo and NewsNinja+ all gate summaries and prompt-on-
  article behind their paid tiers. Users pay for *less reading*, not more app.
- **The #1 real-world complaint is teaser feeds** — a headline and one
  sentence with a link out. Eight of ten kept Hacker News complaints in one
  2026 roundup describe exactly this. Readers that fetch the full article
  (Feedbin, Miniflux, smry) win on it.
- **The Pocket shutdown (Jul 2025) and Omnivore's death (Oct 2024) moved a
  wave of read-later users** toward readers with strong saved-article and
  highlight workflows (Readwise Reader) — an opening for saved-article depth.
- **Filtering and rules are the power-user lock-in**: Inoreader rules,
  Feedly mute filters, NewsBlur training. Power readers stay where noise is
  removable.
- **Newsletters-as-feeds** (Inoreader Pro's newsletter inbox) is the fastest
  growing source type beyond RSS itself.
- **Privacy / no-account** is a real differentiator (NetNewsWire, NewsNinja)
  for a segment that rejects required logins.
- **Discovery**: FeedSpot's 750k-source directory is its standout feature;
  source discovery remains unsolved for most readers.

## Current state (what already ships)

Card-stack one-article triage, saved articles with free cap + paywall,
keyword push alerts (worker `/subscribe`), full-text extraction per article
(`ArticleContentService`), TTS playback, OPML import/export, custom sources,
cloud sync, search in the feed screen, in-app review + analytics funnel.

## Tier 1 — next 1–2 releases (high market need, high fit)

### 1. AI triage summary on the article card
The app's one-article-per-screen triage is the exact surface where a 2–3 line
summary changes the read/skip decision — and every competitor puts summaries
behind their paid tier, so it is a proven Pro conversion lever.
Ship as a Pro-gated "Summarize" action on the expanded card, proxied through
the worker (key stays server-side), with a monthly token budget per Pro user
mirroring Inoreader's model. Non-AI filtering of what the user sees stays
off the table — Inoreader's "you decide when" framing is what users accepted.

### 2. Teaser-feed full text at ingestion
`ArticleContentService` already extracts full content per article on demand,
but the worker emits no extracted body (the 1.0.2 audit removed `fullContent`
as a description duplicate — extraction never happens server-side). Extend
the worker's ingestion to run extraction when the feed item body is shorter
than a threshold, store the extracted text, and let the client prefer it.
This attacks the single most-cited reader complaint and no action by the
user is needed.

### 3. Mute filters / keyword rules
The app has keyword *alerts* (push on match) but no keyword *muting* — the
mirror-image power-user feature that Inoreader (rules) and Feedly (mute
filters) gate paid tiers on. Client-side filter over `FilterParams` plus a
worker-side drop rule; UI in Settings → Feed Settings. Cheapest high-value
item on this list.

### 4. Full-text search (SQLite FTS5)
Search today covers the feed list; Inoreader gates body search behind a paid
tier, so it is both a market-expected capability and a Pro lever. FTS5 over
the local `articles` and `saved_articles` tables (bodies already cached)
gives offline full-text search with no worker changes.

## Tier 2 — following releases (clear need, medium effort)

### 5. Saved-article depth: highlights, notes, export
Position the Saved tab for the post-Pocket migration: per-paragraph
highlights and a note field, then export (Markdown share, and later
Readwise-compatible output). Readwise charges $9.99/mo mostly for this
workflow; a reader that already saves articles can capture it cheaply.

### 6. Home-screen widget + daily digest notification
Android-only is an advantage here: rivals spread thin across platforms and
their Android widgets lag. A "today's unread" widget plus one scheduled
digest notification (top unread by category) matches NewsNinja's daily
notification pattern and pulls daily retention.

### 7. Source discovery
A categorized directory of curated sources (extending the predefined
`RssFeedService.predefinedSources`) with one-tap subscribe. FeedSpot proves
discovery is a headline feature; the worker already holds the subscription
registry to build it on.

## Tier 3 — exploratory (real market pull, larger builds)

### 8. Newsletter-to-feed inbox
Inoreader sells this as a Pro feature; the Pocket/Omnivore diaspora also
lands here. Requires a per-user inbound email address on the worker
(Cloudflare Email Routing) rendered as ordinary articles. Large build;
do after Tier 1 proves the Pro funnel.

### 9. Podcast / YouTube in the feed
FeedSpot plays podcasts and TTS in the same feed; enclosures from YouTube
channel feeds are low-hanging. The existing TTS service is a natural base
for listen-to-article, which is a differentiator none of the big readers
do well on Android.

### 10. Local-only / no-account mode
NewsNinja and NetNewsWire win a privacy segment on "no account required."
Offering sync as optional (app works fully without login) is mostly a
packaging change given the local-first storage already in place, and
removes the biggest onboarding drop-off.

## Sources

- Inoreader Intelligence announcement — inoreader.com/blog/2025/03/inoreader-intelligence-and-article-summaries-are-here.html
- Inoreader's 2026 reader comparison — inoreader.com/best-rss-readers
- smry 2026 roundup incl. Hacker News complaint analysis — smry.ai/best-rss-readers
- Inoreader vs Feedly feature/pricing table — keep.md/compare/inoreader-vs-feedly
- FeedSpot reader comparison (directory, TTS, newsletter digest) — feedspot.com/blog/best-rss-reader/
- Post-Pocket landscape deep dive — ttlab.hopto.org blog, 2026-05-16
