// SPDX-License-Identifier: MPL-2.0
import assert from 'node:assert/strict';
import { createCipheriv, createDecipheriv, createHash } from 'node:crypto';

const MAGIC = Buffer.from('LOCALH1\n', 'ascii');
const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_CHUNKS = 100000;
const MAX_PLAINTEXT_CHUNK_BYTES = 8 * 1024 * 1024;
const ENVELOPE_BYTES = 12 + 16;
const KEY = Buffer.alloc(32, 0x31); // Synthetic vector key only.
const TOP_LEVEL_FIELDS = ['algorithm', 'chunk_count', 'chunks', 'format_version', 'plaintext_sha256'];
const CHUNK_FIELDS = ['ciphertext_size', 'id', 'plaintext_size'];

const u32 = value => {
  assert.ok(Number.isSafeInteger(value) && value >= 0 && value <= 0xffffffff);
  const output = Buffer.alloc(4);
  output.writeUInt32BE(value);
  return output;
};

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function canonicalManifest(value) {
  return Buffer.from(stableJson(value), 'utf8');
}

function exactFields(value, fields) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    && JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...fields].sort());
}

function chunkId(index) {
  return `chunk-${index.toString().padStart(8, '0')}`;
}

function aad(id, index, count, plaintextSize) {
  return Buffer.from(`localhold-backup-v1:${id}:${index}:${count}:${plaintextSize}`, 'utf8');
}

export function encodeLocalhold(chunks) {
  assert.ok(Array.isArray(chunks) && chunks.length <= MAX_CHUNKS);
  for (const chunk of chunks) {
    assert.ok(Buffer.isBuffer(chunk) && chunk.length <= MAX_PLAINTEXT_CHUNK_BYTES);
  }
  const metadata = chunks.map((plaintext, index) => ({
    ciphertext_size: plaintext.length + ENVELOPE_BYTES,
    id: chunkId(index),
    plaintext_size: plaintext.length,
  }));
  const aggregate = createHash('sha256');
  chunks.forEach(chunk => aggregate.update(chunk));
  const manifest = canonicalManifest({
    algorithm: 'AES-256-GCM',
    chunk_count: chunks.length,
    chunks: metadata,
    format_version: 1,
    plaintext_sha256: aggregate.digest('hex'),
  });
  assert.ok(manifest.length <= MAX_MANIFEST_BYTES);
  const encrypted = chunks.map((plaintext, index) => {
    const nonce = Buffer.alloc(12);
    nonce.writeUInt32BE(0x4c484231, 0);
    nonce.writeBigUInt64BE(BigInt(index), 4);
    const cipher = createCipheriv('aes-256-gcm', KEY, nonce, { authTagLength: 16 });
    cipher.setAAD(aad(metadata[index].id, index, chunks.length, plaintext.length));
    const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    return Buffer.concat([nonce, cipher.getAuthTag(), ciphertext]);
  });
  return Buffer.concat([
    MAGIC,
    u32(manifest.length),
    manifest,
    ...encrypted.flatMap(chunk => [u32(chunk.length), chunk]),
  ]);
}

export function decodeLocalhold(container) {
  if (!Buffer.isBuffer(container)) throw new Error('invalidContainer');
  let offset = 0;
  const take = length => {
    if (!Number.isSafeInteger(length) || length < 0 || length > container.length - offset) {
      throw new Error('truncated');
    }
    const value = container.subarray(offset, offset + length);
    offset += length;
    return value;
  };
  if (!take(MAGIC.length).equals(MAGIC)) throw new Error('unsupported');
  const manifestLength = take(4).readUInt32BE();
  if (manifestLength > MAX_MANIFEST_BYTES) throw new Error('manifestTooLarge');
  const manifestBytes = take(manifestLength);
  let manifest;
  try {
    manifest = JSON.parse(manifestBytes.toString('utf8'));
  } catch {
    throw new Error('invalidManifest');
  }
  if (!canonicalManifest(manifest).equals(manifestBytes)) throw new Error('nonCanonicalManifest');
  if (!exactFields(manifest, TOP_LEVEL_FIELDS)) throw new Error('unknownManifestField');
  if (manifest.format_version !== 1 || manifest.algorithm !== 'AES-256-GCM') throw new Error('unsupported');
  if (!Number.isInteger(manifest.chunk_count) || manifest.chunk_count < 0 || manifest.chunk_count > MAX_CHUNKS) {
    throw new Error('invalidCount');
  }
  if (!Array.isArray(manifest.chunks) || manifest.chunks.length !== manifest.chunk_count) {
    throw new Error('invalidChunkMetadata');
  }
  if (typeof manifest.plaintext_sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(manifest.plaintext_sha256)) {
    throw new Error('invalidDigest');
  }
  const ids = new Set();
  manifest.chunks.forEach((item, index) => {
    if (!exactFields(item, CHUNK_FIELDS)) throw new Error('unknownChunkField');
    if (item.id !== chunkId(index) || ids.has(item.id)) throw new Error('duplicateOrInvalidId');
    ids.add(item.id);
    if (!Number.isInteger(item.plaintext_size) || item.plaintext_size < 0
      || item.plaintext_size > MAX_PLAINTEXT_CHUNK_BYTES) throw new Error('plaintextSize');
    if (!Number.isInteger(item.ciphertext_size)
      || item.ciphertext_size !== item.plaintext_size + ENVELOPE_BYTES) throw new Error('ciphertextSize');
  });

  const plaintext = [];
  const aggregate = createHash('sha256');
  for (let index = 0; index < manifest.chunk_count; index += 1) {
    const metadata = manifest.chunks[index];
    const length = take(4).readUInt32BE();
    if (length !== metadata.ciphertext_size) throw new Error('chunkLengthMismatch');
    const chunk = take(length);
    const nonce = chunk.subarray(0, 12);
    const tag = chunk.subarray(12, 28);
    const ciphertext = chunk.subarray(28);
    const expectedNonce = Buffer.alloc(12);
    expectedNonce.writeUInt32BE(0x4c484231, 0);
    expectedNonce.writeBigUInt64BE(BigInt(index), 4);
    if (!nonce.equals(expectedNonce)) throw new Error('nonceMismatch');
    const decipher = createDecipheriv('aes-256-gcm', KEY, nonce, { authTagLength: 16 });
    decipher.setAAD(aad(metadata.id, index, manifest.chunk_count, metadata.plaintext_size));
    decipher.setAuthTag(tag);
    const clear = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    if (clear.length !== metadata.plaintext_size) throw new Error('plaintextSizeMismatch');
    aggregate.update(clear);
    plaintext.push(clear);
  }
  if (offset !== container.length) throw new Error('trailingData');
  if (aggregate.digest('hex') !== manifest.plaintext_sha256) throw new Error('integrity');
  return plaintext;
}

export const limitsForTesting = Object.freeze({
  magicBytes: MAGIC.length,
  maxManifestBytes: MAX_MANIFEST_BYTES,
  maxPlaintextChunkBytes: MAX_PLAINTEXT_CHUNK_BYTES,
});
