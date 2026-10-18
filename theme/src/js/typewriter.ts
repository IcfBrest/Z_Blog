/**
 * 打字机：逐字显示 [data-typing] 元素上的文本。
 *
 * 元素本身已经在 HTML 里写了完整文本（无脚本时直接可读），本模块先把文本清空，
 * 再按字补齐；简洁模式下直接保留完整文本，不播动画。
 */

const CHAR_DELAY = 90;
const START_DELAY = 260;

export function initTypewriter(): void {
  const el = document.querySelector<HTMLElement>("[data-typing]");
  if (!el) return;

  const full = el.dataset.typing ?? "";
  if (full === "") return;

  const finish = (): void => {
    el.textContent = full;
    el.dataset.typingDone = "1";
  };

  if (document.documentElement.getAttribute("data-motion") === "off") {
    finish();
    return;
  }

  let index = 0;
  el.textContent = "";

  const tick = (): void => {
    if (index >= full.length) {
      finish();
      return;
    }
    el.textContent += full[index] ?? "";
    index += 1;
    window.setTimeout(tick, CHAR_DELAY);
  };

  window.setTimeout(tick, START_DELAY);

  document.addEventListener("sg:motion", (event) => {
    const detail = (event as CustomEvent<{ motion: string }>).detail;
    if (detail?.motion === "off") finish();
  });
}
