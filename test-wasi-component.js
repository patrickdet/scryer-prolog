import { readFile } from 'node:fs/promises';
import { WASI } from 'wasi';
import { argv, env } from 'node:process';

const wasi = new WASI({
  version: 'preview1',
  args: argv,
  env,
});

const wasm = await WebAssembly.compile(
  await readFile(new URL('./target/scryer-prolog.wasm', import.meta.url)),
);

const instance = await WebAssembly.instantiate(wasm, wasi.getImportObject());

wasi.start(instance);

// Try to access the exported Scryer Prolog interface
console.log('WASM exports:', Object.keys(instance.exports));

// The component should export scryer:prolog/core functions
if (instance.exports['scryer:prolog/core@0.9.4']) {
  console.log('Found Scryer Prolog core interface');
  const prolog = instance.exports['scryer:prolog/core@0.9.4'];
  console.log('Core functions:', Object.keys(prolog));
}