import { handleShare, handleCompanion } from './functions/_lib/pages.js';

const DYNAMIC = /^\/(join|c)\/([^/]+)\/?$/;

export default {
  async fetch(request, env) {
    const method = request.method;
    if (method === 'GET' || method === 'HEAD') {
      const match = DYNAMIC.exec(new URL(request.url).pathname);
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
