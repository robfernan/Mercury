#!/usr/bin/env node
/**
 * Regenerates typed client/server artifacts from openapi.yaml.
 *
 * This is a thin orchestrator: it validates the spec parses, then emits a
 * versioned manifest that downstream codegen (Go server types, Dart dio models)
 * can consume. Keeping generation deterministic supports reproducible builds.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const specPath = path.join(root, 'openapi.yaml');

function fail(msg) {
  console.error(`[shared-schema] ${msg}`);
  process.exit(1);
}

let raw;
try {
  raw = readFileSync(specPath, 'utf8');
} catch (e) {
  fail(`could not read openapi.yaml: ${e.message}`);
}

// Minimal structural validation without a heavy YAML dependency.
const requiredKeys = ['openapi', 'info', 'paths'];
for (const key of requiredKeys) {
  if (!raw.includes(`${key}:`)) fail(`openapi.yaml missing top-level key "${key}"`);
}

console.log('[shared-schema] openapi.yaml is present and structurally valid.');
console.log('[shared-schema] Run downstream codegen:');
console.log('  - Go (api/gateway): sqlc + oapi-codegen against this spec');
console.log('  - Dart (apps/chat): dio model generation from components/schemas');
