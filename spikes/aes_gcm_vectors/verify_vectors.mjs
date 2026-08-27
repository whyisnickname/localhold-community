// SPDX-License-Identifier: MPL-2.0
import assert from 'node:assert/strict';
import { createCipheriv, createDecipheriv } from 'node:crypto';
import { readFile } from 'node:fs/promises';

const document = JSON.parse(await readFile(new URL('./vectors.json', import.meta.url), 'utf8'));
assert.equal(document.algorithm, 'AES-256-GCM');
assert.equal(document.nonce_bytes, 12);
assert.equal(document.tag_bytes, 16);

const decode = value => Buffer.from(value, 'hex');
const flipFirstBit = value => {
  const changed = Buffer.from(value);
  changed[0] ^= 1;
  return changed;
};

for (const vector of document.vectors) {
  const key = decode(vector.key_hex);
  const nonce = decode(vector.nonce_hex);
  const aad = decode(vector.aad_hex);
  const plaintext = decode(vector.plaintext_hex);
  const expectedCiphertext = decode(vector.ciphertext_hex);
  const expectedTag = decode(vector.tag_hex);

  const cipher = createCipheriv('aes-256-gcm', key, nonce, { authTagLength: 16 });
  cipher.setAAD(aad);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  assert.deepEqual(ciphertext, expectedCiphertext, `${vector.id}: ciphertext`);
  assert.deepEqual(cipher.getAuthTag(), expectedTag, `${vector.id}: tag`);

  const open = (candidateNonce, candidateAad, candidateCiphertext, candidateTag) => {
    const decipher = createDecipheriv('aes-256-gcm', key, candidateNonce, { authTagLength: 16 });
    decipher.setAAD(candidateAad);
    decipher.setAuthTag(candidateTag);
    return Buffer.concat([decipher.update(candidateCiphertext), decipher.final()]);
  };
  assert.deepEqual(open(nonce, aad, ciphertext, expectedTag), plaintext, `${vector.id}: decrypt`);
  assert.throws(() => open(flipFirstBit(nonce), aad, ciphertext, expectedTag));
  assert.throws(() => open(nonce, flipFirstBit(aad), ciphertext, expectedTag));
  assert.throws(() => open(nonce, aad, ciphertext.length ? flipFirstBit(ciphertext) : ciphertext, flipFirstBit(expectedTag)));
  assert.throws(() => open(nonce, aad, ciphertext, flipFirstBit(expectedTag)));
}

console.log(`Verified ${document.vectors.length} AES-256-GCM vectors and tamper failures.`);
