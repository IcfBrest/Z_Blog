#!/usr/bin/env node
// D-Mail 正文加密工具（零依赖，Node 20+）
//
// 用法：
//   node tools/seal.mjs --in 正文.md --pass '<口令>' [--out 密文.html] [--iter 200000]
//   node tools/seal.mjs --in 正文.md --pass '<口令>' --check --out 校验输出.txt
//   SG_SEAL_PASS='<口令>' node tools/seal.mjs --in 正文.md
//
// 产出可直接粘进文章正文（Console 的 HTML 源码模式）的密文块：
//   <div class="sg-sealed" data-dmail-sealed data-salt="…" data-iv="…" data-iter="200000">base64</div>
//
// 加密：PBKDF2-SHA256(iter) 派生 256 位密钥 → AES-256-GCM。
// GCM 自带完整性校验，密文被改动一个字节即解密失败。
//
// 注意：口令不进 shell 历史时优先用 SG_SEAL_PASS。

import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const ITER_DEFAULT = 200000;
const SALT_BYTES = 16;
const IV_BYTES = 12;
const SALT_ATTR = 'data-salt';
const IV_ATTR = 'data-iv';
const ITER_ATTR = 'data-iter';

const te = new TextEncoder();
const td = new TextDecoder();

/** Uint8Array → base64 */
export function toBase64(bytes) {
  return Buffer.from(bytes).toString('base64');
}

/** base64 → Uint8Array */
export function fromBase64(text) {
  return new Uint8Array(Buffer.from(text, 'base64'));
}

/** 口令 + 盐 + 迭代次数 → AES-GCM 密钥 */
export async function deriveKey(passphrase, salt, iterations) {
  const base = await crypto.subtle.importKey('raw', te.encode(passphrase), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

/** 加密正文，返回密文块 HTML */
export async function sealText(plain, passphrase, iterations = ITER_DEFAULT) {
  const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES));
  const iv = crypto.getRandomValues(new Uint8Array(IV_BYTES));
  const key = await deriveKey(passphrase, salt, iterations);
  const cipher = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, te.encode(plain));
  return (
    `<div class="sg-sealed" data-dmail-sealed ${SALT_ATTR}="${toBase64(salt)}" ` +
    `${IV_ATTR}="${toBase64(iv)}" ${ITER_ATTR}="${iterations}">${toBase64(new Uint8Array(cipher))}</div>`
  );
}

/** 从密文块里读出参数与密文 */
export function parseBlock(block) {
  const attr = (name) => {
    const m = block.match(new RegExp(`${name}="([^"]+)"`));
    return m ? m[1] : null;
  };
  const body = block.match(/<div[^>]*>([\s\S]*?)<\/div>/);
  const salt = attr(SALT_ATTR);
  const iv = attr(IV_ATTR);
  const iter = Number(attr(ITER_ATTR));
  const cipher = body ? body[1].trim() : '';
  if (!salt || !iv || !Number.isInteger(iter) || iter <= 0 || !cipher) {
    throw new Error('密文块缺少参数：需要 data-salt / data-iv / data-iter 与 base64 密文');
  }
  if (!block.includes('data-dmail-sealed')) {
    throw new Error('密文块缺少 data-dmail-sealed 标记');
  }
  return { salt: fromBase64(salt), iv: fromBase64(iv), iterations: iter, cipher: fromBase64(cipher) };
}

/** 解密一个密文块，口令错误或密文被改都会抛错 */
export async function openBlock(block, passphrase) {
  const { salt, iv, iterations, cipher } = parseBlock(block);
  const key = await deriveKey(passphrase, salt, iterations);
  const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, cipher);
  return td.decode(plain);
}

function usage() {
  process.stdout.write(
    [
      'D-Mail 正文加密工具',
      '',
      '  node tools/seal.mjs --in <正文文件> [--pass <口令>] [--out <输出文件>] [--iter 200000]',
      '  node tools/seal.mjs --check <密文块文件> [--pass <口令>] [--out <还原文件>]',
      '',
      '不传 --pass 时读环境变量 SG_SEAL_PASS（避免口令进 shell 历史）。',
      '不传 --out 时输出到标准输出。',
      '',
    ].join('\n'),
  );
}

function argOf(argv, name) {
  const i = argv.indexOf(name);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : null;
}

async function main(argv) {
  if (argv.includes('-h') || argv.includes('--help') || argv.length === 0) {
    usage();
    return 0;
  }
  const checkTarget = argOf(argv, '--check');
  const inFile = argOf(argv, '--in') ?? checkTarget;
  const outFile = argOf(argv, '--out');
  const pass = argOf(argv, '--pass') ?? process.env.SG_SEAL_PASS;
  const iter = Number(argOf(argv, '--iter') ?? ITER_DEFAULT);

  if (!inFile) {
    process.stderr.write('缺少 --in 或 --check\n');
    return 2;
  }
  if (!pass) {
    process.stderr.write('缺少口令：用 --pass 或环境变量 SG_SEAL_PASS\n');
    return 2;
  }
  if (pass.length < 8) {
    process.stderr.write('⚠ 口令短于 8 个字符，建议用更长的短语（本工具不做强度校验）\n');
  }

  const input = readFileSync(inFile, 'utf8');

  if (checkTarget) {
    let plain;
    try {
      plain = await openBlock(input, pass);
    } catch {
      process.stderr.write('解密失败：口令不正确，或密文已被改动。\n');
      return 1;
    }
    if (outFile) writeFileSync(outFile, plain, 'utf8');
    else process.stdout.write(plain);
    return 0;
  }

  if (!Number.isInteger(iter) || iter < 100000) {
    process.stderr.write('--iter 必须是不小于 100000 的整数\n');
    return 2;
  }
  const block = await sealText(input, pass, iter);
  if (/<\/?(?!div class="sg-sealed")[a-z]/i.test(block.replace(/<div[^>]*>[\s\S]*?<\/div>/, ''))) {
    process.stderr.write('内部错误：密文块里混入了原文标签\n');
    return 1;
  }
  if (outFile) writeFileSync(outFile, block + '\n', 'utf8');
  else process.stdout.write(block + '\n');
  return 0;
}

// 仅在直接执行时跑 CLI，被 import 时只导出函数
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2))
    .then((code) => process.exit(code))
    .catch((err) => {
      process.stderr.write(`${err?.message ?? err}\n`);
      process.exit(1);
    });
}
