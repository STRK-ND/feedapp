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

/**
 * Extract article content from HTML
 * @param {string} html - Raw HTML content
 * @param {string} articleUrl - URL of the article (for reference)
 * @returns {string|null} - Extracted and cleaned content
 */
function extractArticleContent(html, articleUrl) {
  if (!html || typeof html !== 'string') return null;

  // Remove script and style elements
  let cleaned = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  cleaned = cleaned.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  cleaned = cleaned.replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, '');
  cleaned = cleaned.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '');
  cleaned = cleaned.replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, '');
  cleaned = cleaned.replace(/<header[^>]*>[\s\S]*?<\/header>/gi, '');
  cleaned = cleaned.replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '');
  cleaned = cleaned.replace(/<aside[^>]*>[\s\S]*?<\/aside>/gi, '');

  let content = '';
  let source = 'body';

  // Try to find content in semantic elements (article, main)
  const articleMatch = cleaned.match(/<article[^>]*>([\s\S]*?)<\/article>/i);
  if (articleMatch && articleMatch[1] && articleMatch[1].length > 200) {
    content = articleMatch[1];
    source = 'article';
  } else {
    const mainMatch = cleaned.match(/<main[^>]*>([\s\S]*?)<\/main>/i);
    if (mainMatch && mainMatch[1] && mainMatch[1].length > 200) {
      content = mainMatch[1];
      source = 'main';
    } else {
      // Try common content container class/id patterns
      const contentPatterns = [
        /<(div|section)[^>]*class=["'][^"\']*\b(content|entry-content|post-content|article-content|main-content|story-content|body[_\-]?content)\b[^"\']*["'][^>]*>([\s\S]*?)<\/\1>/i,
        /<(div|section|article)[^>]*id=["'][^"\']*\b(content|entry|post|article|main|story)\b[^"\']*["'][^>]*>([\s\S]*?)<\/\1>/i,
        /<(div|section)[^>]*class=["'][^"\']*\b(post[_\-]?body|article[_\-]?body|entry[_\-]?body)\b[^"\']*["'][^>]*>([\s\S]*?)<\/\1>/i,
        /<(div)[^>]*itemprop=["']\s*articleBody\s*["'][^>]*>([\s\S]*?)<\/div>/i
      ];
      for (const pattern of contentPatterns) {
        const match = cleaned.match(pattern);
        if (match) {
          // Get the last capturing group which contains the content
          content = match[match.length - 1] || match[3];
          if (content && content.length > 200) {
            source = 'content-selector';
            break;
          }
        }
      }
      // Fallback to body content
      if (!content) {
        const bodyMatch = cleaned.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
        content = bodyMatch ? bodyMatch[1] : cleaned;
      }
    }
  }

  // Remove unwanted elements that often contain non-content
  content = content.replace(/<(nav|header|footer|aside|sidebar|menu|ad|advertisement|social|share|comment[s]?|discuss)[^>]*>[\s\S]*?<\/\1>/gi, '');
  content = content.replace(/<[^>]+class=["'][^"\']*\b(sidebar|widget|social|share|follow|subscribe|comment|ad|advert|banner|popup|modal|nav|menu)\b[^"\']*["'][^>]*>[\s\S]*?<\/[^>]+>/gi, '');

  // Strip HTML tags and entities
  content = stripHtmlTags(content);

  // Remove common non-content patterns
  const nonContentPatterns = [
    /\b(Follow us|Follow me|Follow @[\w]+)\s+(on|at)\s+(Twitter|Facebook|Instagram|LinkedIn|X|Social Media)\b/gi,
    /\bSubscribe\s+(to|for)\s+(our|my|the)\s+(newsletter|updates|feed)\b/gi,
    /\b(Read more|Read the full article|Continue reading|Click here to read|Full story)\b/gi,
    /\b(Sign up|Sign-up|Sign up for|Register for)\s+(our|the|my)\s+(newsletter|updates|email)\b/gi,
    /\b(Share this|Share on|Share with|Tweet this)\b/gi,
    /\b(Like us on|Follow us on)\s+(Facebook|Twitter|Instagram)\b/gi,
    /\b(Related articles|Related stories|You may also like|More stories|Recommended for you)\b/gi,
    /\b(Advertisement|Sponsored content|Promoted)\b/gi,
    /\b(Previous|Next|Back to top|Home)\s*&raquo;?\b/gi,
    /\b(Copyright|All rights reserved)\b[\s\S]{0,200}/gi,
    /\b(Tags|Categories):\s*[\w\s,]+/gi,
    /\b(About the author|Written by|Byline)\b[\s\S]{0,300}/gi,
    /\^\s*Advertisement\s*\$/gi,
    /\b(Cookie policy|Privacy policy|Terms of use)\b/gi,
  ];

  for (const pattern of nonContentPatterns) {
    content = content.replace(pattern, '');
  }

  // Remove URLs (but keep them as reference)
  content = content.replace(/https?:\/\/[^\s]+/gi, ' ');

  // Clean up whitespace
  content = content.replace(/\s{2,}/g, ' ').trim();

  // Remove very short content (likely not the main article)
  if (content.length < 100) return null;

  return content;
}

/**
 * Fetch and extract full content from a URL
 * @param {string} articleUrl - URL to fetch
 * @returns {Promise<string|null>} - Extracted content or null on error
 */
async function fetchFullContent(articleUrl) {
  if (!articleUrl || typeof articleUrl !== 'string') return null;

  try {
    const response = await fetch(articleUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1'
      }
    });

    if (!response.ok) {
      console.log(`Error fetching ${articleUrl}: HTTP ${response.status}`);
      return null;
    }

    const html = await response.text();
    return extractArticleContent(html, articleUrl);
  } catch (e) {
    console.log(`Error fetching ${articleUrl}: ${e.message}`);
    return null;
  }
}

/**
 * Handle full-content endpoint request
 * @param {Request} req - Incoming request
 * @returns {Response} - JSON response with extracted content
 */
async function handleFullContent(req) {
  const url = new URL(req.url);
  const articleUrl = url.searchParams.get('url');

  // Validate URL parameter
  if (!articleUrl) {
    return new Response(JSON.stringify({
      error: 'Missing required parameter: url',
      message: 'Please provide a URL to extract content from'
    }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }

  // Validate URL format
  let validatedUrl;
  try {
    validatedUrl = new URL(articleUrl);
    // Only allow http and https protocols
    if (validatedUrl.protocol !== 'http:' && validatedUrl.protocol !== 'https:') {
      throw new Error('Invalid protocol');
    }
  } catch (e) {
    return new Response(JSON.stringify({
      error: 'Invalid URL format',
      message: 'The provided URL is not valid. Please provide a valid http or https URL.'
    }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }

  // Fetch and extract content
  const content = await fetchFullContent(articleUrl);

  if (content === null) {
    return new Response(JSON.stringify({
      error: 'Failed to extract content',
      message: 'Unable to fetch or extract content from the provided URL. The page may be unavailable or content extraction failed.'
    }), {
      status: 502,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }

  // Calculate word count
  const wordCount = content.split(/\s+/).filter(word => word.length > 0).length;

  const result = {
    url: articleUrl,
    content: content,
    wordCount: wordCount,
    fetchedAt: new Date().toISOString()
  };

  return new Response(JSON.stringify(result), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
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

function parseIntOrDefault(value, defaultValue) {
  if (!value) return defaultValue;
  const parsed = parseInt(value, 10);
  return isNaN(parsed) ? defaultValue : parsed;
}

function paginateItems(items, page, pageSize) {
  const start = (page - 1) * pageSize;
  const end = start + pageSize;
  const paginatedItems = items.slice(start, end);
  return {
    items: paginatedItems,
    total: items.length,
    page: page,
    pageSize: pageSize,
    hasMore: end < items.length
  };
}

function filterArticlesByCategory(articles, category) {
  if (!category || category.trim() === '') return articles;
  const cat = category.trim().toLowerCase();
  return articles.filter(a => a.sourceCategory && a.sourceCategory.toLowerCase() === cat);
}

function filterArticlesBySource(articles, sourceId) {
  if (!sourceId || sourceId.trim() === '') return articles;
  const sources = sourceId.split(',').map(s => s.trim().toLowerCase());
  return articles.filter(a => a.sourceId && sources.includes(a.sourceId.toLowerCase()));
}

function filterArticlesBySearch(articles, query) {
  if (!query || query.trim() === '') return articles;
  const q = query.trim().toLowerCase();
  return articles.filter(a => {
    const titleMatch = a.title && a.title.toLowerCase().includes(q);
    const descMatch = a.description && a.description.toLowerCase().includes(q);
    const sourceMatch = a.sourceName && a.sourceName.toLowerCase().includes(q);
    return titleMatch || descMatch || sourceMatch;
  });
}

function filterArticlesByDateRange(articles, since, until) {
  let result = articles;
  if (since) {
    const sinceDate = new Date(since);
    if (!isNaN(sinceDate.getTime())) {
      result = result.filter(a => new Date(a.pubDate) >= sinceDate);
    }
  }
  if (until) {
    const untilDate = new Date(until);
    if (!isNaN(untilDate.getTime())) {
      result = result.filter(a => new Date(a.pubDate) <= untilDate);
    }
  }
  return result;
}

function sortArticles(articles, sortBy) {
  const sorted = [...articles];
  switch (sortBy) {
    case 'date_asc':
      sorted.sort((a, b) => new Date(a.pubDate) - new Date(b.pubDate));
      break;
    case 'source':
      sorted.sort((a, b) => {
        const sourceCompare = (a.sourceName || '').localeCompare(b.sourceName || '');
        if (sourceCompare !== 0) return sourceCompare;
        return new Date(b.pubDate) - new Date(a.pubDate);
      });
      break;
    case 'date_desc':
    default:
      sorted.sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate));
      break;
  }
  return sorted;
}

async function handleSources() {
  const sources = RSS_SOURCES.map(s => ({
    id: s.id,
    name: s.name,
    category: s.category,
    color: s.color,
    icon: s.icon,
    url: s.url
  }));

  return new Response(JSON.stringify({ sources }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=3600'
    }
  });
}

async function handleFetch(req) {
  const cache = caches.default;
  const url = new URL(req.url);
  const key = url.href;

  const page = parseIntOrDefault(url.searchParams.get('page'), 1);
  const pageSize = Math.min(parseIntOrDefault(url.searchParams.get('pageSize'), 50), 100);

  // Parse new filter and sort parameters
  const category = url.searchParams.get('category');
  const source = url.searchParams.get('source');
  const q = url.searchParams.get('q');
  const since = url.searchParams.get('since');
  const until = url.searchParams.get('until');
  const sort = url.searchParams.get('sort');

  try { const c = await cache.match(key); if (c) return c; } catch(e) {}
  const res = await Promise.allSettled(RSS_SOURCES.map(s => fetchSource(s)));
  let all = [];
  for (const x of res) if (x.status === 'fulfilled') all.push(...x.value);

  // Apply filters (before sorting and pagination)
  all = filterArticlesByCategory(all, category);
  all = filterArticlesBySource(all, source);
  all = filterArticlesBySearch(all, q);
  all = filterArticlesByDateRange(all, since, until);

  // Apply sorting (before pagination)
  all = sortArticles(all, sort);

  const paginated = paginateItems(all, page, pageSize);

  const resp = new Response(JSON.stringify(paginated), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Cache-Control': 'public, max-age=' + CACHE_TTL } });
  try { await cache.put(key, resp.clone()); } catch(e) {}
  return resp;
}

export default {
  async fetch(req) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' } });
    const url = new URL(req.url);
    if (url.pathname === '/sources') return handleSources();
    if (url.pathname === '/health') return new Response(JSON.stringify({ status: 'ok' }), { headers: { 'Content-Type': 'application/json' } });
    if (url.pathname === '/test') return new Response(JSON.stringify([{ id: '1', title: 'Test', description: 'Test', sourceId: 'techcrunch', sourceName: 'TechCrunch', pubDate: new Date().toISOString() }]), { headers: { 'Content-Type': 'application/json' } });
    if (url.pathname === '/full-content') return handleFullContent(req);
    return req.method === 'GET' ? handleFetch(req) : new Response('Method not allowed', { status: 405 });
  },
};
