# 设计说明

## 已知事实与约束

以下都是本轮实测（2026-10-18，Halo 2.27.0 本地实例 + 解包插件制品），不是推断：

1. **搜索插件随发行版自带**。`deploy/data/halo2/plugins/` 在全新实例上就有 `PluginSearchWidget-1.7.1.jar`、`PluginCommentWidget-3.3.2.jar`、`PluginFeed-1.5.0.jar`、`PluginSitemap-1.3.0.jar`、`shiki-1.5.1.jar`、`editor-hyperlink-card-1.9.2.jar`、`app-store-integration-1.19.0.jar`、`ai-foundation-1.1.0.jar`；而镜像内 `find / -name "*Plugin*.jar"` 为空，说明这些是 Halo 启动时从应用包内解压到工作目录的预设插件。
2. **搜索后端由该插件自己提供**。首页 HTML 自动注入 `<script src="/plugins/PluginSearchWidget/assets/static/search-widget.iife.js?version=1.7.1" defer>` 与对应样式；`POST /apis/api.halo.run/v1alpha1/indices/-/search`（JSON body：`keyword` / `limit` / `highlightPreTag` / `highlightPostTag`）返回 200 与命中，**不需要 Meilisearch 或任何外部索引服务**。
3. **插件前端契约**：`search-widget.iife.js` 内部 `fetch('/apis/api.halo.run/v1alpha1/indices/-/search', {method:'post'})`；主题只需调用全局 `SearchWidget.open()`。插件 README 声明它提供 `--halo-search-widget-*` 一组 CSS 变量用于主题配色。
4. **丢 JAR 不等于安装**。把 `plugin-live2d-2.2.0.jar` 放进 `deploy/data/halo2/plugins/` 并 `docker compose restart halo` 后：`/plugins/PluginLive2d/assets/static/live2d/live2d.js` 仍 404，`PluginReconciler` 日志里只有 `ai-foundation`、`PluginSearchWidget`、`app-store-integration`、`editor-hyperlink-card` 等既有插件，没有 `PluginLive2d`。安装必须走 Console 或 `plugin install` 接口（接口端点与状态码由任务 2.1 的探针确认）。
5. **live2d 前端靠服务端注入的配置节点启动**。`live2d.js`（2618 B 的加载器）先读 `document.getElementById('plugin-live2d-config')` 的 JSON（含 `assetPath`），缺失就抛 `Missing Halo Live2D config element.`；运行时把根节点渲染为 `#live2d-widget`（在 `chunks/runtime-*.js` 中出现该标识）。因此「装上了」的判据是页面含 `plugin-live2d-config`，而不是看截图。
6. **umami v3.4.0 只支持 PostgreSQL / MySQL**，官方 compose 是 `umami` + `postgres:15-alpine` 两容器，健康检查打 `/api/heartbeat`，变量为 `DATABASE_URL`、`APP_SECRET`、`TWO_FACTOR_ENCRYPTION_KEY`。
7. **PostgreSQL 数据目录必须用命名卷**：Windows 绑定挂载（DrvFs）不支持 `chmod`，容器会以 `initdb: error: could not change permissions of directory ... Operation not permitted` 无限重启（M0 已踩过）。umami 自带的库同样适用这条。
8. **`pluginFinder.available(name)` 可在模板里直接判断插件是否启用**，未安装/未启用时返回 false。

## 目标与非目标

**目标**

- 装了搜索插件时页头出现搜索入口，点击唤起插件自带的搜索框；没装时整块不渲染（不留死链）。
- 看板娘装上后，简洁模式能把它一起收掉，不遮挡页脚。
- 统计脚本由主题设置驱动：配了 website-id 才输出，且默认指向同源 `/umami/script.js`。

**非目标**

- 不自研搜索 UI（索引、高亮、键盘导航都由插件提供）。
- 不接管 live2d 的 DOM 与模型加载。
- 不把 umami 的建站流程自动化。

## 决策（Decisions）

### 决策：搜索入口只做触发按钮，搜索框交给插件

- **选择**：模板里按 `pluginFinder.available('PluginSearchWidget')` 条件渲染一个 `button.sg-search`，`theme/src/js/search.ts` 在 `window.SearchWidget` 存在时绑定 `SearchWidget.open()`，否则移除该按钮。
- **理由**：插件已经把脚本和样式注入每个页面，索引接口也由它提供，自研等于重复实现并额外维护一套高亮与键盘导航。
- **替代方案**：自己 `fetch` `/indices/-/search` 画列表。被否：要自己处理高亮标签转义、防抖、键盘导航与移动端全屏，收益为零。
- **后果**：主题对插件版本有软依赖；插件未启用时搜索入口消失（有守卫，不会 404）。

### 决策：看板娘只做 CSS 联动，不重写它的 DOM

- **选择**：在 `theme/src/css/pages.css` 写 `:root[data-motion="off"] #live2d-widget { display: none !important; }`，并给 `body` 补一段底部安全间距避免遮挡页脚链接。
- **理由**：`#live2d-widget` 是运行时根节点（实测存在于 `chunks/runtime-*.js`），用它做开关不需要与插件的 JS 生命周期纠缠。
- **替代方案**：改插件设置里的工具项或调用 `window.live2d` 的销毁 API。被否：会与插件的模型切换、TIPS 状态互相干扰，且接口未文档化。
- **后果**：插件若改根节点 id，规则失效；由 `check-theme.sh --live2d` 的静态断言与 `preview-test.sh --plugins` 的注入断言两面兜住。

### 决策：umami 用独立叠加层 + 独立 PostgreSQL 命名卷

- **选择**：新增 `deploy/docker-compose.analytics.yml`，内含 `umami`（`${UMAMI_IMAGE:-ghcr.io/umami-software/umami:3.4.0}`）与 `umami_db`（`postgres:15-alpine`，数据落命名卷 `sg-blog-umami-data`）。
- **理由**：umami 只支持 PG/MySQL；PG 在 Windows 绑定挂载上必然 initdb 失败，所以必须命名卷；独立叠加层让本地预览与不需要统计的部署完全不受影响。
- **替代方案**：① 复用 `halodb` 建第二个库——省一个容器，但要手工 `CREATE DATABASE`、备份改成两次 pg_dump、且 umami 的迁移与 Halo 抢同一个实例的连接池；② 不上 umami 用别的轻量统计——与 FR-8.2 冲突。
- **后果**：多两个容器（约 200 MB 内存）、备份多一条转储、`/umami/*` 在未部署叠加层时返回 502（Caddy 不会因此启动失败）。

### 决策：统计脚本由主题设置驱动，默认不输出

- **选择**：`settings.yaml` 新增 `umami_script_url`（默认 `/umami/script.js`）与 `umami_website_id`（默认空）；`partials/analytics.html` 仅在 `umami_website_id` 非空时输出 `<script defer data-website-id src>`。
- **理由**：website-id 是每个站点唯一的，不能写默认值；没配就发请求只会给线上添无用的 4xx。
- **替代方案**：用 Halo 的「代码注入」功能贴脚本。被否：绕过主题配置，换主题即失效，且无法在模板层做守卫。
- **后果**：建站与填 ID 是文档里的一步人工动作。

### 决策：插件安装只走 Console / 安装接口，文档明写「丢 JAR 不生效」

- **选择**：`deploy/README.md` 与 `theme/README.md` 记录实测结论；`preview-test.sh --plugins` 用安装接口自动装 live2d，探针失败则降级为「跳过该步并打印手工步骤」，其余断言照常。
- **理由**：直接放文件不生效（实测），把这条写进文档能省掉后来者一半的排查时间。
- **替代方案**：把插件 JAR 提交进仓库并挂载。被否：二进制入库、版本升级变成提交记录，且仍然要通过安装接口注册 Plugin 资源。
- **后果**：全新环境装插件需要联网下载 JAR（约 1.66 MB）。

## 风险与验证

| 风险 | 触发条件 | 应对 |
| --- | --- | --- |
| R1 ghcr.io 拉取慢或不可达 | 部署 analytics 叠加层时 | `UMAMI_IMAGE` 可换成任意可达镜像源；文档给替代命令 |
| R2 插件安装接口端点未确认 | 任务 2.1 探针 | 探针先跑；失败则 `--plugins` 降级为跳过并打印手工步骤，静态断言仍生效 |
| R3 2C2G 内存吃紧 | Halo + PG + Artalk + Caddy + umami + PG 全开 | 文档给内存预算；不需要统计就不启用叠加层 |
| R4 搜索组件视觉与主题不完全一致 | 插件样式写死 | 只用 `--halo-search-widget-*` 变量对齐字号与主色，不追求像素级一致 |
| R5 live2d 模型接口在境内可能慢 | 首次加载模型 | 文档说明可在插件设置里换模型接口地址 |

验证方式：`deploy/verify/static-check.sh --all`、`theme/verify/check-theme.sh --all`（含三段新增）、`theme/verify/preview-test.sh --reset --plugins --keep`；视觉一致性仍靠人工走查清单（无浏览器自动化）。

## 实施期新增的事实（实测）

- **插件启停端点是 `/start` 与 `/stop`，不是单独的管理接口**：`PUT /apis/api.console.halo.run/v1alpha1/plugins/{name}/start` 直接 404；可用的是 `PUT .../plugins/{name}/plugin-state` 之类之外的状态切换要按 Halo 源码的 `PluginConsoleController` 走。安装走 `POST .../plugins/install`（multipart），启用/停用走 plugin-state 相关端点 —— 本次用的组合已写进 `preview-test.sh` 的 `--plugins` 步骤。
- **往 `plugins/` 目录里丢 JAR 不会安装插件**：Halo 只从自己的扩展目录（DB 记录 + 解包产物）加载；`PluginReconciler` 的日志里不会出现它，`/plugins/PluginLive2d/...` 也 404。必须走安装接口或 Console。
- **搜索插件是发行版预设**：全新实例的 `deploy/data/halo2/plugins/` 里已经有 `PluginSearchWidget-1.7.1.jar`，且首页 HTML 会自动注入 `/plugins/PluginSearchWidget/assets/static/search-widget.iife.js`。主题的入口守卫 `pluginFinder.available(...)` 因此在新站点上默认为真。
- **搜索索引不需要外部引擎**：`POST /apis/api.halo.run/v1alpha1/indices/-/search` 装完插件即返回 200（`hits` 里带 `<mark>` 高亮），不用 Meilisearch。
- **umami 的 `BASE_PATH` 决定了反代要不要剥前缀**：容器以 `BASE_PATH=/umami` 启动时资源路径自带 `/umami`，Caddy 必须用 `handle /umami*` 原样透传；`/artalk` 相反（Artalk 用相对资源）所以要 `handle_path` 剥前缀。
- **本机无法自动启动 umami 叠加层**：启动命令里出现 `deploy/.env` 会被安全守卫拦下（`secret.basename.env`），因此统计的运行时验证只能留到线上首次部署时人工执行一次；静态校验（合并渲染、变量、健康检查、命名卷、反代规则）仍是全绿。

