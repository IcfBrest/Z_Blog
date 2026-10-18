# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
| --- | --- | --- | --- |
| 1 | 装了搜索插件的站点页头出现搜索入口，点击唤起插件自带搜索框；未装时入口不渲染 | 无 | `bash theme/verify/check-theme.sh --search` |
| 2 | 看板娘可通过安装接口装上，并在简洁模式（`data-motion="off"`）下自动收起，不遮挡页脚 | 批次 1 | `bash theme/verify/preview-test.sh --reset --plugins --keep` |
| 3 | umami 统计可一键起停（独立叠加层），主题按 website-id 输出统计脚本，备份覆盖统计库 | 批次 1 | `bash deploy/verify/static-check.sh --analytics && bash theme/verify/check-theme.sh --analytics` |

## 任务

### 批次 1：搜索入口

- [x] **1.1 页头搜索入口**：修改 `theme/src/partials/layout.html`，在 `.sg-controls` 内插入 `button.sg-search[data-sg-search]`，用 `th:if="${pluginFinder.available('PluginSearchWidget')}"` 守卫；完成后装了插件的站点页头出现「搜索」按钮，未装时整块不渲染。
- [x] **1.2 搜索交互脚本**：新增 `theme/src/js/search.ts` 并在 `theme/src/js/main.ts` 里初始化，把 `[data-sg-search]` 绑到 `window.SearchWidget.open()`，全局缺失时移除入口；完成后点击按钮能唤起插件搜索框。
- [x] **1.3 搜索控件样式与组件配色**：修改 `theme/src/css/pages.css`，加 `.sg-search` 外观并把 `--halo-search-widget-*` 变量映射到主题语义色；完成后按钮与其它图标控件同高，组件主色跟随世界线。
- [x] **1.4 搜索检查段**：修改 `theme/verify/check-theme.sh` 新增 `--search` 段（模板守卫、`SearchWidget.open`、CSS 变量、构建产物含 `sg-search`），并纳入 `--all`；完成后 `--search` 单独可跑。
- [x] **1.5 搜索文档**：修改 `theme/README.md` 增「搜索」章节（预设插件说明、入口守卫、样式变量表）；完成后文档与实现一致。

### 批次 2：看板娘

- [x] **2.1 插件安装步骤**：修改 `theme/verify/preview-test.sh` 新增 `--plugins` 步骤（下载 `plugin-live2d-2.2.0.jar` → 插件安装接口 → 启用 → 断言 `plugin-live2d-config` 注入与其静态资源 200），探针失败时跳过该步并打印手工步骤；完成后端到端能证明看板娘真的挂上。
- [x] **2.2 简洁模式联动样式**：修改 `theme/src/css/pages.css`，加 `:root[data-motion="off"] #live2d-widget { display: none !important; }` 与 `body` 底部安全间距；完成后简洁模式下看板娘收起且页脚不被遮挡。
- [x] **2.3 看板娘检查段**：修改 `theme/verify/check-theme.sh` 新增 `--plugins` 段（两条 CSS 规则、不依赖插件内部类名、纳入 `--all`）；完成后 `--plugins` 单独可跑。
- [x] **2.4 插件安装文档**：修改 `deploy/README.md` 与 `theme/README.md`，记录「丢 JAR 不生效、必须走安装接口」的实测结论与安装步骤；完成后文档给出可直接照做的命令。

### 批次 3：umami 统计

- [x] **3.1 统计编排叠加层**：新建 `deploy/docker-compose.analytics.yml`（`umami` + `umami-db`，数据落命名卷 `sg-blog-umami-data`，健康检查打 `/api/heartbeat`）；完成后叠加层可与基础编排合并渲染。
- [x] **3.2 统计变量与反代**：修改 `deploy/.env.example`（`UMAMI_IMAGE` / `UMAMI_DB_IMAGE` / `UMAMI_DB_PASSWORD` / `UMAMI_APP_SECRET` / `UMAMI_TWO_FACTOR_KEY` / `UMAMI_PORT`）与 `deploy/caddy/Caddyfile`（`handle /umami*` 反代到 `umami:3000`，**不剥前缀**）；完成后变量齐全、`caddy validate` 通过。
- [x] **3.3 备份覆盖 umami 库**：修改 `deploy/backup/backup.sh`，在 Halo 库转储之外增加 umami 库转储（仅当 `umami-db` 在运行）并纳入保留策略；完成后 `--dry-run` 会说明统计库转储的条件与目标文件名。
- [x] **3.4 主题统计组件**：修改 `theme/settings.yaml` 增 `umami_script_url`（默认 `/umami/script.js`）与 `umami_website_id`（默认空），新建 `theme/src/partials/analytics.html` 并在 `layout.html` include；完成后未配 ID 时不输出任何脚本。
- [x] **3.5 两套检查脚本分段**：修改 `deploy/verify/static-check.sh` 增 `--analytics`、`theme/verify/check-theme.sh` 增 `--analytics`（含 `--all` 纳入与零值串位数、`usage()` 的 sed 范围同步），完成后两段各自可跑。
- [x] **3.6 统计文档**：修改 `deploy/README.md`（变量表、建站与填 ID、内存预算、停用步骤、`/umami` 不剥前缀的原因）与 `theme/README.md`（统计章节与排查表）；完成后两份手册能照着把统计跑起来。

## 实施备注（仅在必要时）

- 搜索插件是发行版预设（`PluginSearchWidget-1.7.1.jar` 在全新实例上就有），批次 1 不需要安装动作；批次 2 的 live2d 才需要安装接口。
- 看板娘的根节点是 `#live2d-widget`，判据是页面含 `plugin-live2d-config`；两者都来自插件制品实测。
- umami 的数据库必须是命名卷（Windows 绑定挂载会让 initdb 因 chmod 失败而无限重启）。
- 两个校验脚本的 `--all` 零值串位数与 `usage()` 的 `sed` 范围是硬编码，新增分段时必须同步，否则 `--all` 会静默漏跑。
- 与初版计划的偏离（均已在上文措辞中订正）：
  - 3.1 服务名用 `umami-db`（连字符），不是 `umami_db`。
  - 3.2 反代用 `handle /umami*` 且**不剥前缀** —— umami 自己配了 `BASE_PATH=/umami`，资源路径本身带 `/umami`，剥掉会 404（`/artalk` 才需要 `handle_path`）。
  - 3.3 统计库转储是条件性的（未启用叠加层时不产生 `umami-db-*.sql.gz`），因此 dry-run 只说明条件，不会真的打印第二条 `pg_dump`。
  - 3.6 原计划含「preview-test 新增 `--analytics` 步骤起叠加层并断言」，本次改为只交付文档 + 两套静态校验：本机启动 umami 叠加层的命令被安全守卫拦下（`secret.basename.env`），未绕过，故运行时验证留作线上首次部署时的手工步骤。
