var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-G1euny/checked-fetch.js
var urls = /* @__PURE__ */ new Set();
function checkURL(request, init) {
  const url = request instanceof URL ? request : new URL(
    (typeof request === "string" ? new Request(request, init) : request).url
  );
  if (url.port && url.port !== "443" && url.protocol === "https:") {
    if (!urls.has(url.toString())) {
      urls.add(url.toString());
      console.warn(
        `WARNING: known issue with \`fetch()\` requests to custom HTTPS ports in published Workers:
 - ${url.toString()} - the custom port will be ignored when the Worker is published using the \`wrangler deploy\` command.
`
      );
    }
  }
}
__name(checkURL, "checkURL");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    const [request, init] = argArray;
    checkURL(request, init);
    return Reflect.apply(target, thisArg, argArray);
  }
});

// feed-worker.js
var RSS_SOURCES = [
  { id: "techcrunch", name: "TechCrunch", url: "https://techcrunch.com/feed/", category: "Tech", color: "#3B82F6", icon: "rocket_launch" },
  { id: "verge", name: "The Verge", url: "https://www.theverge.com/rss/index.xml", category: "Tech", color: "#3B82F6", icon: "devices" },
  { id: "wired", name: "Wired", url: "https://www.wired.com/feed/rss", category: "Tech", color: "#3B82F6", icon: "memory" },
  { id: "arstechnica", name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index", category: "Tech", color: "#3B82F6", icon: "computer" },
  { id: "engadget", name: "Engadget", url: "https://www.engadget.com/rss.xml", category: "Tech", color: "#3B82F6", icon: "devices_other" },
  { id: "bbc", name: "BBC World", url: "https://feeds.bbci.co.uk/news/rss.xml", category: "News", color: "#DC2626", icon: "public" },
  { id: "guardian", name: "The Guardian", url: "https://www.theguardian.com/world/rss", category: "News", color: "#DC2626", icon: "newspaper" },
  { id: "newscientist", name: "New Scientist", url: "https://www.newscientist.com/feed/home/", category: "Science", color: "#0891B2", icon: "biotech" },
  { id: "nasa", name: "NASA", url: "https://www.nasa.gov/rss/dyn/breaking_news.rss", category: "Science", color: "#0891B2", icon: "rocket" },
  { id: "skysports", name: "Sky Sports", url: "https://www.skysports.com/rss/12040", category: "Sports", color: "#059669", icon: "sports_soccer" },
  { id: "variety", name: "Variety", url: "https://variety.com/feed/", category: "Entertainment", color: "#7C3AED", icon: "theaters_rounded" },
  { id: "ign", name: "IGN", url: "https://feeds.ign.com/ign/games-all", category: "Gaming", color: "#8B5CF6", icon: "sports_esports" }
];
var CACHE_TTL = 15 * 60;
function cleanHtmlEntities(text) {
  if (!text) return "";
  text = text.replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)));
  text = text.replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
  const ents = { "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&apos;": "'", "&mdash;": "-", "&ndash;": "-", "&hellip;": "...", "&copy;": "(c)", "&reg;": "(R)", "&trade;": "(TM)", "&lsquo;": "'", "&rsquo;": "'", "&ldquo;": '"', "&rdquo;": '"', "&bull;": "-", "&middot;": "-", "&deg;": " deg " };
  for (const [e, c] of Object.entries(ents)) text = text.replace(new RegExp(e, "g"), c);
  return text;
}
__name(cleanHtmlEntities, "cleanHtmlEntities");
function stripHtmlTags(text) {
  if (!text) return "";
  text = cleanHtmlEntities(text);
  text = text.replace(/<[^>]*>/g, "");
  return cleanHtmlEntities(text).replace(/\s+/g, " ").trim();
}
__name(stripHtmlTags, "stripHtmlTags");
function cleanContent(text) {
  if (!text) return "";
  let c = stripHtmlTags(text);
  c = c.replace(/\[\+\]/g, "").replace(/\[more\]/gi, "").replace(/\[read more\]/gi, "").replace(/\s*\.\.\.\s*$/g, "");
  return c.replace(/\s{2,}/g, " ").trim();
}
__name(cleanContent, "cleanContent");
function extractArticleContent(html, articleUrl) {
  if (!html || typeof html !== "string") return null;
  let cleaned = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "");
  cleaned = cleaned.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "");
  cleaned = cleaned.replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, "");
  cleaned = cleaned.replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, "");
  cleaned = cleaned.replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, "");
  cleaned = cleaned.replace(/<header[^>]*>[\s\S]*?<\/header>/gi, "");
  cleaned = cleaned.replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, "");
  cleaned = cleaned.replace(/<aside[^>]*>[\s\S]*?<\/aside>/gi, "");
  let content = "";
  let source = "body";
  const articleMatch = cleaned.match(/<article[^>]*>([\s\S]*?)<\/article>/i);
  if (articleMatch && articleMatch[1] && articleMatch[1].length > 200) {
    content = articleMatch[1];
    source = "article";
  } else {
    const mainMatch = cleaned.match(/<main[^>]*>([\s\S]*?)<\/main>/i);
    if (mainMatch && mainMatch[1] && mainMatch[1].length > 200) {
      content = mainMatch[1];
      source = "main";
    } else {
      const contentPatterns = [
        /<(div|section)[^>]*class=["'][^"\']*\b(content|entry-content|post-content|article-content|main-content|story-content|body[_\-]?content)\b[^"\']*["'][^>]*>([\s\S]*?)<\/\1>/i,
        /<(div|section|article)[^>]*id=["'][^"\']*\b(content|entry|post|article|main|story)\b[^"\']*["'][^>]*>([\s\S]*?)<\/\1>/i,
        /<(div|section)[^>]*class=["'][^"\']*\b(post[_\-]?body|article[_\-]?body|entry[_\-]?body)\b[^"\']*["'][^>]*>([\s\S]*?)<\/\1>/i,
        /<(div)[^>]*itemprop=["']\s*articleBody\s*["'][^>]*>([\s\S]*?)<\/div>/i
      ];
      for (const pattern of contentPatterns) {
        const match = cleaned.match(pattern);
        if (match) {
          content = match[match.length - 1] || match[3];
          if (content && content.length > 200) {
            source = "content-selector";
            break;
          }
        }
      }
      if (!content) {
        const bodyMatch = cleaned.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
        content = bodyMatch ? bodyMatch[1] : cleaned;
      }
    }
  }
  content = content.replace(/<(nav|header|footer|aside|sidebar|menu|ad|advertisement|social|share|comment[s]?|discuss)[^>]*>[\s\S]*?<\/\1>/gi, "");
  content = content.replace(/<[^>]+class=["'][^"\']*\b(sidebar|widget|social|share|follow|subscribe|comment|ad|advert|banner|popup|modal|nav|menu)\b[^"\']*["'][^>]*>[\s\S]*?<\/[^>]+>/gi, "");
  content = stripHtmlTags(content);
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
    /\b(Cookie policy|Privacy policy|Terms of use)\b/gi
  ];
  for (const pattern of nonContentPatterns) {
    content = content.replace(pattern, "");
  }
  content = content.replace(/https?:\/\/[^\s]+/gi, " ");
  content = content.replace(/\s{2,}/g, " ").trim();
  if (content.length < 100) return null;
  return content;
}
__name(extractArticleContent, "extractArticleContent");
async function fetchFullContent(articleUrl) {
  if (!articleUrl || typeof articleUrl !== "string") return null;
  try {
    const response = await fetch(articleUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate, br",
        "DNT": "1",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1"
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
__name(fetchFullContent, "fetchFullContent");
async function handleFullContent(req) {
  const url = new URL(req.url);
  const articleUrl = url.searchParams.get("url");
  if (!articleUrl) {
    return new Response(JSON.stringify({
      error: "Missing required parameter: url",
      message: "Please provide a URL to extract content from"
    }), {
      status: 400,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
  let validatedUrl;
  try {
    validatedUrl = new URL(articleUrl);
    if (validatedUrl.protocol !== "http:" && validatedUrl.protocol !== "https:") {
      throw new Error("Invalid protocol");
    }
  } catch (e) {
    return new Response(JSON.stringify({
      error: "Invalid URL format",
      message: "The provided URL is not valid. Please provide a valid http or https URL."
    }), {
      status: 400,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
  const content = await fetchFullContent(articleUrl);
  if (content === null) {
    return new Response(JSON.stringify({
      error: "Failed to extract content",
      message: "Unable to fetch or extract content from the provided URL. The page may be unavailable or content extraction failed."
    }), {
      status: 502,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
  const wordCount = content.split(/\s+/).filter((word) => word.length > 0).length;
  const result = {
    url: articleUrl,
    content,
    wordCount,
    fetchedAt: (/* @__PURE__ */ new Date()).toISOString()
  };
  return new Response(JSON.stringify(result), {
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*"
    }
  });
}
__name(handleFullContent, "handleFullContent");
function getXmlText(xml, tag) {
  let m = xml.match(new RegExp("<" + tag + "[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></" + tag + ">", "i"));
  if (m) return m[1].trim();
  m = xml.match(new RegExp("<" + tag + "[^>]*>([\\s\\S]*?)</" + tag + ">", "i"));
  return m ? m[1].trim() : "";
}
__name(getXmlText, "getXmlText");
function parseRssXml(xmlText, source) {
  const articles = [];
  try {
    const items = xmlText.match(/<item[\s\S]*?<\/item>/gi) || [];
    for (let i = 0; i < Math.min(items.length, 20); i++) {
      const item = items[i];
      const title = cleanContent(getXmlText(item, "title"));
      const link = getXmlText(item, "link");
      if (!title || !link) continue;
      const desc = cleanContent(getXmlText(item, "description"));
      const full = cleanContent(getXmlText(item, "content:encoded")) || desc;
      let pub = (/* @__PURE__ */ new Date()).toISOString();
      try {
        const d = new Date(getXmlText(item, "pubDate"));
        if (!isNaN(d.getTime())) pub = d.toISOString();
      } catch (e) {
      }
      const auth = getXmlText(item, "author") || getXmlText(item, "dc:creator") || null;
      let img = null;
      let em = item.match(/<enclosure[^>]+url="([^"]+)"[^>]+type="image\/"[^>]*\/?>/i);
      if (!em) em = item.match(/<media:content[^>]+url="([^"]+)"[^>]*\/?>/i);
      if (em) img = em[1];
      articles.push({ id: hashCode(link), title, description: desc, fullContent: full, link, sourceId: source.id, sourceName: source.name, sourceCategory: source.category, sourceColor: source.color, sourceIcon: source.icon, pubDate: pub, author: auth || null, imageUrl: img });
    }
  } catch (e) {
    console.log("Parse error: " + e.message);
  }
  return articles;
}
__name(parseRssXml, "parseRssXml");
function hashCode(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h &= h;
  }
  return Math.abs(h);
}
__name(hashCode, "hashCode");
async function fetchSource(s) {
  try {
    const r = await fetch(s.url, { headers: { "User-Agent": "CuratedFeeds/1.0", "Accept": "application/rss+xml" } });
    if (!r.ok) throw new Error("HTTP " + r.status);
    return parseRssXml(await r.text(), s);
  } catch (e) {
    console.log("Error " + s.name + ": " + e.message);
    return [];
  }
}
__name(fetchSource, "fetchSource");
function parseIntOrDefault(value, defaultValue) {
  if (!value) return defaultValue;
  const parsed = parseInt(value, 10);
  return isNaN(parsed) ? defaultValue : parsed;
}
__name(parseIntOrDefault, "parseIntOrDefault");
function paginateItems(items, page, pageSize) {
  const start = (page - 1) * pageSize;
  const end = start + pageSize;
  const paginatedItems = items.slice(start, end);
  return {
    items: paginatedItems,
    total: items.length,
    page,
    pageSize,
    hasMore: end < items.length
  };
}
__name(paginateItems, "paginateItems");
function filterArticlesByCategory(articles, category) {
  if (!category || category.trim() === "") return articles;
  const cat = category.trim().toLowerCase();
  return articles.filter((a) => a.sourceCategory && a.sourceCategory.toLowerCase() === cat);
}
__name(filterArticlesByCategory, "filterArticlesByCategory");
function filterArticlesBySource(articles, sourceId) {
  if (!sourceId || sourceId.trim() === "") return articles;
  const sources = sourceId.split(",").map((s) => s.trim().toLowerCase());
  return articles.filter((a) => a.sourceId && sources.includes(a.sourceId.toLowerCase()));
}
__name(filterArticlesBySource, "filterArticlesBySource");
function filterArticlesBySearch(articles, query) {
  if (!query || query.trim() === "") return articles;
  const q = query.trim().toLowerCase();
  return articles.filter((a) => {
    const titleMatch = a.title && a.title.toLowerCase().includes(q);
    const descMatch = a.description && a.description.toLowerCase().includes(q);
    const sourceMatch = a.sourceName && a.sourceName.toLowerCase().includes(q);
    return titleMatch || descMatch || sourceMatch;
  });
}
__name(filterArticlesBySearch, "filterArticlesBySearch");
function filterArticlesByDateRange(articles, since, until) {
  let result = articles;
  if (since) {
    const sinceDate = new Date(since);
    if (!isNaN(sinceDate.getTime())) {
      result = result.filter((a) => new Date(a.pubDate) >= sinceDate);
    }
  }
  if (until) {
    const untilDate = new Date(until);
    if (!isNaN(untilDate.getTime())) {
      result = result.filter((a) => new Date(a.pubDate) <= untilDate);
    }
  }
  return result;
}
__name(filterArticlesByDateRange, "filterArticlesByDateRange");
function sortArticles(articles, sortBy) {
  const sorted = [...articles];
  switch (sortBy) {
    case "date_asc":
      sorted.sort((a, b) => new Date(a.pubDate) - new Date(b.pubDate));
      break;
    case "source":
      sorted.sort((a, b) => {
        const sourceCompare = (a.sourceName || "").localeCompare(b.sourceName || "");
        if (sourceCompare !== 0) return sourceCompare;
        return new Date(b.pubDate) - new Date(a.pubDate);
      });
      break;
    case "date_desc":
    default:
      sorted.sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate));
      break;
  }
  return sorted;
}
__name(sortArticles, "sortArticles");
async function handleSources() {
  const sources = RSS_SOURCES.map((s) => ({
    id: s.id,
    name: s.name,
    category: s.category,
    color: s.color,
    icon: s.icon,
    url: s.url
  }));
  return new Response(JSON.stringify({ sources }), {
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "public, max-age=3600"
    }
  });
}
__name(handleSources, "handleSources");
async function handleFetch(req) {
  const cache = caches.default;
  const url = new URL(req.url);
  const key = url.href;
  const page = parseIntOrDefault(url.searchParams.get("page"), 1);
  const pageSize = Math.min(parseIntOrDefault(url.searchParams.get("pageSize"), 50), 100);
  const category = url.searchParams.get("category");
  const source = url.searchParams.get("source");
  const q = url.searchParams.get("q");
  const since = url.searchParams.get("since");
  const until = url.searchParams.get("until");
  const sort = url.searchParams.get("sort");
  try {
    const c = await cache.match(key);
    if (c) return c;
  } catch (e) {
  }
  const res = await Promise.allSettled(RSS_SOURCES.map((s) => fetchSource(s)));
  let all = [];
  for (const x of res) if (x.status === "fulfilled") all.push(...x.value);
  all = filterArticlesByCategory(all, category);
  all = filterArticlesBySource(all, source);
  all = filterArticlesBySearch(all, q);
  all = filterArticlesByDateRange(all, since, until);
  all = sortArticles(all, sort);
  const paginated = paginateItems(all, page, pageSize);
  const resp = new Response(JSON.stringify(paginated), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*", "Cache-Control": "public, max-age=" + CACHE_TTL } });
  try {
    await cache.put(key, resp.clone());
  } catch (e) {
  }
  return resp;
}
__name(handleFetch, "handleFetch");
var feed_worker_default = {
  async fetch(req) {
    if (req.method === "OPTIONS") return new Response(null, { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, OPTIONS", "Access-Control-Allow-Headers": "Content-Type" } });
    const url = new URL(req.url);
    if (url.pathname === "/sources") return handleSources();
    if (url.pathname === "/health") return new Response(JSON.stringify({ status: "ok" }), { headers: { "Content-Type": "application/json" } });
    if (url.pathname === "/test") return new Response(JSON.stringify([{ id: "1", title: "Test", description: "Test", sourceId: "techcrunch", sourceName: "TechCrunch", pubDate: (/* @__PURE__ */ new Date()).toISOString() }]), { headers: { "Content-Type": "application/json" } });
    if (url.pathname === "/full-content") return handleFullContent(req);
    return req.method === "GET" ? handleFetch(req) : new Response("Method not allowed", { status: 405 });
  }
};

// C:/Users/rajat/AppData/Roaming/npm/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// C:/Users/rajat/AppData/Roaming/npm/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-G1euny/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = feed_worker_default;

// C:/Users/rajat/AppData/Roaming/npm/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-G1euny/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=feed-worker.js.map
