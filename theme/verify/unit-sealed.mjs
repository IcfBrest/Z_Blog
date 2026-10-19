#!/usr/bin/env node
// D-Mail 加密往返用例（Node 侧，与浏览器同构的 WebCrypto）
//
//   node theme/verify/unit-sealed.mjs
//
// 覆盖：往返一致、错误口令拒绝、密文篡改拒绝、盐与 IV 随机、参数可解析、
// 密文块不含明文、长正文往返。退出码 0 全通过 / 1 有失败。

import { sealText, openBlock, parseBlock } from '../../tools/seal.mjs';

let pass = 0;
let fail = 0;
const ok = (m) => {
  pass += 1;
  process.stdout.write(`  ✓ ${m}\n`);
};
const bad = (m) => {
  fail += 1;
  process.stdout.write(`  ✗ ${m}\n`);
};

const PHRASE = 'el psy kongroo 2036';
const ITER = 200000;
const PLAIN = [
  '<h2>世界线变动率</h2>',
  '<p>这是一封 D-Mail：α 世界线的记录。</p>',
  '<ul><li>1.048596%</li><li>El Psy Kongroo.</li></ul>',
].join('\n');

// 1. 往返一致
const block = await sealText(PLAIN, PHRASE, ITER);
const back = await openBlock(block, PHRASE);
back === PLAIN ? ok('加密后可原样解回') : bad('加密后解回的内容不一致');

// 2. 结构
block.includes('data-dmail-sealed') ? ok('密文块带 data-dmail-sealed 标记') : bad('密文块缺少标记');
const parsed = parseBlock(block);
parsed.iterations === ITER ? ok(`data-iter 解析为 ${ITER}`) : bad(`data-iter 解析错误：${parsed.iterations}`);
parsed.salt.length === 16 ? ok('盐为 16 字节') : bad(`盐长度异常：${parsed.salt.length}`);
parsed.iv.length === 12 ? ok('IV 为 12 字节') : bad(`IV 长度异常：${parsed.iv.length}`);

// 3. 明文不泄漏
const leaks = ['世界线变动率', 'D-Mail', 'El Psy', '1.048596%', 'sg-sealed__'].filter((s) => block.includes(s));
leaks.length === 0 ? ok('密文块不含原文任何片段') : bad(`密文块泄漏原文：${leaks.join(', ')}`);

// 4. 错误口令
let wrongRejected = false;
try {
  await openBlock(block, 'wrong passphrase');
} catch {
  wrongRejected = true;
}
wrongRejected ? ok('错误口令被拒绝') : bad('错误口令竟然解开了');

// 5. 篡改检测（改 base64 中间一个字符）
const cipherText = block.match(/<div[^>]*>([\s\S]*?)<\/div>/)[1].trim();
const at = Math.floor(cipherText.length / 2);
const flipped = cipherText[at] === 'A' ? 'B' : 'A';
const tampered = block.replace(cipherText, cipherText.slice(0, at) + flipped + cipherText.slice(at + 1));
let tamperRejected = false;
try {
  await openBlock(tampered, PHRASE);
} catch {
  tamperRejected = true;
}
tamperRejected ? ok('密文被改动后解密失败') : bad('密文被改动了却仍能解开');

// 6. 盐与 IV 每次不同
const block2 = await sealText(PLAIN, PHRASE, ITER);
const p2 = parseBlock(block2);
Buffer.from(parsed.salt).equals(Buffer.from(p2.salt)) ? bad('两次加密用了同一个盐') : ok('每次加密的盐不同');
Buffer.from(parsed.iv).equals(Buffer.from(p2.iv)) ? bad('两次加密用了同一个 IV') : ok('每次加密的 IV 不同');

// 7. 长正文
const long = PLAIN.repeat(120);
const longBack = await openBlock(await sealText(long, PHRASE, ITER), PHRASE);
longBack === long ? ok(`长正文（${long.length} 字符）往返一致`) : bad('长正文往返不一致');

process.stdout.write(`\n${fail === 0 ? '✅' : '❌'} 通过 ${pass} 项，失败 ${fail} 项。\n`);
process.exit(fail === 0 ? 0 : 1);
