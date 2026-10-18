# 变更提案

## 背景（Why）

M4a 之后站点有了评论与分享卡片，但还有三块读者会用到的能力没接上：

1. **没有站内搜索**。Halo 2.27 实例实测自带 `PluginSearchWidget` 1.7.1（发行版首次启动时解压进 `plugins/`），它已经把 `search-widget.iife.js` 与样式注入每个页面，`POST /apis/api.halo.run/v1alpha1/indices/-/search` 返回真实命中（实测 `total: 1`、标题带 `<mark>` 高亮、`processingTimeMillis: 39`）。缺的只是主题里的入口——插件 README 明确写「需要主题进行适配，不会主动显示搜索入口」。
2. **没有看板娘**。FR-4 要求左下角看板娘并且可以关掉。`LIlGG/plugin-live2d` v2.2.0 不随发行版提供，必须安装；实测把 JAR 丢进 `deploy/data/halo2/plugins/` 再重启**不会生效**（`/plugins/PluginLive2d/assets/static/live2d/live2d.js` 仍然 404，`PluginReconciler` 日志里根本没有该插件），必须走安装接口。
3. **没有访问统计**。FR-8.2 要求 umami 自托管统计。umami v3.4.0 只支持 PostgreSQL / MySQL，需要独立数据库，与 M4a「单容器 + 绑定挂载」的形态不同，因此用独立的可选叠加层承载，本地预览默认不启动，免得每次预览都多等两个容器。

三件事都要外部制品或额外常驻服务，且都只在真实访问时才有意义，所以合并为 M4b 一个变更，按「开箱即用 → 需安装 → 需额外服务」的顺序落地。

## 变更内容（What Changes）

1. **搜索入口**：`theme/src/partials/layout.html` 在页头控件区加一个受 `pluginFinder.available('PluginSearchWidget')` 守卫的搜索按钮，新增 `theme/src/js/search.ts` 绑定到插件暴露的 `window.SearchWidget.open()`；用插件提供的 `--halo-search-widget-*` CSS 变量把组件配色拉回世界线语义。
2. **看板娘联动**：`theme/src/css/pages.css` 让 `#live2d-widget` 在简洁模式（`:root[data-motion="off"]`）下隐藏，并给页脚补底部安全间距；`theme/verify/preview-test.sh` 新增 `--plugins`，通过插件安装接口装上 live2d 后断言 `plugin-live2d-config` 注入与静态资源可达。
3. **umami 统计**：新增 `deploy/docker-compose.analytics.yml`（umami + 独立 PostgreSQL 命名卷）、`/umami/*` 反代、备份覆盖 umami 库；主题新增 `umami_script_url` / `umami_website_id` 两个设置项与 `partials/analytics.html`，未配置站点 ID 时不输出任何脚本。
4. **验证能力**：`theme/verify/check-theme.sh` 增 `--search` / `--live2d` / `--analytics` 三段；`deploy/verify/static-check.sh` 增 `--analytics` 段；`theme/verify/preview-test.sh` 增 `--plugins`。

## 范围（Scope）

### 范围内（In Scope）

- 搜索入口模板、交互脚本、按钮样式与插件组件的 CSS 变量主题化。
- 看板娘在简洁模式下的隐藏规则、页脚底部安全间距、安装流程与端到端断言。
- umami 的可选编排叠加层、Caddy 反代、备份覆盖、主题统计脚本注入与两个设置项。
- 三套校验脚本的新分段；`deploy/README.md` 与 `theme/README.md` 的对应章节。

### 范围外（Out of Scope）

- **umami 站点注册与账号**：需要在 umami 控制台手工建站拿 website-id，写进文档而不脚本化（避免把账号凭据塞进验证脚本）。
- **看板娘的 AI 聊天与 Agent**：需要 `ai-foundation` 插件与模型凭据，FR 未要求，本变更只用默认看板娘。
- **live2d 模型托管**：模型接口由插件自带默认值，不引入自建模型 CDN。
- **插件升级**：`PluginSearchWidget` 1.7.1 → 1.8.0 属运维动作，只写文档提示。
- 真实统计数据的产出：需要线上流量，留到 M5 上线验收人工确认。

## 影响与验证

**影响区域**

- `deploy/`：`docker-compose.analytics.yml`（新增）、`caddy/Caddyfile`、`backup/backup.sh`、`.env.example`、`verify/static-check.sh`、`README.md`。
- `theme/`：`src/partials/layout.html`、`src/partials/analytics.html`（新增）、`src/js/search.ts`（新增）、`src/js/main.ts`、`src/css/pages.css`、`settings.yaml`、`verify/check-theme.sh`、`verify/preview-test.sh`、`README.md`。
- 运行期新增 `umami` 与 `umami_db` 容器（只在 analytics 叠加层里）。

**完成证明**

- `bash deploy/verify/static-check.sh --all`（含新增 `--analytics` 段）全部通过。
- `bash theme/verify/check-theme.sh --all`（含新增 `--search` / `--live2d` / `--analytics` 段）全部通过。
- `bash theme/verify/preview-test.sh --reset --plugins --keep` 在全新实例上全绿：搜索按钮渲染且 `SearchWidget` 全局存在、live2d 装上后 `plugin-live2d-config` 注入、其静态资源 200、简洁模式规则在位。
- 上述命令在 `workflow complete` 时作为唯一验证命令执行一次。
