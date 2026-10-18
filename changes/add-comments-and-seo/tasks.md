# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
|------|----------|------|------|
| 1 | 评论后端随站点起停、生产反代就位、评论数据进备份、静态校验与手册覆盖 | 无 | `bash deploy/verify/static-check.sh --artalk` |
| 2 | Artalk 挂载点、按需加载脚本、RINE 频道样式 | 批次 1 | `bash theme/verify/check-theme.sh --integrations` |
| 3 | 每页分享元信息、订阅入口、端到端断言覆盖评论与 SEO | 批次 2 | `bash theme/verify/preview-test.sh --reset --integrations --seo --keep` |

## 任务

- [x] **1.1 起 Artalk 服务**：修改 `deploy/docker-compose.yml` 与 `deploy/.env.example`，新增 `artalk` 服务（镜像 `artalk/artalk-go:2.10.0`、SQLite 绑定挂载到 `./data/artalk`、本地映射 `127.0.0.1:23366:23366`、健康检查打 `/api/v2/conf`）并把 `ARTALK_IMAGE` / `ARTALK_SITE_NAME` / `ARTALK_SERVER_PORT` 写进变量模板，起站后评论后端与 Halo 一并就绪；证明：`docker compose -f deploy/docker-compose.yml config -q`。
- [x] **1.2 生产反代评论后端**：修改 `deploy/docker-compose.prod.yml` 与 `deploy/caddy/Caddyfile`，用 `handle_path /artalk/*` 把请求反代到 `artalk:23366` 并剥掉该前缀，同时让 caddy 依赖 artalk 健康，使线上评论接口与前端资源走同一域名；证明：`docker run --rm -e DOMAIN=blog.example.com -v "$PWD/deploy/caddy:/etc/caddy:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`。
- [x] **1.3 让备份覆盖评论数据**：修改 `deploy/backup/backup.sh`，用目录白名单把 `deploy/data/halo2` 与 `deploy/data/artalk` 打进同一个附件产物，使恢复时文章与评论一起还原，保留策略与产物命名不变；证明：`bash deploy/backup/backup.sh --dry-run`。
- [x] **1.4 给部署校验加评论段**：修改 `deploy/verify/static-check.sh` 新增 `--artalk`（断言编排含 artalk 服务与 23366 端口、`.env.example` 覆盖全部 `ARTALK_*` 变量、生产叠加层含 `/artalk` 路由、备份脚本引用 `artalk` 目录），使评论接入缺失时静态校验即失败；证明：`bash deploy/verify/static-check.sh --artalk`。
- [x] **1.5 补部署手册的评论章节**：修改 `deploy/README.md`，新增「评论（Artalk）」一节（本地端口与浏览器访问地址、线上反代与证书、初始管理员与站点配置、垃圾评论与审核策略、备份与恢复步骤），使运维不依赖源码即可启用评论；证明：`bash deploy/verify/static-check.sh --docs`。
- [x] **2.1 加评论相关设置项**：修改 `theme/settings.yaml`，新增 `integration` 分组（标签「集成」）与 `comments_enabled`（默认开）、`comments_server`（默认空，空则用同源 `/artalk`）、`comments_site_name`（默认空，空则用站点标题）三项，使 Console 里能控制评论开关、后端地址与站点名；证明：`bash theme/verify/check-theme.sh --components`。
- [x] **2.2 建评论组件与集成校验**：新建 `theme/src/partials/comments.html`（输出 `#sg-comments` 挂载点并把服务地址/站点名写进 `data-server`/`data-site`，受 `comments_enabled` 与 `haloCommentEnabled` 双重约束）与 `theme/src/js/comments.ts`（按需注入 `<server>/dist/Artalk.css` 与 `Artalk.js` 后 `Artalk.init`，失败降级为提示文案），并在 `theme/verify/check-theme.sh` 新增 `--integrations` 段断言该片段与加载逻辑；证明：`bash theme/verify/check-theme.sh --integrations`。
- [x] **2.3 把评论组件接到文章与页面**：修改 `theme/src/post.html` 与 `theme/src/page.html`，用 `<include src="comments.html" />` 替换原来的 `<halo:comment>` 块，使文章与独立页面都渲染同一套评论区；证明：`bash theme/verify/check-theme.sh --integrations`。
- [x] **2.4 写 RINE 聊天气泡样式**：新建 `theme/src/css/comments.css` 并在 `theme/src/css/main.css` 里 `@import`，用 Artalk 实际输出的 `.atk-*` 类名（2.10.0 实测）把评论区改成「RINE 频道」外观并跟随世界线主色，窄屏退化为单列；证明：`bash theme/verify/check-theme.sh --integrations`。
- [x] **2.5 补主题文档的评论章节**：修改 `theme/README.md`，新增「评论（Artalk）」一节（三项设置项、前端只有站点名没有 siteKey 的实测说明、挂载流程、三条排查），使后来者能自行启用与调样式；证明：`bash theme/verify/check-theme.sh --docs`。
- [x] **3.1 输出分享元信息**：新建 `theme/src/partials/meta.html` 并让 10 个路由模板的 `<template name="head">` 各自 include，输出 `description`、`og:*`、`twitter:*`，描述按「文章摘要 → 站点副标题」回退；`canonical` 与 `og:url` 仅在站点对外 URL 可用时输出（拼不出绝对地址就不输出），使每页都有正确的分享卡片；证明：`bash theme/verify/check-theme.sh --integrations`。
- [x] **3.2 加订阅与索引入口**：修改 `theme/src/partials/layout.html`，在 head 输出 `<link rel="alternate" type="application/rss+xml">` 并在页脚加 `/rss.xml` 与 `/sitemap.xml` 链接，使 RSS 能被浏览器与爬虫发现；证明：`bash theme/verify/check-theme.sh --integrations`。
- [x] **3.3 端到端覆盖评论与 SEO**：修改 `theme/verify/preview-test.sh`，新增 `--integrations` 与 `--seo` 两个开关：前者拉起 `artalk` 容器并断言后端可达、文章页与独立页面都挂载评论区、未配置服务地址时回退到同源 `/artalk`；后者断言文章页与首页的 OG/Twitter 元信息以及 `/rss.xml`、`/sitemap.xml` 均 200，使评论与 SEO 的退化能被端到端抓住；证明：`bash theme/verify/preview-test.sh --reset --integrations --seo --keep`。
- [x] **3.4 更新总览文档与体积预算**：修改根 `README.md`，把 M4 拆成 M4a 已完成与 M4b 待开始、更新目录树与文档索引、补已知限制（评论按站点名归属、canonical 依赖站点地址、`/artalk` 前缀未在真实域名下验过、M4b 未开始），并记录 M4a 的构建体积；证明：`bash theme/verify/check-theme.sh --docs`。

## 实施备注（仅在必要时）

- 线上 `comments_server` 用相对路径 `/artalk`（由 Caddy 的 `handle_path` 剥前缀后反代）；本地没有 Caddy，预览脚本只断言「未配置时回退到 `/artalk`」，浏览器手工验证时才在 Console 里填 `http://localhost:23366`。
- 备份产物沿用 `halo-attachments-<stamp>.tar.gz` 这个名字（只是把 `artalk` 目录一并打进去），保留策略靠文件名前缀匹配，改名会连带改清理逻辑。
- Artalk 的类名可能随 2.x 升级变化，`comments.css` 顶部必须记录抓取来源与版本，`--integrations` 保留关键选择器断言作为回归信号。
- 主题不提供 `siteKey` 设置项：实测 Artalk 2.10.0 的前端配置对象里只有 `site`（站点名），`dist/Artalk.js` 中 `siteKey` 出现 0 次。
