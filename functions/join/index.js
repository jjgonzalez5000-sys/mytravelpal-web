import { handleLegacyJoin } from '../_lib/pages.js';

// /join?from=<name>:<lat>,<lon>&to=...&at=<ISO>: legacy stateless share links.
export const onRequestGet = ({ request }) => handleLegacyJoin({ request });

export const onRequestHead = onRequestGet;
