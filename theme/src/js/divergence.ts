/**
 * Divergence Meter：把服务端直出的数值拆成辉光管单元，并在两种数据源之间滚动切换。
 *
 * 服务端已经渲染了终值文本与 data-value（禁用脚本时同样正确），本模块只负责
 * 「按位拆分 + 滚动过渡」。
 */

import { formatDivergence, padDigits, easeOutValue } from "./logic.mjs";

const ATTRACTOR = "1.048596";
const ROLL_MS = 600;

type Source = "attractor" | "live";

function motionOff(): boolean {
  return document.documentElement.getAttribute("data-motion") === "off";
}

export function initDivergence(): void {
  const meter = document.querySelector<HTMLElement>(".sg-divergence");
  if (!meter) return;

  const valueEl = meter.querySelector<HTMLElement>(".sg-divergence__value");
  if (!valueEl) return;

  const toggle = meter.querySelector<HTMLButtonElement>(".sg-divergence__toggle");
  const labelEl = toggle?.querySelector<HTMLElement>("span") ?? null;

  const attractor = ATTRACTOR;
  const live = meter.dataset.live && meter.dataset.live !== "" ? meter.dataset.live : "0.000000";

  let source: Source = meter.dataset.source === "live" ? "live" : "attractor";
  let current = source === "live" ? live : attractor;
  let frame = 0;

  const render = (text: string): void => {
    const fragment = document.createDocumentFragment();
    for (const unit of padDigits(text)) {
      const span = document.createElement("span");
      // 类名必须与 main.css 的单横线选择器一致：BEM 的双下划线在 Thymeleaf 里是
      // 表达式预处理分隔符，模板层面已经改名为 -digit / -dot，这里不能再用 __。
      if (unit.type === "digit") span.className = "sg-divergence-digit";
      else if (unit.type === "dot") span.className = "sg-divergence-dot";
      else span.className = "sg-divergence__percent";
      span.textContent = unit.value;
      fragment.appendChild(span);
    }
    valueEl.replaceChildren(fragment);
  };

  const syncAria = (): void => {
    const value = source === "live" ? live : attractor;
    meter.setAttribute("aria-label", `世界线变动率 ${value}%`);
    if (toggle) {
      toggle.setAttribute("aria-pressed", source === "live" ? "true" : "false");
      toggle.setAttribute(
        "aria-label",
        source === "attractor"
          ? "当前显示世界线变动率，点击切换到站点真实文章数"
          : "当前显示站点真实文章数，点击切换到世界线变动率",
      );
    }
    if (labelEl) labelEl.textContent = source === "attractor" ? "世界线变动率" : "站点观测值";
  };

  const animateTo = (target: string): void => {
    window.cancelAnimationFrame(frame);

    const from = Number(current);
    const to = Number(target);

    if (motionOff() || !Number.isFinite(from) || !Number.isFinite(to) || from === to) {
      current = target;
      render(current);
      return;
    }

    const start = performance.now();
    const tick = (now: number): void => {
      const progress = Math.min(1, (now - start) / ROLL_MS);
      if (progress >= 1) {
        current = target;
        render(current);
        return;
      }
      render(formatDivergence(easeOutValue(from, to, progress)));
      frame = window.requestAnimationFrame(tick);
    };
    frame = window.requestAnimationFrame(tick);
  };

  render(current);
  syncAria();

  toggle?.addEventListener("click", () => {
    source = source === "attractor" ? "live" : "attractor";
    meter.dataset.source = source;
    syncAria();
    animateTo(source === "live" ? live : attractor);
  });

  // 简洁模式打开时立刻定格到终值，避免动画卡在半路
  document.addEventListener("sg:motion", (event) => {
    const detail = (event as CustomEvent<{ motion: string }>).detail;
    if (detail?.motion === "off") {
      window.cancelAnimationFrame(frame);
      current = source === "live" ? live : attractor;
      render(current);
    }
  });
}
