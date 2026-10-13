import { handleCompanion } from '../_lib/pages.js';

export const onRequestGet = ({ request, params, env }) =>
  handleCompanion({ request, env, code: params.code });

export const onRequestHead = onRequestGet;
