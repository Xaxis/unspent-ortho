// brotli -q Q -o OUT IN, for a box without the brotli binary (tools/export.sh
// falls back to this). Node is already needed for web.mjs and its zlib makes
// the same stream, so a fresh box exports without installing anything.
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { brotliCompressSync, constants } from 'node:zlib';

const args = process.argv.slice(2);
let quality = 11, out = null, input = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '-q') quality = parseInt(args[++i], 10);
  else if (args[i] === '-o') out = args[++i];
  else if (args[i] !== '-f') input = args[i];
}
if (!input || !out) {
  console.error('usage: node tools/web/brotli.mjs [-f] -q Q -o OUT IN');
  process.exit(2);
}
writeFileSync(out, brotliCompressSync(readFileSync(input), {
  params: { [constants.BROTLI_PARAM_QUALITY]: quality, [constants.BROTLI_PARAM_SIZE_HINT]: statSync(input).size },
}));
