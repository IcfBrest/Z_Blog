/**
 * 鼠标跟随辉光：用 CSS 变量把指针位置喂给 .sg-glow 的径向渐变。
 *
 * 只在「有精确指针 + 视口够宽 + 动效开启」时启用，触屏与窄屏直接不注册监听。
 */

const MIN_WIDTH = 768;

export function initPointerGlow(): void {
  const layer = document.querySelector<HTMLElement>(".sg-glow");
  if (!layer) return;
  if (layer.dataset.enabled === "off") return;
  if (window.matchMedia("(pointer: coarse)").matches) return;
  if (window.innerWidth < MIN_WIDTH) return;
  if (document.documentElement.getAttribute("data-motion") === "off") return;

  window.addEventListener(
    "pointermove",
    (event) => {
      layer.style.setProperty("--glow-x", `${event.clientX}px`);
      layer.style.setProperty("--glow-y", `${event.clientY}px`);
      layer.dataset.active = "1";
    },
    { passive: true },
  );

  document.addEventListener("mouseleave", () => {
    delete layer.dataset.active;
  });
}
