/**
 * 交互层入口：按依赖顺序装配各模块。
 *
 * 顺序有意为之：先由 motion 决定动效状态，再让世界线、辉光管、打字机、粒子与
 * 鼠标辉光各自读取当前状态，避免模块之间读到中间态。
 */

import "../css/main.css";

import { initWorldline } from "./worldline";
import { initMotion } from "./motion";
import { initDivergence } from "./divergence";
import { initTypewriter } from "./typewriter";
import { initParticles } from "./particles";
import { initPointerGlow } from "./pointer-glow";

function boot(): void {
  initMotion();
  initWorldline();
  initDivergence();
  initTypewriter();
  initParticles();
  initPointerGlow();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot, { once: true });
} else {
  boot();
}
