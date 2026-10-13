const SITE = 'https://www.mytravelpal.io';
const DEFAULT_API_BASE = 'https://mytravelpal-api.fly.dev';
const PACKAGE_ID = 'com.mytravelpal.travel';
const OG_IMAGE = `${SITE}/img/og-default.png`;
const API_TIMEOUT_MS = 3000;
const CACHE_FOUND = 'public, max-age=300';
const CACHE_NOT_FOUND = 'public, max-age=60';
const CACHE_FALLBACK = 'no-store';

const CODE_RE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/;

const STRINGS = {
  en: {
    locale: 'en_GB',
    brand: 'MyTravelPal',
    openApp: 'Open in the app',
    getApp: 'Get the app',
    shareTitle: (o, d) => `${o} to ${d} - road trip plan`,
    shareHeading: (o, d) => `${o} to ${d}`,
    shareDesc: (o, d, km, days) => `${km === null ? '' : `${km} km, `}${days} ${days === 1 ? 'day' : 'days'}: a road trip${o && d ? ` from ${o} to ${d}` : ''} planned with MyTravelPal.`,
    shareTitleGeneric: 'Road trip plan',
    countries: 'Countries',
    distance: 'Distance',
    duration: 'Duration',
    daysUnit: (n) => (n === 1 ? 'day' : 'days'),
    savedFuel: 'Fuel saved',
    savedTolls: 'Tolls saved',
    sharedAt: 'Shared on',
    hint: 'Open the link in the app to see the full plan: stops, tolls, hotels and weather along the route.',
    companionTitle: 'Group trip - MyTravelPal Companion',
    companionHeading: 'Join the group trip',
    companionDesc: 'Follow your group on the road with MyTravelPal Companion.',
    companionActive: 'The group is on the road.',
    companionInactive: 'This group trip is not active right now. It may not have started yet or it has already ended.',
    destination: 'Destination',
    eta: 'Estimated arrival in',
    notFoundTitle: 'Link not found - MyTravelPal',
    notFoundHeading: 'This link is not available',
    notFoundBody: 'It may have expired or been mistyped.',
    fallbackTitle: 'MyTravelPal',
    fallbackHeading: 'Open this link in MyTravelPal',
    fallbackBody: 'We could not load the preview right now. If you have the app, it will open the content; otherwise get it below.',
    eurSuffix: ' EUR',
  },
  es: {
    locale: 'es_ES',
    brand: 'MyTravelPal',
    openApp: 'Abrir en la app',
    getApp: 'Conseguir la app',
    shareTitle: (o, d) => `${o} a ${d} - plan de road trip`,
    shareHeading: (o, d) => `${o} a ${d}`,
    shareDesc: (o, d, km, days) => `${km === null ? '' : `${km} km, `}${days} ${days === 1 ? 'día' : 'días'}: un road trip${o && d ? ` de ${o} a ${d}` : ''} planificado con MyTravelPal.`,
    shareTitleGeneric: 'Plan de road trip',
    countries: 'Países',
    distance: 'Distancia',
    duration: 'Duración',
    daysUnit: (n) => (n === 1 ? 'día' : 'días'),
    savedFuel: 'Combustible ahorrado',
    savedTolls: 'Peajes ahorrados',
    sharedAt: 'Compartido el',
    hint: 'Abre el enlace en la app para ver el plan completo: paradas, peajes, hoteles y tiempo a lo largo de la ruta.',
    companionTitle: 'Viaje en grupo - MyTravelPal Companion',
    companionHeading: 'Únete al viaje en grupo',
    companionDesc: 'Sigue a tu grupo en carretera con MyTravelPal Companion.',
    companionActive: 'El grupo está en carretera.',
    companionInactive: 'Este viaje en grupo no está activo ahora mismo. Puede que aún no haya empezado o que ya haya terminado.',
    destination: 'Destino',
    eta: 'Llegada estimada en',
    notFoundTitle: 'Enlace no encontrado - MyTravelPal',
    notFoundHeading: 'Este enlace no está disponible',
    notFoundBody: 'Puede que haya caducado o que esté mal escrito.',
    fallbackTitle: 'MyTravelPal',
    fallbackHeading: 'Abre este enlace en MyTravelPal',
    fallbackBody: 'Ahora mismo no podemos cargar la vista previa. Si tienes la app, abrirá el contenido; si no, consíguela abajo.',
    eurSuffix: ' EUR',
  },
};

export function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function validateSlug(raw) {
  if (typeof raw !== 'string') return null;
  const slug = raw.toUpperCase();
  return CODE_RE.test(slug) ? slug : null;
}

export function validateCode(raw) {
  if (typeof raw !== 'string') return null;
  const code = raw.toUpperCase();
  return CODE_RE.test(code) ? code : null;
}

export function pickLang(acceptLanguage, override) {
  if (override === 'es' || override === 'en') return override;
  if (typeof acceptLanguage !== 'string') return 'en';
  let best = 'en';
  let bestQ = -1;
  for (const part of acceptLanguage.split(',')) {
    const [tagRaw, ...params] = part.trim().split(';');
    const primary = tagRaw.trim().toLowerCase().split('-')[0];
    if (primary !== 'es' && primary !== 'en') continue;
    let q = 1;
    for (const p of params) {
      const m = /^\s*q\s*=\s*([0-9.]+)\s*$/i.exec(p);
      if (m) q = Number.parseFloat(m[1]);
    }
    if (!Number.isFinite(q) || q <= 0) continue;
    if (q > bestQ) {
      best = primary;
      bestQ = q;
    }
  }
  return best;
}

function cleanText(value, max) {
  if (typeof value !== 'string') return null;
  const text = value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!text) return null;
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function cleanNumber(value, { min, max }) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  if (value < min || value > max) return null;
  return value;
}

export function normalizeShare(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const absent = (v) => v === null || v === undefined;
  if (!absent(raw.origin_city) && typeof raw.origin_city !== 'string') return null;
  if (!absent(raw.destination_city) && typeof raw.destination_city !== 'string') return null;
  const km = absent(raw.km) ? null : cleanNumber(raw.km, { min: 0, max: 100000 });
  if (!absent(raw.km) && km === null) return null;
  const days = cleanNumber(raw.days, { min: 0, max: 365 });
  if (days === null) return null;
  let origin = cleanText(raw.origin_city, 80);
  let destination = cleanText(raw.destination_city, 80);
  if (!origin || !destination) {
    origin = null;
    destination = null;
  }
  const countries = Array.isArray(raw.countries)
    ? raw.countries.filter((c) => typeof c === 'string' && /^[A-Z]{2}$/.test(c)).slice(0, 12)
    : [];
  const created = typeof raw.created_at === 'string' ? Date.parse(raw.created_at) : NaN;
  return {
    origin_city: origin,
    destination_city: destination,
    km: km === null ? null : Math.round(km),
    days: Math.max(1, Math.round(days)),
    countries,
    saved_fuel_eur: cleanNumber(raw.saved_fuel_eur, { min: 0.005, max: 100000 }),
    saved_tolls_eur: cleanNumber(raw.saved_tolls_eur, { min: 0.005, max: 100000 }),
    created_date: Number.isNaN(created) ? null : new Date(created).toISOString().slice(0, 10),
  };
}

export function normalizeCompanion(raw) {
  if (!raw || typeof raw !== 'object' || typeof raw.active !== 'boolean') return null;
  const eta = cleanNumber(raw.eta_minutes, { min: 0, max: 10080 });
  return {
    active: raw.active,
    destination_city: cleanText(raw.destination_city, 80),
    eta_minutes: eta === null ? null : Math.round(eta),
  };
}

function formatInt(n, lang) {
  const sep = lang === 'es' ? '.' : ',';
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, sep);
}

function formatEur(n, lang) {
  const text = n >= 100 ? formatInt(n, lang) : n.toFixed(2).replace('.', lang === 'es' ? ',' : '.');
  return `${text}${STRINGS[lang].eurSuffix}`;
}

function formatDuration(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} min`;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

export function appLinks(path) {
  const clean = path.replace(/^\//, '');
  const https = `${SITE}/${clean}`;
  const fallback = encodeURIComponent(`${SITE}/get`);
  const intent = `intent://www.mytravelpal.io/${clean}#Intent;scheme=https;package=${PACKAGE_ID};S.browser_fallback_url=${fallback};end`;
  return { https, intent };
}

function layout({ lang, title, description, canonical, openUrl, body, ogTitle }) {
  const t = STRINGS[lang];
  const e = escapeHtml;
  const meta = [
    `<meta charset="UTF-8">`,
    `<meta name="viewport" content="width=device-width, initial-scale=1.0">`,
    `<title>${e(title)}</title>`,
    `<meta name="description" content="${e(description)}">`,
    `<meta name="robots" content="noindex,nofollow">`,
    `<meta name="theme-color" content="#F44F72">`,
    `<meta property="og:site_name" content="${e(t.brand)}">`,
    `<meta property="og:type" content="website">`,
    `<meta property="og:locale" content="${e(t.locale)}">`,
    `<meta property="og:title" content="${e(ogTitle || title)}">`,
    `<meta property="og:description" content="${e(description)}">`,
    `<meta property="og:image" content="${OG_IMAGE}">`,
    `<meta property="og:image:width" content="1200">`,
    `<meta property="og:image:height" content="630">`,
    `<meta name="twitter:card" content="summary_large_image">`,
    `<meta name="twitter:title" content="${e(ogTitle || title)}">`,
    `<meta name="twitter:description" content="${e(description)}">`,
    `<meta name="twitter:image" content="${OG_IMAGE}">`,
  ];
  if (canonical) {
    meta.push(`<link rel="canonical" href="${e(canonical)}">`);
    meta.push(`<meta property="og:url" content="${e(canonical)}">`);
  }
  meta.push(`<link rel="icon" href="/favicon.svg">`, `<link rel="stylesheet" href="/style.css">`);
  const ctas = [];
  if (openUrl) ctas.push(`<a class="cta primary" href="${e(openUrl)}">${e(t.openApp)}</a>`);
  ctas.push(`<a class="cta ghost" href="/get">${e(t.getApp)}</a>`);
  return [
    `<!DOCTYPE html>`,
    `<html lang="${lang}">`,
    `<head>`,
    ...meta,
    `</head>`,
    `<body>`,
    `<header><nav class="container"><a class="brand" href="/">${e(t.brand)}</a></nav></header>`,
    `<main class="page"><div class="container">`,
    body,
    `<div class="ctas">${ctas.join('')}</div>`,
    `</div></main>`,
    `</body>`,
    `</html>`,
    ``,
  ].join('\n');
}

export function renderSharePage(data, lang, slug) {
  const t = STRINGS[lang];
  const e = escapeHtml;
  const { https, intent } = appLinks(`join/${slug}`);
  const rows = [];
  if (data.km !== null) rows.push([t.distance, `${formatInt(data.km, lang)} km`]);
  rows.push([t.duration, `${data.days} ${t.daysUnit(data.days)}`]);
  if (data.countries.length) rows.push([t.countries, data.countries.join(', ')]);
  if (data.saved_fuel_eur !== null) rows.push([t.savedFuel, formatEur(data.saved_fuel_eur, lang)]);
  if (data.saved_tolls_eur !== null) rows.push([t.savedTolls, formatEur(data.saved_tolls_eur, lang)]);
  if (data.created_date) rows.push([t.sharedAt, data.created_date]);
  const list = rows.map(([k, v]) => `<li><strong>${e(k)}:</strong> ${e(v)}</li>`).join('\n');
  const hasRoute = data.origin_city !== null && data.destination_city !== null;
  const shareTitle = hasRoute ? t.shareTitle(data.origin_city, data.destination_city) : t.shareTitleGeneric;
  const heading = hasRoute ? t.shareHeading(data.origin_city, data.destination_city) : t.shareTitleGeneric;
  const body = [
    `<h1>${e(heading)}</h1>`,
    `<ul>`,
    list,
    `</ul>`,
    `<p>${e(t.hint)}</p>`,
  ].join('\n');
  return layout({
    lang,
    title: `${shareTitle} | ${t.brand}`,
    ogTitle: shareTitle,
    description: t.shareDesc(data.origin_city, data.destination_city, data.km === null ? null : formatInt(data.km, lang), data.days),
    canonical: https,
    openUrl: intent,
    body,
  });
}

export function renderCompanionPage(data, lang, code) {
  const t = STRINGS[lang];
  const e = escapeHtml;
  const { intent } = appLinks(`c/${code}`);
  const parts = [`<h1>${e(t.companionHeading)}</h1>`];
  if (data.active) {
    parts.push(`<p>${e(t.companionActive)}</p>`, `<ul>`);
    if (data.destination_city) parts.push(`<li><strong>${e(t.destination)}:</strong> ${e(data.destination_city)}</li>`);
    if (data.eta_minutes !== null) parts.push(`<li><strong>${e(t.eta)}:</strong> ${e(formatDuration(data.eta_minutes))}</li>`);
    parts.push(`</ul>`);
  } else {
    parts.push(`<p>${e(t.companionInactive)}</p>`);
  }
  return layout({
    lang,
    title: t.companionTitle,
    description: t.companionDesc,
    canonical: `${SITE}/c/${code}`,
    openUrl: data.active ? intent : null,
    body: parts.join('\n'),
  });
}

export function renderNotFoundPage(lang) {
  const t = STRINGS[lang];
  const e = escapeHtml;
  return layout({
    lang,
    title: t.notFoundTitle,
    description: t.notFoundBody,
    canonical: null,
    openUrl: null,
    body: `<h1>${e(t.notFoundHeading)}</h1>\n<p>${e(t.notFoundBody)}</p>`,
  });
}

export function renderFallbackPage(lang, path) {
  const t = STRINGS[lang];
  const e = escapeHtml;
  return layout({
    lang,
    title: t.fallbackTitle,
    description: t.fallbackBody,
    canonical: null,
    openUrl: appLinks(path).intent,
    body: `<h1>${e(t.fallbackHeading)}</h1>\n<p>${e(t.fallbackBody)}</p>`,
  });
}

export function resolveApiBase(env) {
  const raw = env && typeof env.API_BASE === 'string' ? env.API_BASE.trim() : '';
  if (!raw) return DEFAULT_API_BASE;
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return DEFAULT_API_BASE;
    return `${url.origin}${url.pathname.replace(/\/+$/, '')}`;
  } catch {
    return DEFAULT_API_BASE;
  }
}

export function proxyHeaders(request, env) {
  const secret = env && typeof env.WEB_PROXY_SECRET === 'string' ? env.WEB_PROXY_SECRET.trim() : '';
  const ip = request && request.headers ? request.headers.get('CF-Connecting-IP') : null;
  if (!secret || !ip) return {};
  return { 'X-Web-Proxy-Secret': secret, 'X-Web-Client-IP': ip.trim() };
}

export async function fetchPublic(url, fetchImpl, timeoutMs = API_TIMEOUT_MS, extraHeaders = {}) {
  const controller = new AbortController();
  let timer;
  const timeout = new Promise((resolve) => {
    timer = setTimeout(() => {
      controller.abort();
      resolve({ kind: 'error' });
    }, timeoutMs);
  });
  const request = (async () => {
    try {
      const res = await fetchImpl(url, {
        method: 'GET',
        headers: { Accept: 'application/json', ...extraHeaders },
        signal: controller.signal,
      });
      if (res.status === 404 || res.status === 410) return { kind: 'not_found' };
      if (!res.ok) return { kind: 'error' };
      return { kind: 'ok', json: await res.json() };
    } catch {
      return { kind: 'error' };
    }
  })();
  try {
    return await Promise.race([request, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

function htmlResponse(html, status, cacheControl) {
  return new Response(html, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': cacheControl,
      'X-Robots-Tag': 'noindex, nofollow',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      Vary: 'Accept-Language',
      'Content-Security-Policy':
        "default-src 'none'; style-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    },
  });
}

function requestLang(request) {
  let override = null;
  try {
    override = new URL(request.url).searchParams.get('lang');
  } catch {
    override = null;
  }
  return pickLang(request.headers.get('Accept-Language'), override);
}

async function handle({ request, env, fetchImpl, id, kind }) {
  const lang = requestLang(request);
  const impl = fetchImpl || fetch;
  const validated = kind === 'share' ? validateSlug(id) : validateCode(id);
  if (!validated) return htmlResponse(renderNotFoundPage(lang), 404, CACHE_NOT_FOUND);
  const apiPath = kind === 'share' ? `/v1/public/share/${validated}` : `/v1/public/companion/${validated}`;
  const pagePath = kind === 'share' ? `join/${validated}` : `c/${validated}`;
  const result = await fetchPublic(`${resolveApiBase(env)}${apiPath}`, impl, API_TIMEOUT_MS, proxyHeaders(request, env));
  if (result.kind === 'not_found') return htmlResponse(renderNotFoundPage(lang), 404, CACHE_NOT_FOUND);
  if (result.kind === 'ok') {
    if (kind === 'share') {
      const data = normalizeShare(result.json);
      if (data) return htmlResponse(renderSharePage(data, lang, validated), 200, CACHE_FOUND);
    } else {
      const data = normalizeCompanion(result.json);
      if (data) return htmlResponse(renderCompanionPage(data, lang, validated), 200, CACHE_FOUND);
    }
  }
  return htmlResponse(renderFallbackPage(lang, pagePath), 200, CACHE_FALLBACK);
}

export function handleShare(args) {
  return handle({ ...args, id: args.slug, kind: 'share' });
}

export function handleCompanion(args) {
  return handle({ ...args, id: args.code, kind: 'companion' });
}

export const constants = {
  SITE,
  DEFAULT_API_BASE,
  PACKAGE_ID,
  OG_IMAGE,
  API_TIMEOUT_MS,
  CACHE_FOUND,
  CACHE_NOT_FOUND,
  CACHE_FALLBACK,
};
