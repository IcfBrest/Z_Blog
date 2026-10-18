# 设计：评论接入与 SEO 元信息

## 已知事实与约束

- **Halo 2.27 自带 SEO 出口，实测可用**：`GET /sitemap.xml` 200、`GET /rss.xml` 200（由内置 `plugin-feed` 提供，条目里会带 1px 遥测 gif）、`GET /robots.txt` 200；`/feed`、`/atom.xml`、`/sitemap_index.xml` 均 404。也就是说 FR-8.2/8.4 的服务端产出已经存在，缺的是主题侧的元信息与入口。
- **Halo 内置评论只输出占位**：`post.html` / `page.html` 当前写的是 `<halo:comment group="content.halo.run" kind="Post|SinglePage" name=...>`，没有安装评论组件插件时渲染为空。
- **Artalk 2.10.0 可运行且接口已探明**（本机实测，`docker run` 一次性容器）：端口 `23366`；`GET /dist/Artalk.js` 200、`GET /dist/Artalk.css` 200、`GET /api/v2/conf` 200（返回 `frontend_conf`，含 `locale`、`darkMode`、`gravatar`、`emoticons` 等）、`GET /` 302、`/admin/` 404；`docker.io/artalk/artalk-go:2.10.0` 摘要 `sha256:ed51450f3ed744780efd0d796f1ea033063bb11543973439b9c57ed32ac9b78f`。
- **Artalk 的类名前缀是 `.atk-`**，实测存在且可直接用于样式覆盖：`.atk-comment`、`.atk-comment-wrap`、`.atk-comment-children`、`.atk-comment-count`、`.atk-avatar`、`.atk-badge`、`.atk-badge-wrap`、`.atk-content`、`.atk-body`、`.atk-actions`、`.atk-dark-mode`、`.atk-btn`、`.atk-dropdown` 等。
- **主题的 head 只能通过 slot 追加内容**：`layout.html` 的 `head` 里有 `<slot name="head">`，每个路由模板已经用它设置 `<title>`。include 是构建期文本替换，被包含的骨架用 `<slot>`/`<slot name="...">` 接收内容（M1 的结论）。
- **`theme.config` 按设置分组嵌套**：`theme.config.<group>.<name>`。现有分组是 `basic` 与 `interaction`（M3a 修正过误用 `basic` 的缺陷）。
- **`theme/src/css/main.css` 通过 `@import` 汇总**（`tokens.css`、`fonts.css`、`pages.css`），新增样式文件沿用同一模式即可被 Vite 打包。
- **备份脚本只打包 `deploy/data/halo2`**：`deploy/backup/backup.sh` 的附件步骤是 `tar -czf ... -C deploy/data halo2`，加入 Artalk 后它的 SQLite 数据库在 `deploy/data/artalk/` 下，不在现有备份范围内。
- **`deploy/verify/static-check.sh` 的 `--vars` 断言要求 `.env.example` 覆盖编排里引用的全部变量**，因此新增 `${ARTALK_*}` 必须同步出现在模板里。

### 实施期新增的事实（实测）

- **Artalk 前端只有站点名，没有 siteKey**：2.10.0 的 `dist/Artalk.js` 里 `siteKey` 出现 **0 次**，`pageKey` 出现 22 次，配置对象是 `{el, pageKey, pageTitle, server, site, ...}`。因此不提供 `comments_site_key` 设置项（写了也不生效），改为要求 `comments_site_name` 与 Artalk 后台站点名一致。
- **Artalk 容器的配置生成方式**：镜像 `ENTRYPOINT` 是 `/entrypoint.sh`，`/data` 下没有 `artalk.yml` 时会先 `artalk gen conf`；环境变量 `ATK_DB_FILE`、`ATK_SITE_DEFAULT`、`ATK_SITE_URL`、`ATK_LOCALE` 均生效（实测 `/data/artalk.db` 159744 B）。镜像内只有 `wget`，健康检查因此用 `wget -q -O /dev/null http://127.0.0.1:23366/api/v2/conf`。
- **Artalk 的 SPA 用相对路径资源**：`/` 302 到 `./sidebar/`，页面引用 `./assets/index-*.js`；因此 Caddy 必须用 `handle_path /artalk/*`（剥前缀）而不是 `handle`，否则 `/artalk/sidebar/assets/...` 会变成 `/artalk/assets/...` 而 404。实测 `/sidebar/assets/...` 200、`/assets/...` 404。
- **评论是否渲染还受内容自身开关约束**：`haloCommentEnabled` 为 false 时模板走「评论已关闭」。预览脚本造的独立页面一开始写成 `allowComment: false`，导致 `/about` 没有评论区 —— 造数据时独立页面必须 `allowComment: true`。
- **注释里的字面量标签会进构建产物**：`comments.html` 头部的 HTML 注释里写了 `<halo:comment>`，include 是构建期文本替换，注释被原样带进产物，直接把「构建产物不含 Halo 原生评论标签」的断言打红。注释里不要写真实标签名。
- **`site.url` 在本地预览实例上是空的**：`meta.html` 里 `th:if` 依赖它拼绝对地址，实测两个标签都不输出（页面正常、无异常）。这说明 `site` 是 Map 语义（缺键为 null，不会抛 SpEL 异常），也确认 canonical 需要先在 Console 配站点地址。

## 目标与非目标

**目标**：读者能在文章与页面下看到贴合 SG 视觉的评论区；分享链接能出卡片；站点的 RSS/sitemap/robots 对读者与爬虫可达；评论数据进入既有备份链路。

**非目标**：搜索、看板娘、统计（M4b）；站长平台收录提交（需真实域名，M5）；评论区视觉的像素级校对（无浏览器自动化）。

## 决策（Decisions）

### 决策：评论用自托管 Artalk 独立容器，主题以设置项切换 provider

**选择**：`deploy/docker-compose.yml` 追加 `artalk` 服务（`artalk/artalk-go:2.10.0`，SQLite 绑定挂载到 `deploy/data/artalk/`，本地映射 `127.0.0.1:23366:23366`）；主题新增 `comment_provider`（`artalk` 默认 / `halo` 回退）与 `artalk_server`、`artalk_site` 三个设置项。

**理由**：FR-3 指定 Artalk；独立容器不侵入 Halo 的数据模型，评论数据自带 SQLite，备份只要多打一个目录；provider 开关让"不想跑 Artalk"的人仍能用回 Halo 内置评论，模板不必分叉。

**替代方案**：① Waline（3.x 需独立数据库，比 Artalk 多一个依赖）；② giscus（必须 GitHub 公开仓库，留言变成 issue，且要求访客登录）；③ 装 Halo 评论插件（生态与维护情况不明，且样式改造点更多）。

**后果**：多一个常驻容器与一份运行期数据；`backup.sh` 必须扩到 `deploy/data/artalk`；`.env.example` 与 `static-check.sh --vars` 要同步新增变量；本地预览时评论脚本的默认地址 `/artalk` 并不成立（那是 Caddy 后面的路径），需在文档里写明本地改成 `http://localhost:23366`。

### 决策：RINE 气泡样式以容器实际输出的类名为依据，不猜选择器

**选择**：先跑一次性容器抓 `/dist/Artalk.css` 与真实 DOM 结构，把用到的 `.atk-*` 选择器连同来源写进 `theme/src/css/comments.css` 的注释，再写样式。

**理由**：M1/M2 已经证明"猜类名"会静默失效（`th:fragment` 与 `__` 预处理两次都是构建通过、运行时才炸）。Artalk 的 DOM 不在我们控制内，只能以它输出的类名为准。

**替代方案**：用 Artalk 的主题变量（`--atk-*`）做有限定制——表达力不足，做不出"左右气泡 + 站长高亮"。

**后果**：样式与 Artalk 版本弱耦合，升级 2.x 可能改类名，需要在 `check-theme.sh --integrations` 里保留"关键选择器存在"的断言作为回归信号。

### 决策：SEO 元信息放在 `partials/meta.html`，由每个路由模板用 slot 覆盖

**选择**：`meta.html` 输出 `canonical`、`og:site_name`、`og:locale`、`twitter:card` 等公共项，并留一个 `<slot name="meta">` 让模板填标题/描述/类型/图片；10 个路由模板各自传入。

**理由**：`layout.html` 的 head 已经是 slot 机制，沿用同一套约定，模板之间不重复写公共标签；描述可以按"文章摘要 → 站点描述"回退。

**替代方案**：把 OG 写在 `layout.html` 里——拿不到每页标题与摘要（没有 `#request`，Halo 2.26+ 已移除）。

**后果**：每个路由模板多几行 `th:with` 参数；漏传时回退到站点级默认值，不会渲染出空标签。

### 决策：`sitemap` / `RSS` / `robots` 复用 Halo 内置，只做主题侧入口

**选择**：不装 feed/sitemap 插件，只校验三个端点 200，并在页脚加 RSS 与 sitemap 链接。

**理由**：Halo 2.27 实测三个端点都已可用；再装插件属于重复建设，还会与内置 `plugin-feed` 抢路径。

**替代方案**：装第三方 sitemap 插件——收益为零，风险是路径冲突。

**后果**：条目内容受内置插件约束（RSS 里会带遥测 gif），可接受。

### 决策：把搜索、看板娘与统计拆成 M4b

**选择**：本变更只做评论与 SEO；`plugin-search-widget`、`plugin-live2d`、umami 不在范围内。

**理由**：三者都需要外部制品（插件 JAR 下载安装、umami 的数据库与站点凭据），与本变更"容器 + 模板 + 静态校验"的闭环不同构，混在一起会让验证与回滚都变复杂。

**替代方案**：一次做完 M4——评审面太大，且插件安装失败会阻塞评论与 SEO 的交付。

**后果**：M4 变成两次交付；上线验收标准里"搜索/统计可用"延后到达。

## 风险与验证

| 编号 | 风险 | 应对 |
|------|------|------|
| R-1 | 本地预览里 `artalk_server` 默认 `/artalk` 只在 Caddy 后面成立，浏览器直接看会 404 | 文档写明本地改成 `http://localhost:23366`；端到端脚本只断言容器可达与页面含脚本标签，不断言浏览器加载成功 |
| R-2 | RINE 气泡的最终观感无浏览器自动化 | `check-theme.sh --integrations` 断言关键选择器与规则存在；观感走人工走查清单 |
| R-3 | Artalk 首次评论可能需要站点配置或审核策略，脚本不真实发评论 | 只探 `/api/v2/conf` 与静态资源；真实发评论留给人工，步骤写进 `deploy/README.md` |
| R-4 | Artalk 升级 2.x 改类名会让样式失效 | 断言关键选择器存在；`comments.css` 顶部记录抓取来源与版本 |
| R-5 | 备份漏掉 `deploy/data/artalk` 会造成评论丢失 | 把备份扩展写成独立任务并纳入 `--artalk` 静态断言 |

**验证方式**：`static-check.sh --all`（新增 `--artalk`）、`check-theme.sh --all`（新增 `--integrations`）、`preview-test.sh --reset --keep`（新增评论与 SEO 断言）三条命令全绿，再按 `theme/README.md` 的走查清单人工看一遍评论区。
