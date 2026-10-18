# 变更提案

## 背景（Why）

M0–M3a 之后站点已经能渲染全部页面并具备 SG 视觉语言，但缺三样让博客"活起来"的东西，且都是访客能立刻察觉的缺口：

1. **没有评论**。`post.html` 与 `page.html` 目前只输出 `<halo:comment>` 占位，Halo 内置评论需要额外安装评论组件插件才有后端，空站点上等于一片空白。FR-3 要求的是 Artalk + RINE 聊天气泡样式，这套视觉目前完全不存在。
2. **没有分享卡片与订阅入口**。全站 `<head>` 只有标题与样式，没有 canonical、Open Graph、Twitter Card；页面上也没有 RSS 链接。别人把文章链接贴到聊天软件或社交平台，只会得到一行裸链接（FR-8.3/8.4）。Halo 2.27 实测已原生提供 `/sitemap.xml`、`/rss.xml`、`/robots.txt`（均 200），但主题没有把它们暴露给读者与爬虫。
3. **评论与 SEO 都是"上线验收标准"里的硬条件**（需求文档 §8 第 3、8 条），拖到 M5 再做会让"打磨期"同时承担集成风险。

同时，M4 的另外三项（搜索插件、看板娘插件、umami 统计）都依赖从外部下载 Halo 插件 JAR 或额外常驻服务与账号凭据，与本变更"容器 + 模板 + 静态可验证"的闭环不同构，因此拆到 M4b 单独立项（见"范围外"）。

## 变更内容（What Changes）

1. **Artalk 评论服务**：`deploy/docker-compose.yml` 追加 `artalk` 服务（`artalk/artalk-go:2.10.0`，SQLite 落在绑定挂载的 `deploy/data/artalk/`），`.env.example` 补齐它的镜像与站点级变量，生产叠加层给 Caddy 加 `/artalk/*` 反代。
2. **主题评论组件**：新增两个设置项（`comment_provider` 默认 `artalk`、`artalk_server` 默认 `/artalk`），`post.html` / `page.html` 在 `artalk` 模式下渲染 Artalk 容器与脚本，`halo` 模式保留原来的 `<halo:comment>` 作为回退。
3. **RINE 聊天气泡样式**：新增 `theme/src/css/comments.css`，把 Artalk 输出的评论列表改造成左右气泡（访客左、站长右并高亮）、把时间戳改成 D-Mail 接收文案。选择器以 Artalk 容器实际输出的类名为准——先用探针抓 `dist/Artalk.css` 与真实 DOM 结构，再写样式，不猜。
4. **SEO 元信息**：新增 `theme/src/partials/meta.html`，输出 canonical、`og:*`、`twitter:*` 与 description，10 个路由模板各自提供标题/描述/类型；页脚补 RSS 与 sitemap 链接。
5. **验证能力**：`deploy/verify/static-check.sh` 增 `--artalk` 段；`theme/verify/check-theme.sh` 增 `--integrations` 段；`theme/verify/preview-test.sh` 扩充为「起站 → 初始化 → 造数据 → 装主题 → 路由 → 页面结构 → 评论与 SEO」。

## 范围（Scope）

### 范围内（In Scope）

- `artalk` 服务进基础编排 + 生产叠加层反代 + `.env.example` 变量 + 数据目录纳入 `.gitignore`（已覆盖 `deploy/data/`）。
- 主题侧评论容器、脚本加载、provider 回退开关、RINE 气泡样式与时间文案。
- 主题侧 canonical / Open Graph / Twitter Card / description。
- 页脚 RSS 与 sitemap 入口；`/rss.xml`、`/sitemap.xml`、`/robots.txt` 可用性断言。
- 三套校验脚本的新分段与端到端断言、`theme/README.md` 与根 `README.md` 的对应章节。

### 范围外（Out of Scope）

- **搜索插件（plugin-search-widget）与看板娘（plugin-live2d）**：需要下载并安装 Halo 插件 JAR，live2d 还依赖外部模型 CDN，留到 M4b。
- **umami 统计**：需要独立数据库、站点注册与账号凭据，且真实数据要等线上部署后才产生，留到 M4b。
- **站长平台收录提交**（百度/必应）：需要真实域名与备案，属 M5/上线阶段的人工动作；本变更只保证 sitemap 与 RSS 产出正确。
- Artalk 的管理员账号初始化、评论审核策略配置：属运维动作，写进文档而不脚本化（避免把管理员凭据塞进验证脚本）。
- 评论区的真实视觉微调：无浏览器自动化，样式正确性靠选择器与 DOM 结构断言 + 人工走查。

## 影响与验证

**影响区域**

- `deploy/`：`docker-compose.yml`、`docker-compose.prod.yml`、`caddy/Caddyfile`、`.env.example`、`verify/static-check.sh`、`README.md`。
- `theme/`：`settings.yaml`、`src/partials/meta.html`（新增）、`src/partials/comments.html`（新增）、`src/css/comments.css`（新增）、`src/post.html`、`src/page.html`、`src/partials/layout.html`、10 个路由模板的 head、`verify/check-theme.sh`、`verify/preview-test.sh`、`README.md`。
- 运行期新增 `deploy/data/artalk/`（SQLite 数据库，已被 `.gitignore` 覆盖）。

**完成证明**

- `bash deploy/verify/static-check.sh --all`（含新增 `--artalk` 段）全部通过。
- `bash theme/verify/check-theme.sh --all`（含新增 `--integrations` 段）全部通过。
- `bash theme/verify/preview-test.sh --reset --keep` 在全新实例上全绿：Artalk 容器健康、`/artalk/` 可达、文章页含评论容器与脚本、首页与文章页输出 canonical/OG/Twitter、`/rss.xml` 与 `/sitemap.xml` 与 `/robots.txt` 均 200。
- 上述命令在 `workflow complete` 时作为唯一验证命令执行一次。
