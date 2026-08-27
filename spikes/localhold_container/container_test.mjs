// SPDX-License-Identifier: MPL-2.0
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { decodeLocalhold, encodeLocalhold, limitsForTesting } from './container.mjs';

const chunks = [
  Buffer.alloc(0),
  Buffer.from('Localhold synthetic'),
  Buffer.from(Array.from({ length: 4097 }, (_, i) => i & 0xff)),
];
const encoded = encodeLocalhold(chunks);
assert.deepEqual(decodeLocalhold(encoded), chunks);
assert.deepEqual(decodeLocalhold(encodeLocalhold([])), []);
assert.deepEqual(decodeLocalhold(encodeLocalhold([Buffer.from([0x7f])])), [Buffer.from([0x7f])]);

function u32(value) {
  const output = Buffer.alloc(4);
  output.writeUInt32BE(value);
  return output;
}

function splitContainer(container = encoded) {
  const manifestLength = container.readUInt32BE(8);
  const manifestStart = 12;
  const manifestEnd = manifestStart + manifestLength;
  return {
    manifest: JSON.parse(container.subarray(manifestStart, manifestEnd).toString('utf8')),
    manifestText: container.subarray(manifestStart, manifestEnd).toString('utf8'),
    payload: container.subarray(manifestEnd),
  };
}

function withManifest(manifest, payload = splitContainer().payload) {
  const bytes = Buffer.from(JSON.stringify(manifest), 'utf8');
  return Buffer.concat([Buffer.from('LOCALH1\n'), u32(bytes.length), bytes, payload]);
}

function withManifestText(text, payload = splitContainer().payload) {
  const bytes = Buffer.from(text, 'utf8');
  return Buffer.concat([Buffer.from('LOCALH1\n'), u32(bytes.length), bytes, payload]);
}

assert.throws(() => decodeLocalhold(encoded.subarray(0, encoded.length - 1)), /truncated/);
const tampered = Buffer.from(encoded);
tampered[tampered.length - 1] ^= 1;
assert.throws(() => decodeLocalhold(tampered));
assert.throws(() => decodeLocalhold(Buffer.concat([encoded, Buffer.from([0])])), /trailingData/);
const wrongMagic = Buffer.from(encoded);
wrongMagic[0] ^= 1;
assert.throws(() => decodeLocalhold(wrongMagic), /unsupported/);

const { manifest, manifestText, payload } = splitContainer();
const unknownVersion = structuredClone(manifest);
unknownVersion.format_version = 2;
assert.throws(() => decodeLocalhold(withManifest(unknownVersion)), /unsupported/);

const duplicateId = structuredClone(manifest);
duplicateId.chunks[1].id = duplicateId.chunks[0].id;
assert.throws(() => decodeLocalhold(withManifest(duplicateId)), /duplicateOrInvalidId/);

const falsePlaintextSize = structuredClone(manifest);
falsePlaintextSize.chunks[1].plaintext_size += 1;
falsePlaintextSize.chunks[1].ciphertext_size += 1;
assert.throws(() => decodeLocalhold(withManifest(falsePlaintextSize)), /chunkLengthMismatch/);

const oversizedPlaintext = structuredClone(manifest);
oversizedPlaintext.chunks[0].plaintext_size = limitsForTesting.maxPlaintextChunkBytes + 1;
oversizedPlaintext.chunks[0].ciphertext_size = oversizedPlaintext.chunks[0].plaintext_size + 28;
assert.throws(() => decodeLocalhold(withManifest(oversizedPlaintext)), /plaintextSize/);

const unknownCompression = structuredClone(manifest);
unknownCompression.zzz_compression = 'gzip';
assert.throws(() => decodeLocalhold(withManifest(unknownCompression)), /unknownManifestField/);

const duplicateJsonKey = manifestText.replace(
  '"format_version":1',
  '"format_version":1,"format_version":1',
);
assert.throws(() => decodeLocalhold(withManifestText(duplicateJsonKey)), /nonCanonicalManifest/);

const nonCanonicalWhitespace = manifestText.replace('{', '{ ');
assert.throws(() => decodeLocalhold(withManifestText(nonCanonicalWhitespace)), /nonCanonicalManifest/);

const overflowChunkLength = Buffer.from(payload);
overflowChunkLength.writeUInt32BE(0xffffffff, 0);
assert.throws(
  () => decodeLocalhold(withManifestText(manifestText, overflowChunkLength)),
  /chunkLengthMismatch/,
);

const manifestBombHeader = Buffer.concat([
  Buffer.from('LOCALH1\n'),
  u32(limitsForTesting.maxManifestBytes + 1),
]);
assert.throws(() => decodeLocalhold(manifestBombHeader), /manifestTooLarge/);

assert.throws(
  () => encodeLocalhold([Buffer.alloc(limitsForTesting.maxPlaintextChunkBytes + 1)]),
);

const digest = createHash('sha256').update(encoded).digest('hex');
console.log(`.localhold reference round-trip and hostile-input suite passed (${encoded.length} bytes, ${digest}).`);
