/**
 * logic.mjs 的类型声明：让 .ts 模块获得补全与检查，同时保持运行时文件是
 * 纯 ESM（node 可直接 import 做单测，不需要构建）。
 */

export type Worldline = "alpha" | "beta";
export type Motion = "on" | "off";

export const WORLDLINES: readonly Worldline[];
export const MOTIONS: readonly Motion[];
export const DEFAULT_WORLDLINE: Worldline;
export const WORLDLINE_LABELS: Record<Worldline, string>;

export type DivergenceUnit = {
  type: "digit" | "dot" | "percent";
  value: string;
};

export function resolveWorldline(stored: unknown, fallback?: unknown): Worldline;

export function resolveMotion(
  stored: unknown,
  prefersReduced: boolean,
  serverDefault?: unknown,
): { motion: Motion; source: "user" | "system" | "server" };

export function formatDivergence(value: unknown): string;

export function padDigits(text: unknown): DivergenceUnit[];

export function easeOutValue(from: number, to: number, t: number): number;
