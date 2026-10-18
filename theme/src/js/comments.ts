/**
 * 评论区：按需加载 Artalk 并挂载到 #sg-comments。
 *
 * 为什么运行时加载而不是打包进来：Artalk 的前端产物由评论后端自己托管
 * （<server>/dist/Artalk.js），升级评论后端时前端也跟着升级，主题不用重新发版。
 *
 * server 的取值来自主题设置「集成 · 评论服务地址」：
 *   - 线上留空 → 同源 /artalk（由 Caddy 剥前缀转发给 artalk 容器）
 *   - 本地填 http://localhost:23366（本地没有 Caddy 做前缀剥离）
 *
 * 注意 Artalk 的前端配置只有 `site`（站点名），没有 siteKey —— 实测 2.10.0 的
 * dist/Artalk.js 里 siteKey 出现 0 次。站点按名称归属，因此主题设置里的
 * 评论站点名必须与 Artalk 后台的站点名一致。
 */

const MOUNT_ID = "sg-comments";
const LOADED_ATTR = "data-sg-artalk";

interface ArtalkGlobal {
  init(options: Record<string, unknown>): unknown;
}

declare global {
  interface Window {
    Artalk?: ArtalkGlobal;
  }
}

/** 注入并等待一个脚本；同一 URL 只加载一次。 */
function loadScript(src: string): Promise<void> {
  const selector = `script[${LOADED_ATTR}="${src}"]`;
  const existing = document.querySelector<HTMLScriptElement>(selector);
  if (existing) {
    if (existing.dataset.sgLoaded === "1") return Promise.resolve();
    return new Promise((resolve, reject) => {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error(`脚本加载失败：${src}`)), {
        once: true,
      });
    });
  }

  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.defer = true;
    script.setAttribute(LOADED_ATTR, src);
    script.addEventListener(
      "load",
      () => {
        script.dataset.sgLoaded = "1";
        resolve();
      },
      { once: true },
    );
    script.addEventListener(
      "error",
      () => reject(new Error(`脚本加载失败：${src}`)),
      { once: true },
    );
    document.head.appendChild(script);
  });
}

/** 注入样式表；同一 URL 只注入一次。 */
function loadStyle(href: string): void {
  if (document.querySelector(`link[${LOADED_ATTR}="${href}"]`)) return;
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = href;
  link.setAttribute(LOADED_ATTR, href);
  document.head.appendChild(link);
}

/** 去掉结尾的斜杠，避免拼出 //dist/Artalk.js。 */
function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

export async function initComments(): Promise<void> {
  const mount = document.getElementById(MOUNT_ID);
  if (!mount) return;

  const server = trimTrailingSlash(mount.dataset.server || "/artalk");
  const site = mount.dataset.site || "";
  const pageKey = window.location.pathname;

  try {
    loadStyle(`${server}/dist/Artalk.css`);
    await loadScript(`${server}/dist/Artalk.js`);

    if (!window.Artalk) {
      throw new Error("Artalk 全局对象不存在");
    }

    window.Artalk.init({
      el: `#${MOUNT_ID}`,
      server,
      site,
      pageKey,
      pageTitle: document.title,
    });

    mount.dataset.sgReady = "1";
    const hint = mount.querySelector(".sg-comments__hint");
    if (hint) hint.remove();
  } catch (error) {
    // 评论挂了不能影响正文阅读，所以只做降级提示，不抛到全局
    mount.dataset.sgFailed = "1";
    const hint = mount.querySelector(".sg-comments__hint");
    if (hint) {
      hint.textContent = "RINE 频道连接失败，评论暂时无法显示。";
    }
    console.warn("[sg] 评论加载失败：", error);
  }
}
