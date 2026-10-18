/**
 * 交互层的纯逻辑：不碰 DOM、不读写存储，可被 node 直接单测。
 *
 * 边界约定：本文件只做「给定输入 → 决策」；DOM 与 localStorage 的副作用
 * 一律留在同目录的 .ts 模块里。
 */

export const WORLDLINES = ["alpha", "beta"];
export const MOTIONS = ["on", "off"];

/** 与 settings.yaml 的 worldline_default 保持一致 */
export const DEFAULT_WORLDLINE = "beta";

/** 展示用的世界线名 */
export const WORLDLINE_LABELS = { alpha: "α", beta: "β" };

/**
 * 解析世界线：存储值合法就用它，否则回落到服务端默认值，再否则用 beta。
 *
 * @param {unknown} stored localStorage 里读到的值（可能为 null / 任意字符串）
 * @param {unknown} [fallback] 服务端渲染的默认世界线
 * @returns {"alpha" | "beta"}
 */
export function resolveWorldline(stored, fallback = DEFAULT_WORLDLINE) {
  if (WORLDLINES.includes(stored)) return stored;
  if (WORLDLINES.includes(fallback)) return fallback;
  return DEFAULT_WORLDLINE;
}

/**
 * 解析动效模式。优先级：访客显式选择 > 系统减少动效偏好 > 服务端默认。
 *
 * @param {unknown} stored 访客的选择（"on" / "off" / null）
 * @param {boolean} prefersReduced 系统是否要求减少动效
 * @param {unknown} [serverDefault] 主题设置项决定的默认值
 * @returns {{ motion: "on" | "off", source: "user" | "system" | "server" }}
 */
export function resolveMotion(stored, prefersReduced, serverDefault = "on") {
  if (MOTIONS.includes(stored)) return { motion: stored, source: "user" };
  if (prefersReduced === true) return { motion: "off", source: "system" };
  return {
    motion: MOTIONS.includes(serverDefault) ? serverDefault : "on",
    source: "server",
  };
}

/**
 * 把数值格式化成六位小数（不含 %）。负数与非法值按 0 处理，
 * 因为站点文章数不可能是负数。
 *
 * @param {unknown} value
 * @returns {string}
 */
export function formatDivergence(value) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return "0.000000";
  return n.toFixed(6);
}

/**
 * 把 "1.048596%" 这样的展示值拆成渲染单元：数字位、小数点、百分号。
 * 小数位不足 6 位时补零，多余位截断；整数部分缺失时补 "0"。
 *
 * @param {unknown} text
 * @returns {{ type: "digit" | "dot" | "percent", value: string }[]}
 */
export function padDigits(text) {
  const raw = String(text ?? "").trim().replace(/%+$/, "");
  const numeric = raw === "" ? "0" : raw;
  const [rawInt, rawFrac] = numeric.split(".");
  const intPart = rawInt === "" ? "0" : rawInt;
  const fracPart = (rawFrac ?? "").padEnd(6, "0").slice(0, 6);

  const units = [];
  for (const ch of intPart) units.push({ type: "digit", value: ch });
  units.push({ type: "dot", value: "." });
  for (const ch of fracPart) units.push({ type: "digit", value: ch });
  units.push({ type: "percent", value: "%" });
  return units;
}

/**
 * 数字滚动的中间值：从 from 到 to 做三次缓出插值。
 *
 * @param {number} from
 * @param {number} to
 * @param {number} t 0..1，超出范围会被夹紧
 * @returns {number}
 */
export function easeOutValue(from, to, t) {
  const raw = Number(t);
  const clamped = Number.isFinite(raw) ? Math.min(1, Math.max(0, raw)) : 0;
  const eased = 1 - Math.pow(1 - clamped, 3);
  return from + (to - from) * eased;
}
