#!/usr/bin/env node
/**
 * 交互层纯逻辑的单测：`node theme/verify/unit-logic.mjs`
 *
 * 不引入任何测试框架，也不依赖浏览器：只断言 logic.mjs 的决策结果。
 * 退出码 0 = 全部通过，1 = 有失败。
 */

import {
  resolveWorldline,
  resolveMotion,
  formatDivergence,
  padDigits,
  easeOutValue,
} from "../src/js/logic.mjs";

let pass = 0;
let fail = 0;

function check(name, fn) {
  try {
    fn();
    pass += 1;
    console.log(`  ✅ ${name}`);
  } catch (error) {
    fail += 1;
    console.log(`  ❌ ${name}`);
    console.log(`      ${error.message}`);
  }
}

function eq(actual, expected) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`期望 ${e}，实际 ${a}`);
}

console.log("\n▸ 世界线解析");

check("存储为 alpha 时用 alpha", () => eq(resolveWorldline("alpha"), "alpha"));
check("存储为 beta 时用 beta", () => eq(resolveWorldline("beta"), "beta"));
check("存储为 null 时回落到默认 beta", () => eq(resolveWorldline(null), "beta"));
check("存储为非法值时不采信（XSS 式的脏值）", () =>
  eq(resolveWorldline("<script>alert(1)</script>"), "beta"),
);
check("存储非法但服务端默认 alpha 时用 alpha", () =>
  eq(resolveWorldline("garbage", "alpha"), "alpha"),
);
check("存储与服务端默认都非法时回落到 beta", () =>
  eq(resolveWorldline(undefined, "delta"), "beta"),
);

console.log("\n▸ 动效模式解析（访客 > 系统 > 服务端）");

check("访客显式关闭时，即使系统允许也用 off", () =>
  eq(resolveMotion("off", false, "on"), { motion: "off", source: "user" }),
);
check("访客显式开启时，即使系统要求减少也用 on", () =>
  eq(resolveMotion("on", true, "off"), { motion: "on", source: "user" }),
);
check("访客未选择且系统要求减少时用 off", () =>
  eq(resolveMotion(null, true, "on"), { motion: "off", source: "system" }),
);
check("访客未选择、系统不干预时用服务端默认 on", () =>
  eq(resolveMotion(undefined, false, "on"), { motion: "on", source: "server" }),
);
check("访客未选择、服务端默认 off 时用 off", () =>
  eq(resolveMotion(null, false, "off"), { motion: "off", source: "server" }),
);
check("存储脏值不被采信", () =>
  eq(resolveMotion("yes", false, "on"), { motion: "on", source: "server" }),
);

console.log("\n▸ 数值格式化");

check("世界线变动率原样保留六位", () => eq(formatDivergence(1.048596), "1.048596"));
check("空站点显示 0.000000", () => eq(formatDivergence(0), "0.000000"));
check("整数补足六位小数", () => eq(formatDivergence("12"), "12.000000"));
check("负数按 0 处理", () => eq(formatDivergence(-3), "0.000000"));
check("非数字按 0 处理", () => eq(formatDivergence("abc"), "0.000000"));
check("Infinity 按 0 处理", () => eq(formatDivergence(Infinity), "0.000000"));
check("缺失值按 0 处理", () => eq(formatDivergence(undefined), "0.000000"));

console.log("\n▸ 辉光管按位拆分");

check("1.048596% 拆成 1 位整数 + 小数点 + 6 位小数 + 百分号", () => {
  const units = padDigits("1.048596%");
  eq(units.length, 9);
  eq(units[0], { type: "digit", value: "1" });
  eq(units[1], { type: "dot", value: "." });
  eq(units[2], { type: "digit", value: "0" });
  eq(units[8], { type: "percent", value: "%" });
});
check("小数不足六位时补零", () => {
  const units = padDigits("12.5");
  eq(units.length, 10);
  eq(
    units.filter((u) => u.type === "digit").map((u) => u.value).join(""),
    "12500000",
  );
});
check("空字符串退化为 0.000000", () => {
  const units = padDigits("");
  eq(units.length, 9);
  eq(units[0], { type: "digit", value: "0" });
});
check("多余的小数位被截断", () => {
  const units = padDigits("1.12345678");
  eq(
    units.filter((u) => u.type === "digit").map((u) => u.value).join(""),
    "1123456",
  );
});
check("null 不抛异常", () => eq(padDigits(null).length, 9));

console.log("\n▸ 滚动插值");

check("t=0 返回起点", () => eq(easeOutValue(1, 2, 0), 1));
check("t=1 返回终点", () => eq(easeOutValue(1, 2, 1), 2));
check("t 超出范围时被夹紧", () => {
  eq(easeOutValue(1, 2, 9), 2);
  eq(easeOutValue(1, 2, -9), 1);
});
check("中间值落在区间内且快于线性（缓出）", () => {
  const mid = easeOutValue(0, 1, 0.5);
  if (!(mid > 0.5 && mid < 1)) throw new Error(`缓出中点应在 0.5 与 1 之间，实际 ${mid}`);
});
check("t 非数字时按 0 处理", () => eq(easeOutValue(1, 2, "abc"), 1));

console.log("\n──────────────────────────────");
console.log(`通过 ${pass} 项，失败 ${fail} 项。`);
process.exit(fail === 0 ? 0 : 1);
