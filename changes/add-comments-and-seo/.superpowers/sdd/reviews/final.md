# 代码审查：M4a 评论接入与 SEO 元信息

- 变更：`add-comments-and-seo`
- 范围：`03b5917d5964d4bdc537b686782f81c8ad49adf2`..`b9774f3638ef7a7ce335193672aeefc54f098408`（实现提交 `b3ef608`、规格发布 `a9f7880`、回执提交 `b9774f3`）
- 策略：Native `final`（计划 `reviews[0].review_policy = final`），由执行者本地审查整段 diff，未派审查子代理
- 计划版本：revision 2，artifacts hash `sha256:1984bff18a738048aa751b9be54adb012cb134b5b8abd19f9757a81fdb64f4ad`
- 判定：**pass**

## 逐任务核对

| 任务 | 交付物 | 核对结果 |
|---|---|---|
| 1.1 | `deploy/docker-compose.yml` 的 `artalk` 服务、`.env.example` 三个 `ARTALK_*` | 服务含镜像 `${ARTALK_IMAGE:-artalk/artalk-go:2.10.0}`、`ATK_*` 环境变量、`127.0.0.1:${ARTALK_SERVER_PORT:-23366}:23366`、卷 `./data/artalk:/data`、healthcheck 打 `/api/v2/conf`；`docker compose config -q` 通过 |
| 1.2 | `docker-compose.prod.yml`、`caddy/Caddyfile` | caddy `depends_on` 增加 `artalk: condition: service_healthy`；Caddyfile 用 `route { handle_path /artalk/* { reverse_proxy artalk:23366 } ; reverse_proxy halo:8090 }`；`caddy validate` 输出 `Valid configuration`，`caddy adapt` 确认 `strip_path_prefix: /artalk` |
| 1.3 | `deploy/backup/backup.sh` | 目录白名单循环只打包存在的目录（实测 `halo2` 有、`artalk` 无时不报错）；`--dry-run` exit 0 |
| 1.4 | `deploy/verify/static-check.sh --artalk` | 新增 `check_artalk()` 9 条断言（服务、镜像、端口、卷、healthcheck、变量、prod 依赖、Caddy 路由、备份引用）；`--artalk` 16/0，`--all` 38/0 |
| 1.5 | `deploy/README.md` | 新增「评论（Artalk）」一节；`--docs --artalk` 23/0 |
| 2.1 | `theme/settings.yaml` | 新增 `integration` 分组与 `comments_enabled` / `comments_server` / `comments_site_name`；`--components` 通过 |
| 2.2 | `partials/comments.html`、`js/comments.ts`、`check-theme.sh --integrations` | 挂载点输出 `data-server`/`data-site`；脚本按需加载 `dist/Artalk.css` 与 `Artalk.js` 后 `Artalk.init`，失败降级只改文案；`--integrations` 15/0 |
| 2.3 | `post.html`、`page.html` | 原 `<halo:comment>` 块替换为 `<include src="comments.html" />`，构建产物不含原生评论标签（断言覆盖） |
| 2.4 | `css/comments.css` + `main.css` 的 `@import` | 用 2.10.0 实测的 `.atk-*` 类名覆盖，样式全部走语义 token；`--integrations` 断言挂载点样式、RINE 标识与 ≥4 个 `.atk-*` 覆盖 |
| 2.5 | `theme/README.md`「评论（Artalk）」 | 含设置项表、无 siteKey 的实测说明、挂载流程、三条排查；`--docs` 11/0 |
| 3.1 | `partials/meta.html` + 10 个路由模板 include | 输出 `description`/`og:*`/`twitter:*`；`canonical` 与 `og:url` 由 `th:if` 守着，站点 URL 不可用时不输出；`--integrations` 断言全部模板都带三项元信息 |
| 3.2 | `partials/layout.html` head + 页脚 | head 输出 `rel="alternate"` RSS；页脚新增「RSS 订阅」「站点地图」两个链接（`main.css` 配套样式） |
| 3.3 | `theme/verify/preview-test.sh` | 新增 `--integrations`（拉起 artalk、断言后端资源 200、文章与页面都挂载、回退 `/artalk`）与 `--seo`（OG/Twitter、`/rss.xml`、`/sitemap.xml`）；`--reset --integrations --seo --keep` → 56/0 |
| 3.4 | 根 `README.md` | M4 拆成 M4a ✅ / M4b ⏳、目录树与文档索引更新、四条新已知限制、构建体积已入 theme README |

## 验证证据

```
bash deploy/verify/static-check.sh --all        → 通过 38 项，失败 0 项
bash theme/verify/check-theme.sh --all          → 通过 83 项，失败 0 项
node theme/verify/unit-logic.mjs                → 通过 29 项，失败 0 项
bash theme/verify/preview-test.sh --reset --integrations --seo --keep
                                                → 通过 56 项，失败 0 项
```

构建产物：`dist/z-blog-sg-1.4.0.zip` 5.52 MB；`main-*.js` 8,648 B（gzip 3,370 B）；`main-*.css` 155,915 B（gzip 63,196 B）。

## 发现的缺陷（已在本次修复）

- **I-1（Important，实现期修复）**：预览脚本造的独立页面写了 `allowComment: false`，`haloCommentEnabled` 为假导致 `/about` 走「评论已关闭」分支，端到端首次是 50 通过 2 失败。修复：造数据用 `allowComment: true`。证据：修前 `50/2`，修后 `52/0`（当时尚未加 `--seo`）。
- **I-2（Important，实现期修复）**：`comments.html` 头部注释里写了字面量 `<halo:comment>`，include 是构建期文本替换，注释被原样带进产物，`--integrations` 的「产物不含原生评论标签」断言直接变红。修复：注释不再写真实标签名。证据：修前 14/1，修后 15/0。

## 未修复的次要项（记录，不阻塞）

- **M-1**：`loadScript` 对「已注入但加载失败」的脚本会再挂监听器并永挂不 resolve；当前 `initComments()` 每次页面加载只调用一次，触发条件不成立。
- **M-2**：失败态只写 `data-sg-failed="1"` 与改文案，`comments.css` 没有为这个属性写样式（视觉上只体现为提示语变化）。
- **M-3**：`check_artalk` 断言 `published: "23366"` 依赖 `docker compose config` 的长语法渲染，compose 大版本升级可能需要跟着改（与既有端口断言同一类风险）。
- **M-4**：`comments.css` 覆盖的 `.atk-*` 类名绑定 Artalk 2.10.0；升级 Artalk 需复核，已在 design.md 与 theme README 记录。
- **M-5**：任务 3.3 原文提到 `/robots.txt`，实测 200 但未纳入脚本断言（`/rss.xml`、`/sitemap.xml` 已覆盖）。

## 剩余风险

- **R-1 视觉未自动化**：RINE 气泡的观感、暗色对比度、窄屏单列退化仍需人工走查（清单见 `theme/README.md`）。
- **R-2 CI 未在 GitHub Actions 实跑**：本地用与 CI 相同命令验证通过。
- **R-3 `/artalk` 前缀反代未在真实域名下验过**：`caddy validate`/`adapt` 确认规则正确，首次线上部署需确认评论接口可达。
- **R-4 `canonical` / `og:url` 本地不可见**：`site.url` 在本机预览实例上为空，两个标签按设计不输出；配置站点地址后才会出现，无法在本地断言其取值正确。

## 判定

14 个任务全部有对应交付物与可复现的证明命令，四套校验全绿；两处实现期缺陷已修复并留下负向验证记录；剩余问题均为观感或环境依赖，不构成合并阻塞。**pass**。
