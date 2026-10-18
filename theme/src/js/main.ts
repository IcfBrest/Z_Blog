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
import { initComments } from "./comments";
import { initSearch } from "./search";

function boot(): void {
  initMotion();
  initWorldline();
  initDivergence();
  initTypewriter();
  initParticles();
  initPointerGlow();
  // 搜索按钮依赖插件的全局对象，内部自带「晚到就等一会儿、实在没有就摘掉」的兜底
  initSearch();
  // 评论按需加载外部脚本，不阻塞首屏；失败时只降级，不影响正文
  void initComments();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot, { once: true });
} else {
  boot();
}
