// Tests for the Curated Feeds Cloudflare Worker.
// NOTE: All fixtures below are inline (no external files, no network).
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  SOURCES,
  parseRss,
  extractRssItems,
  extractAtomEntries,
  buildArticle,
  stableId,
  parseDate,
  extractTag,
  strip,
  signRs256,
  base64UrlEncode,
  ARTICLES_CACHE_KEY,
} from '../feed-worker.js';

const RSS_XML = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>First article</title>
      <link>https://example.com/1</link>
      <description>First description</description>
      <pubDate>Tue, 28 Jul 2026 18:11:00 BST</pubDate>
    </item>
    <item>
      <title>Second article</title>
      <link>https://example.com/2</link>
      <description>Second description</description>
      <pubDate>Mon, 27 Jul 2026 09:30:00 GMT</pubDate>
    </item>
  </channel>
</rss>`;

const ATOM_XML = `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Test</title>
  <entry>
    <title>Atom one</title>
    <link href="https://example.com/a1"/>
    <summary>Summary one</summary>
    <published>2026-07-28T18:11:00Z</published>
  </entry>
  <entry>
    <title>Atom two</title>
    <link href="https://example.com/a2"/>
    <summary>Summary two</summary>
    <published>2026-07-27T09:30:00Z</published>
  </entry>
</feed>`;

const itemOpts = {
  titleTag: 'title',
  linkTag: 'link',
  descTag: 'description',
  pubDateTag: 'pubDate',
  authorTag: 'author',
  fullContentTag: 'content:encoded',
};

test('parseRss parses RSS fixture (2 items) and Atom fixture (2 entries)', () => {
  const source = SOURCES[0];

  const rss = parseRss(RSS_XML, source);
  assert.equal(rss.length, 2);
  assert.equal(rss[0].title, 'First article');
  assert.equal(rss[0].link, 'https://example.com/1');
  assert.equal(typeof rss[0].pubDate, 'number');
  assert.equal(rss[1].title, 'Second article');
  assert.equal(rss[1].link, 'https://example.com/2');
  assert.equal(typeof rss[1].pubDate, 'number');

  const atom = parseRss(ATOM_XML, source);
  assert.equal(atom.length, 2);
  assert.equal(atom[0].title, 'Atom one');
  assert.equal(atom[0].link, 'https://example.com/a1');
  assert.equal(typeof atom[0].pubDate, 'number');
  assert.equal(atom[1].title, 'Atom two');
  assert.equal(atom[1].link, 'https://example.com/a2');
});

test('buildArticle with garbage <pubDate> yields pubDate === 0', () => {
  const source = SOURCES[0];
  const body =
    '<title>No date</title><link>https://example.com/x</link><pubDate>not-a-date</pubDate>';
  const article = buildArticle(body, source, itemOpts);
  assert.ok(article);
  assert.equal(article.pubDate, 0);
});

test('parseDate: null for empty/garbage, number for RFC-2822 and BST', () => {
  assert.equal(parseDate(''), null);
  assert.equal(parseDate('garbage'), null);

  const rfc = parseDate('Tue, 28 Jul 2026 18:11:00 GMT');
  assert.equal(typeof rfc, 'number');
  assert.ok(rfc > 0);

  // Raw BST suffix is rejected by Date.parse; parseDate's normalization makes it parse.
  assert.ok(Number.isNaN(Date.parse('Tue, 28 Jul 2026 18:11:00 BST')));
  const bst = parseDate('Tue, 28 Jul 2026 18:11:00 BST');
  assert.equal(typeof bst, 'number');
  assert.ok(bst > 0);
});

test('stableId is deterministic and source-aware', () => {
  const a = stableId('verge', 'https://example.com/1');
  const b = stableId('verge', 'https://example.com/1');
  const c = stableId('wired', 'https://example.com/1');
  assert.equal(a, b);
  assert.notEqual(a, c);
});

test('signRs256 round-trip verifies with the public key (no network)', async () => {
  const { privateKey, publicKey } = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) },
    true,
    ['sign', 'verify'],
  );

  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', privateKey));
  const base64 = btoa(String.fromCharCode(...pkcs8));
  const pem =
    '-----BEGIN PRIVATE KEY-----\n' +
    base64.match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';

  const input = 'header.payload';
  const signature = await signRs256(input, pem);

  // Decode base64url signature back to raw bytes for crypto.subtle.verify.
  const b64 = signature.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  const sigBytes = Uint8Array.from(atob(padded), c => c.charCodeAt(0));

  const verified = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    publicKey,
    sigBytes,
    new TextEncoder().encode(input),
  );
  assert.equal(verified, true);
});
