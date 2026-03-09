/**
 * Cloudflare Worker - RSS Feed Processor
 */

const RSS_SOURCES = [
 { id: 'techcrunch', name: 'TechCrunch', url: 'https://techcrunch.com/feed/', category: 'Tech', color: '#3B82F6', icon: 'rocket_launch' },
 { id: 'verge', name: 'The Verge', url: 'https://www.theverge.com/rss/index.xml', category: 'Tech', color: '#3B82F6', icon: 'devices' },
 { id: 'wired', name: 'Wired', url: 'https://www.wired.com/feed/rss', category: 'Tech', color: '#3B82F6', icon: 'memory' },
 { id: 'arstechnica', name: 'Ars Technica', url: 'https://feeds.arstechnica.com/arstechnica/index', category: 'Tech', color: '#3B82F6', icon: 'computer' },
 { id: 'engadget', name: 'Engadget', url: 'https://www.engadget.com/rss.xml', category: 'Tech', color: '#3B82F6', icon: 'devices_other' },
 { id: 'bbc', name: 'BBC World', url: 'https://feeds.bbci.co.uk/news/rss.xml', category: 'News', color: '#DC2626', icon: 'public' },
 { id: 'guardian', name: 'The Guardian', url: 'https://www.theguardian.com/world/rss', category: 'News', color: '#DC2626', icon: 'newspaper' },
 { id: 'newscientist', name: 'New Scientist', url: 'https://www.newscientist.com/feed/home/', category: 'Science', color: '#0891B2', icon: 'biotech' },
 { id: 'nasa', name: 'NASA', url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss', category: 'Science', color: '#0891B2', icon: 'rocket' },
 { id: 'skysports', name: 'Sky Sports', url: 'https://www.skysports.com/rss/12040', category: 'Sports', color: '#059669', icon: 'sports_soccer' },
 { id: 'variety', name: 'Variety', url: 'https://variety.com/feed/', category: 'Entertainment', color: '#7C3AED', icon: 'theaters_rounded' },
 { id: 'ign', name: 'IGN', url: 'https://feeds.ign.com/ign/games-all', category: 'Gaming', color: '#8B5CF6', icon: 'sports_esports' },
];

const CACHE_TTL = 15 * 60;

function cleanHtmlEntities(text) {
  if (!text) return '';
  text = text.replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)));
  text = text.replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
  const ents = { '&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'", '&mdash;': '-', '&ndash;': '-', '&hellip;': '...', '&copy;': '(c)', '&reg;': '(R)', '&trade;': '(TM)', '&lsquo;': "'", '&rsquo;': "'", '&ldquo;': '"', '&rdquo;': '"', '&bull;': '-', '&middot;': '-', '&deg;': ' deg ' };
  for (const [e, c] of Object.entries(ents)) text = text.replace(new RegExp(e, 'g'), c);
  return text;
}

function stripHtmlTags(text) {
  if (!text) return '';
  text = cleanHtmlEntities(text);
  text = text.replace(/<[^>]*>/g, '');
  return cleanHtmlEntities(text).replace(/\s+/g, ' ').trim();
}

function cleanContent(text) {
  if (!text) return '';
  let c = stripHtmlTags(text);
  c = c.replace(/\[\+\]/g, '').replace(/\[more\]/gi, '').replace(/\[read more\]/gi, '').replace(/\s*\.\.\.\s*$/g, '');
  return c.replace(/\s{2,}/g, ' ').trim();
}

function getXmlText(xml, tag) {
  let m = xml.match(new RegExp('<' + tag + '[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></' + tag + '>', 'i'));
  if (m) return m[1].trim();
  m = xml.match(new RegExp('<' + tag + '[^>]*>([\\s\\S]*?)</' + tag + '>', 'i'));
  return m ? m[1].trim() : '';
}

function parseRssXml(xmlText, source) {
  const articles = [];
  try {
    const items = xmlText.match(/<item[\s\S]*?<\/item>/gi) || [];
    for (let i = 0; i < Math.min(items.length, 20); i++) {
      const item = items[i];
      const title = cleanContent(getXmlText(item, 'title'));
      const link = getXmlText(item, 'link');
      if (!title || !link) continue;
      const desc = cleanContent(getXmlText(item, 'description'));
      const full = cleanContent(getXmlText(item, 'content:encoded')) || desc;
      let pub = new Date().toISOString();
      try { const d = new Date(getXmlText(item, 'pubDate')); if (!isNaN(d.getTime())) pub = d.toISOString(); } catch(e) {}
      const auth = getXmlText(item, 'author') || getXmlText(item, 'dc:creator') || null;
      let img = null;
      let em = item.match(/<enclosure[^>]+url="([^"]+)"[^>]+type="image\/"[^>]*\/?>/i);
      if (!em) em = item.match(/<media:content[^>]+url="([^"]+)"[^>]*\/?>/i);
      if (em) img = em[1];
      articles.push({ id: hashCode(link), title, description: desc, fullContent: full, link, sourceId: source.id, sourceName: source.name, sourceCategory: source.category, sourceColor: source.color, sourceIcon: source.icon, pubDate: pub, author: auth || null, imageUrl: img });
    }
  } catch(e) { console.log('Parse error: ' + e.message); }
  return articles;
}

function hashCode(s) { let h = 0; for (let i = 0; i < s.length; i++) { h = ((h << 5) - h) + s.charCodeAt(i); h &= h; } return Math.abs(h); }

async function fetchSource(s) {
  try {
    const r = await fetch(s.url, { headers: { 'User-Agent': 'CuratedFeeds/1.0', 'Accept': 'application/rss+xml' } });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return parseRssXml(await r.text(), s);
  } catch(e) { console.log('Error ' + s.name + ': ' + e.message); return []; }
}

async function handleFetch(req) {
  const cache = caches.default;
  const key = new URL(req.url).href;
  try { const c = await cache.match(key); if (c) return c; } catch(e) {}
  const res = await Promise.allSettled(RSS_SOURCES.map(s => fetchSource(s)));
  const all = [];
  for (const x of res) if (x.status === 'fulfilled') all.push(...x.value);
  all.sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate));
  const resp = new Response(JSON.stringify(all), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Cache-Control': 'public, max-age=' + CACHE_TTL } });
  try { await cache.put(key, resp.clone()); } catch(e) {}
  return resp;
}

export default {
  async fetch(req) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' } });
    if (req.url.includes('/health')) return new Response(JSON.stringify({ status: 'ok' }), { headers: { 'Content-Type': 'application/json' } });
    if (req.url.includes('/test')) return new Response(JSON.stringify([{ id: '1', title: 'Test', description: 'Test', sourceId: 'techcrunch', sourceName: 'TechCrunch', pubDate: new Date().toISOString() }]), { headers: { 'Content-Type': 'application/json' } });
    return req.method === 'GET' ? handleFetch(req) : new Response('Method not allowed', { status: 405 });
  },
};