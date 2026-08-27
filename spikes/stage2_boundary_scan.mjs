// SPDX-License-Identifier: MPL-2.0
import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { extname, join, relative } from 'node:path';

const root = new URL('.', import.meta.url);
const scannedExtensions = new Set([
  '.kt', '.swift', '.java', '.xml', '.dart', '.mjs', '.py', '.ps1', '.sh',
]);
const licensedExtensions = new Set([
  '.kt', '.swift', '.java', '.dart', '.mjs', '.py', '.ps1', '.sh',
]);
const forbiddenNetwork = [
  'android.permission.INTERNET',
  'HttpURLConnection',
  'OkHttpClient',
  'Retrofit.Builder',
  'URLSession',
  'NWConnection',
  'dart:io HttpClient',
];
const generatedFileNames = new Set(['GeneratedPluginRegistrant.java']);

async function files(directory) {
  const output = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (['build', '.dart_tool', '.gradle', 'Pods', 'Flutter'].includes(entry.name)) continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) output.push(...await files(path));
    else if (
      scannedExtensions.has(extname(entry.name)) &&
      !generatedFileNames.has(entry.name)
    ) output.push(path);
  }
  return output;
}

const rootPath = decodeURIComponent(root.pathname).replace(/^\/(?:([A-Za-z]):)/, '$1:');
const sourceFiles = await files(rootPath);
assert.ok(sourceFiles.length > 10, 'unexpectedly small Stage 2 source set');

for (const path of sourceFiles) {
  const source = await readFile(path, 'utf8');
  const relativePath = relative(rootPath, path);
  if (licensedExtensions.has(extname(path))) {
    const header = source.split(/\r?\n/, 5).join('\n');
    assert.ok(
      header.includes('SPDX-License-Identifier: MPL-2.0'),
      `${relativePath} lacks the MPL-2.0 SPDX marker in its first five lines`,
    );
  }
  if (relativePath === 'stage2_boundary_scan.mjs') continue;
  const isTestSource = /(^|[\\/])(test|tests|androidTest)([\\/]|$)/.test(relativePath);
  // Test code contains negative assertions naming forbidden clients. Test
  // manifests remain scanned so an INTERNET permission cannot hide there.
  if (isTestSource && extname(path) !== '.xml') continue;
  for (const token of forbiddenNetwork) {
    assert.ok(!source.includes(token), `${relativePath} contains ${token}`);
  }
}

console.log(`Stage 2 boundary scan passed for ${sourceFiles.length} source files.`);
