// SPDX-License-Identifier: MPL-2.0
import assert from 'node:assert/strict';
import { createCipheriv, createHash } from 'node:crypto';

const gibIndex = process.argv.indexOf('--gib');
const gib = gibIndex >= 0 ? Number(process.argv[gibIndex + 1]) : 1;
assert.ok(Number.isInteger(gib) && gib >= 1 && gib <= 5);

const chunkBytes = 1024 * 1024;
const totalBytes = gib * 1024 * 1024 * 1024;
const chunkCount = Math.ceil(totalBytes / chunkBytes);
const key = Buffer.alloc(32, 0x5a);
const epoch = Buffer.from('4c484154', 'hex');
const seenNonces = new Set();
const manifestHash = createHash('sha256');
let processed = 0;
let maxRss = process.memoryUsage().rss;

const started = process.hrtime.bigint();
for (let index = 0; index < chunkCount; index += 1) {
  const remaining = totalBytes - processed;
  const length = Math.min(chunkBytes, remaining);
  const plaintext = Buffer.alloc(length, index & 0xff);
  const nonce = Buffer.alloc(12);
  epoch.copy(nonce, 0);
  nonce.writeBigUInt64BE(BigInt(index), 4);
  const nonceHex = nonce.toString('hex');
  assert.ok(!seenNonces.has(nonceHex), 'nonce reuse');
  seenNonces.add(nonceHex);

  const aad = Buffer.from(JSON.stringify({ version: 1, attachment: 'synthetic', index, totalBytes }));
  const cipher = createCipheriv('aes-256-gcm', key, nonce, { authTagLength: 16 });
  cipher.setAAD(aad);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  assert.equal(ciphertext.length, length);
  manifestHash.update(nonce).update(tag).update(Buffer.from(String(length)));
  processed += length;
  maxRss = Math.max(maxRss, process.memoryUsage().rss);
}
const elapsedMs = Number(process.hrtime.bigint() - started) / 1e6;

assert.equal(processed, totalBytes);
assert.equal(seenNonces.size, chunkCount);
const result = {
  schema_version: 1,
  gib,
  total_bytes: totalBytes,
  chunk_bytes: chunkBytes,
  chunk_count: chunkCount,
  elapsed_ms: Math.round(elapsedMs),
  max_rss_mib: Math.round(maxRss / 1024 / 1024),
  manifest_sha256: manifestHash.digest('hex'),
  nonce_unique: true,
  completed: true,
};
assert.ok(result.max_rss_mib < 512, `RSS limit exceeded: ${result.max_rss_mib} MiB`);
console.log(JSON.stringify(result, null, 2));
