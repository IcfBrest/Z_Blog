/**
 * 简洁模式：把动效状态写到 <html data-motion>，并在本地记住访客的选择。
 *
 * 优先级完全交给 logic.mjs 的 resolveMotion：访客显式选择 > 系统减少动效偏好 >
 * 主题设置项默认值。翻转时补上 data-motion-source="user"，让 CSS 里的
 * prefers-reduced-motion 兜底规则不再覆盖访客的手动选择。
 */

import { resolveMotion } from "./logic.mjs";
import type { Motion } from "./logic.mjs";

const STORAGE_KEY = "sg-motion";

function readStored(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

function store(value: Motion): void {
  try {
    localStorage.setItem(STORAGE_KEY, value);
  } catch {
    /* 隐私模式下只在本次会话生效 */
  }
}

export function initMotion(): void {
  const root = document.documentElement;
  const button = document.getElementById("sg-motion-toggle");
  const label = root.querySelector<HTMLElement>("[data-motion-label]");
  const media = window.matchMedia("(prefers-reduced-motion: reduce)");
  const serverDefault: Motion = root.getAttribute("data-motion") === "off" ? "off" : "on";

  let resolved = resolveMotion(readStored(), media.matches, serverDefault);

  const sync = (): void => {
    root.setAttribute("data-motion", resolved.motion);
    if (resolved.source === "user") root.setAttribute("data-motion-source", "user");
    else root.removeAttribute("data-motion-source");

    // 标签读作「简洁模式 关/开」：motion=off 即简洁模式开
    if (label) label.textContent = resolved.motion === "off" ? "开" : "关";
    if (button) {
      button.setAttribute("aria-pressed", resolved.motion === "off" ? "true" : "false");
      button.setAttribute(
        "aria-label",
        resolved.motion === "off"
          ? "简洁模式已开启，点击恢复动效"
          : "简洁模式已关闭，点击开启简洁模式",
      );
    }

    document.dispatchEvent(
      new CustomEvent("sg:motion", { detail: { motion: resolved.motion } }),
    );
  };

  sync();

  button?.addEventListener("click", () => {
    resolved = {
      motion: resolved.motion === "off" ? "on" : "off",
      source: "user",
    };
    store(resolved.motion);
    sync();
  });

  // 访客没手动选过时，跟随系统偏好的实时变化
  media.addEventListener("change", (event) => {
    if (resolved.source === "user") return;
    resolved = resolveMotion(null, event.matches, serverDefault);
    sync();
  });
}
