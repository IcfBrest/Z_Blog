/**
 * 世界线切换：把访客的选择写进 localStorage，并同步 <html data-worldline>。
 *
 * 首屏的属性由 layout 的 boot 内联脚本与服务端默认值决定，本模块只处理点击后的翻转，
 * 因此不需要在模块里再读一次 localStorage（避免两份真相）。
 */

import { resolveWorldline, WORLDLINE_LABELS } from "./logic.mjs";
import type { Worldline } from "./logic.mjs";

const STORAGE_KEY = "sg-worldline";

function store(value: Worldline): void {
  try {
    localStorage.setItem(STORAGE_KEY, value);
  } catch {
    /* 隐私模式或配额满：只让本次会话生效，不打断交互 */
  }
}

function describe(current: Worldline): string {
  return current === "beta"
    ? "当前为 β 世界线，点击切换到 α 世界线"
    : "当前为 α 世界线，点击切换到 β 世界线";
}

export function initWorldline(): void {
  const root = document.documentElement;
  const button = document.getElementById("sg-worldline-toggle");
  const label = root.querySelector<HTMLElement>("[data-worldline-label]");

  let current: Worldline = resolveWorldline(root.getAttribute("data-worldline"));

  const sync = (): void => {
    root.setAttribute("data-worldline", current);
    if (label) label.textContent = WORLDLINE_LABELS[current];
    if (button) {
      button.setAttribute("aria-label", describe(current));
      button.setAttribute("aria-pressed", current === "alpha" ? "true" : "false");
    }
  };

  sync();

  button?.addEventListener("click", () => {
    current = current === "beta" ? "alpha" : "beta";
    store(current);
    sync();
  });
}
