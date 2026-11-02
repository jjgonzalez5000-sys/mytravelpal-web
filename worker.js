import { handleShare, handleCompanion } from './functions/_lib/pages.js';

const DYNAMIC = /^\/(join|c)\/([^/]+)\/?$/;

// Canonical site. The old brand hosts and the bare apex answer with a 301 to
// it, keeping the path and query.
export const CANONICAL_ORIGIN = 'https://www.optitrips.com';
const REDIRECT_HOSTS = new Set(['mytravelpal.io', 'www.mytravelpal.io', 'optitrips.com']);

// /.well-known/ is never redirected: Android verifies App Links by fetching
// assetlinks.json on each host and does not follow redirects (apps already
// installed check https://mytravelpal.io/.well-known/assetlinks.json), and
// security.txt must stay reachable on every host.
const WELL_KNOWN = /^\/\.well-known\//;

export function canonicalRedirect(url) {
  if (!REDIRECT_HOSTS.has(url.hostname.toLowerCase())) return null;
  if (WELL_KNOWN.test(url.pathname)) return null;
  return Response.redirect(CANONICAL_ORIGIN + url.pathname + url.search, 301);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const redirect = canonicalRedirect(url);
    if (redirect) return redirect;
    const method = request.method;
    if (method === 'GET' || method === 'HEAD') {
      const match = DYNAMIC.exec(url.pathname);
      if (match) {
        let id = match[2];
        try {
          id = decodeURIComponent(id);
        } catch {
          id = '';
        }
        return match[1] === 'join'
          ? handleShare({ request, env, slug: id })
          : handleCompanion({ request, env, code: id });
      }
    }
    return env.ASSETS.fetch(request);
  },
};
