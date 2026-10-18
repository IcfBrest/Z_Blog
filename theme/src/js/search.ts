/**
 * 搜索入口：把页头那个按钮接到 PluginSearchWidget 暴露的全局 `SearchWidget` 上。
 *
 * 插件的脚本是 `defer` 加载的，可能晚于 DOMContentLoaded，因此这里分两步：
 * 先立刻尝试绑定；拿不到就短轮询一段时间（最多 5 秒），超时后把入口摘掉，
 * 避免留下一个点了没反应的按钮。轮询结束即清理，不常驻定时器。
 */

type SearchWidgetGlobal = {
  open: () => void;
};

const BUTTON_SELECTOR = "[data-sg-search]";
const SHORTCUT_KEY = "/";
const POLL_INTERVAL_MS = 200;
const MAX_ATTEMPTS = 25;

function readWidget(): SearchWidgetGlobal | null {
  const candidate = (window as unknown as { SearchWidget?: SearchWidgetGlobal }).SearchWidget;
  return candidate && typeof candidate.open === "function" ? candidate : null;
}

/** 焦点在可输入元素里时，`/` 是正常字符，不能被当成快捷键 */
function isTyping(): boolean {
  const active = document.activeElement;
  if (!(active instanceof HTMLElement)) return false;
  if (active.isContentEditable) return true;
  return active.tagName === "INPUT" || active.tagName === "TEXTAREA" || active.tagName === "SELECT";
}

export function initSearch(): void {
  const button = document.querySelector<HTMLElement>(BUTTON_SELECTOR);
  if (!button) return;

  let bound = false;

  const attach = (widget: SearchWidgetGlobal): void => {
    if (bound) return;
    bound = true;

    button.addEventListener("click", () => widget.open());

    document.addEventListener("keydown", (event: KeyboardEvent) => {
      if (event.key !== SHORTCUT_KEY) return;
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      if (isTyping()) return;
      event.preventDefault();
      widget.open();
    });
  };

  const ready = readWidget();
  if (ready) {
    attach(ready);
    return;
  }

  let attempts = 0;
  const timer = window.setInterval(() => {
    attempts += 1;
    const widget = readWidget();
    if (widget) {
      window.clearInterval(timer);
      attach(widget);
      return;
    }
    if (attempts >= MAX_ATTEMPTS) {
      window.clearInterval(timer);
      button.remove();
    }
  }, POLL_INTERVAL_MS);
}
