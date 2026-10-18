/**
 * 背景星空：一个原生 Canvas 粒子层，不引入任何动画库。
 *
 * 性能约束（design.md R-2）：像素比上限 2、星点数量按视口面积截断、
 * 简洁模式下停掉 requestAnimationFrame（只留一帧静态星点）。
 */

type Star = {
  x: number;
  y: number;
  r: number;
  alpha: number;
  speed: number;
};

const MAX_STARS = 120;
const MIN_STARS = 24;
const PIXELS_PER_STAR = 16000;

function readInk(): string {
  const value = getComputedStyle(document.documentElement)
    .getPropertyValue("--sg-green")
    .trim();
  return value === "" ? "#00ff41" : value;
}

export function initParticles(): void {
  const canvas = document.querySelector<HTMLCanvasElement>(".sg-particles");
  if (!canvas) return;
  if (canvas.dataset.enabled === "off") return;

  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const ink = readInk();

  let width = 0;
  let height = 0;
  let stars: Star[] = [];
  let frame = 0;
  let running = false;

  const resize = (): void => {
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = Math.floor(width * dpr);
    canvas.height = Math.floor(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const count = Math.min(
      MAX_STARS,
      Math.max(MIN_STARS, Math.round((width * height) / PIXELS_PER_STAR)),
    );
    stars = Array.from({ length: count }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      r: 0.4 + Math.random() * 1.2,
      alpha: 0.15 + Math.random() * 0.5,
      speed: 0.05 + Math.random() * 0.25,
    }));
  };

  const paint = (): void => {
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = ink;
    for (const star of stars) {
      ctx.globalAlpha = star.alpha;
      ctx.beginPath();
      ctx.arc(star.x, star.y, star.r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  };

  const loop = (): void => {
    for (const star of stars) {
      star.y += star.speed;
      if (star.y > height) {
        star.y = 0;
        star.x = Math.random() * width;
      }
    }
    paint();
    frame = window.requestAnimationFrame(loop);
  };

  const start = (): void => {
    if (running) return;
    running = true;
    frame = window.requestAnimationFrame(loop);
  };

  const stop = (): void => {
    running = false;
    window.cancelAnimationFrame(frame);
  };

  resize();
  paint();
  window.addEventListener("resize", () => {
    resize();
    paint();
  });

  if (document.documentElement.getAttribute("data-motion") !== "off") start();

  document.addEventListener("sg:motion", (event) => {
    const detail = (event as CustomEvent<{ motion: string }>).detail;
    if (detail?.motion === "off") stop();
    else start();
  });
}
