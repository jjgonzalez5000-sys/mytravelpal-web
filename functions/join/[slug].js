import { handleShare } from '../_lib/pages.js';

export const onRequestGet = ({ request, params, env }) =>
  handleShare({ request, env, slug: params.slug });

export const onRequestHead = onRequestGet;
