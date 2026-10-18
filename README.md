# Z_Blog · 命运石之门主题个人博客

> 「未来并不是注定不变的。所以，才要向前看。」

一个以《命运石之门》（Steins;Gate）为视觉主题的个人博客：辉光管 **Divergence Meter**、**α / β 双世界线**主题切换、CRT 终端质感的文章容器，底层是 **Halo + PostgreSQL + Caddy** 的全容器化部署。

内容以**技术笔记、生活记录与随想**为主；所有视觉元素都是原创的 SVG / CSS 致敬，不使用官方素材。

---

## 当前状态

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| **M0** | 环境与部署底座（Halo + PostgreSQL + Caddy + Docker Compose、备份脚本、运维手册） | ✅ **已完成** |
| **M1** | 主题骨架（theme-starter 工程、配色 tokens、基础布局、字体自托管） | ✅ **已完成** |
| **M2** | 核心组件（Divergence Meter、CRT 动效、双主题切换、简洁模式） | ✅ **已完成** |
| **M3a** | 页面铺开（首页世界线横幅、文章详情 CRT 终端 + D-Mail 元信息、归档时间轴、分类分支徽章、关于页成员卡、友链卡片、404 终端） | ✅ **已完成** |
| M3b | D-Mail 密码解锁（Halo 2.27 的 `PostSpec` 没有密码字段，需先定方案） | ⏳ 待开始 |
| **M4a** | 评论与 SEO（Artalk 评论后端 + RINE 频道样式、OG/Twitter 元信息、页脚 RSS 与站点地图入口） | ✅ **已完成** |
| **M4b** | 搜索入口（`plugin-search-widget` 与主题 `/` 快捷键）、看板娘（CSS 联动 + 可插拔插件安装）、umami 统计（独立可选叠加层 + 主题统计组件） | ✅ **已完成** |
| M5 | 打磨与发布（性能优化、恢复演练、首发文章） | ⏳ 待开始 |

> 主题 `z-blog-sg` 已能安装并渲染全部路由，M2 的交互层也已就位：世界线 α/β 双主题切换、Divergence Meter 辉光管（默认 `1.048596`，可切真实文章数）、CRT 扫描线/粒子/鼠标辉光/打字机、以及一键「简洁模式」。
>
> 动效默认开启，但遵循 `prefers-reduced-motion`；所有开关记在 localStorage（`sg-worldline` / `sg-motion`），Console 里另有八项设置（五项动效默认值 + 站长称呼 + 关于页 / 友链页的 slug）。浏览器端的视觉效果仍需人工走查确认（见 [theme/README.md](theme/README.md) 的走查清单）。
>
> M3a 把这套视觉语言铺到了每一类页面上：首页有按分类驱动的世界线 SVG 横幅，文章详情是带局部扫描线的 CRT 终端并附带「D-Mail 发送记录」元信息，归档换成竖向时间轴，分类总览渲染成带篇数的分支徽章，关于页给出「未来道具研究所」成员卡，友链页把正文列表变成卡片网格，404 是 CRT 错误终端加「未找到该世界线」。预览脚本现在会自己造分类、文章与页面，因此这些形态都能被端到端断言覆盖。
>
> M4a 接上了评论与 SEO：文章与独立页面下方是 **Artalk** 评论后端（Go + SQLite，独立容器），外观做成「RINE 频道」，样式跟随世界线主色；每个页面输出 OG / Twitter 卡片元信息，页脚固定给出 `/rss.xml` 与 `/sitemap.xml` 两个订阅入口。评论前端不在主题包里，而是按需加载评论后端自己托管的 `dist/Artalk.js`，所以升级评论后端不需要重新发版主题。

## 技术栈

| 层次 | 选型 | 说明 |
|------|------|------|
| 博客应用 | **Halo 2.27.0**（Java / Spring Boot） | 动态博客，插件与主题生态完整，支持密码文章 |
| 数据库 | **PostgreSQL 15** | 运行在**命名卷** `sg-blog-halodb-data`（Windows 绑定挂载会导致 `initdb` 权限失败） |
| 反向代理 | **Caddy 2** | 四行配置拿到自动 HTTPS 证书与续期，比 Nginx + certbot 少一个常驻进程 |
| 编排 | **Docker Compose v2** | 本地与线上共用基础编排，差异收敛到 `.env` 与生产叠加层 |
| 评论 | **Artalk 2.10.0** | Go 后端 + SQLite，免独立数据库；前端做成 RINE 聊天界面样式 |
| 搜索（计划） | halo `plugin-search-widget` | 官方插件，核心不含全文搜索 |
| 看板娘（计划） | LIlGG/plugin-live2d + 免费模型 | 原仓库已停更，使用活跃分支 |
| 统计（计划） | umami 自托管 | 隐私友好，无 Cookie 横幅 |

## 目录结构

```
.
├── README.md
├── CONTEXT.md                               # 领域术语表（世界线 / D-Mail / RINE…）
├── 命运石之门二次元博客-技术方案.md            # 选型对比、配色 tokens、元素映射、部署架构
├── 命运石之门二次元博客-需求文档.md            # FR / DR / NFR、里程碑、验收标准、风险表
├── deploy/                                  # ★ M0 交付：部署底座（M4a 追加 Artalk）
│   ├── docker-compose.yml                   #   Halo + PostgreSQL + Artalk（本地与线上共用）
│   ├── docker-compose.prod.yml              #   生产叠加层：Caddy 80/443
│   ├── caddy/Caddyfile                      #   自动证书 + gzip + /artalk 前缀反代 + halo:8090
│   ├── backup/backup.sh                     #   pg_dump + 附件/评论库打包 + 30 天保留 + COS 钩子
│   ├── verify/static-check.sh               #   编排 / 变量 / 手册 / 换行符 / 评论 静态校验
│   ├── verify/boot-test.sh                  #   真实起站 + 容器重建后数据留存验证
│   ├── .env.example                         #   环境变量模板（真实 .env 不入库）
│   └── README.md                            #   部署与运维手册
├── theme/                                   # ★ M1–M4a 交付：Steins;Gate 主题 z-blog-sg
│   ├── src/                                 #   源码：tokens/main.css/pages.css/comments.css、10 个路由模板
│   ├── src/js/                              #   交互层：worldline / motion / divergence / typewriter / particles / comments
│   ├── src/partials/                        #   骨架、文章卡片、分页、世界线横幅、D-Mail 元信息、评论、SEO
│   ├── verify/check-theme.sh                #   静态校验（tokens / 字体 / 布局 / 模板 / 组件 / 页面 / 集成 / 说明）
│   ├── verify/preview-test.sh               #   端到端：起站 → 初始化 → 造数据 → 装主题 → 路由/评论/SEO 断言
│   ├── verify/unit-logic.mjs                #   交互层纯逻辑单测（世界线/简洁模式/辉光管格式化）
│   ├── theme.yaml                           #   主题元信息（名称、版本、requires）
│   └── README.md                            #   主题开发说明 + 组件/评论/SEO + 人工走查清单
├── .github/workflows/ci.yml                 # 推送校验：部署底座静态校验 + 主题构建校验
├── specs/                                   # 已发布的规格基线
│   ├── deployment-baseline/spec.md          #   M0：5 条 Requirement / 9 个 Scenario
│   ├── theme-foundation/spec.md             #   M1：主题基础能力
│   ├── theme-interaction/spec.md            #   M2：交互组件与开关
│   ├── theme-pages/spec.md                  #   M3a：页面级结构与造数据
│   └── integrations/spec.md                 #   M4a：评论接入与 SEO
└── changes/                                 # 变更档案（提案 / 任务 / 设计 / 审查报告）
    ├── add-halo-deploy-base/                #   M0
    ├── add-theme-skeleton/                  #   M1
    ├── add-core-components/                 #   M2
    ├── add-page-layouts/                    #   M3a
    └── add-comments-and-seo/                #   M4a
```

## 本地快速开始

需要 Docker（含 Compose v2）。首次启动约需拉取 600 MB 以上镜像。

```bash
# 1. 准备环境变量：复制后按需修改数据库密码
cp deploy/.env.example deploy/.env

# 2. 起站
docker compose -f deploy/docker-compose.yml up -d

# 3. 打开 http://localhost:8090 ，按引导创建管理员账号
```

常用操作：

```bash
docker compose -f deploy/docker-compose.yml logs -f halo   # 看日志
docker compose -f deploy/docker-compose.yml down           # 停止（数据保留）
```

更完整的说明（数据目录、Console 入口、彻底重置）见 **[deploy/README.md](deploy/README.md)**。

装上 Steins;Gate 主题：

```bash
# 1. 构建主题包（产出 theme/dist/z-blog-sg-1.5.0.zip）
(cd theme && pnpm install && pnpm build)

# 2. 一条命令完成 起站 → 初始化 → 安装 → 激活 → 路由与组件断言，并保留站点
bash theme/verify/preview-test.sh --keep

# 3. 连评论后端与 SEO 一起验（会自动拉起 Artalk 容器）
bash theme/verify/preview-test.sh --keep --integrations --seo --plugins

# 实例已存在但想验证一个全新安装（密码未知、需要干净数据卷）
bash theme/verify/preview-test.sh --reset --keep
```

也可以把 zip 传到 Console → 主题 → 安装，再启用。主题开发约定见 **[theme/README.md](theme/README.md)**。

## 线上部署

```bash
cp deploy/.env.example deploy/.env      # 改 DOMAIN / HALO_EXTERNAL_URL / POSTGRES_PASSWORD
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml up -d
```

安全组只需放行 **22 / 80 / 443**；Halo 的 8090 只绑回环，不对外暴露。
域名解析、ICP 备案、证书申请时机、备份与恢复演练、故障排查表，全部写在 [deploy/README.md](deploy/README.md) 的「线上部署」大节。

## 自检与验证

```bash
bash deploy/verify/static-check.sh --all    # 静态校验：编排渲染、变量注入、手册章节、LF 换行符、Artalk
bash deploy/verify/boot-test.sh             # 真实起站：健康接口轮询 + 容器重建后数据留存
bash deploy/backup/backup.sh --dry-run      # 备份脚本演练（不加 --dry-run 会真的产出转储）
bash theme/verify/check-theme.sh --all      # 主题静态校验：tokens / 字体 / 布局 / 模板 / 组件 / 页面 / 集成 / 说明
node theme/verify/unit-logic.mjs            # 交互层纯逻辑单测
bash theme/verify/preview-test.sh --keep --integrations --seo --plugins  # 端到端：含评论、SEO/订阅与插件安装
```

> 交互层有两处只靠静态检查会漏掉的真实陷阱，已固化成断言：Thymeleaf 里 `__` 会被当作表达式预处理分隔符（类名、文本里出现就编译报错），以及 JS 里写死的类名必须与样式表一致（`check-theme.sh --components` 会交叉核对）。

## 文档

| 文档 | 内容 |
|------|------|
| [需求文档](命运石之门二次元博客-需求文档.md) | 功能 / 设计 / 非功能需求、M0–M5 任务分解、上线验收标准、风险表 |
| [技术方案](命运石之门二次元博客-技术方案.md) | Halo vs Hugo 选型对比、配色 tokens、SG 元素映射、部署架构 |
| [CONTEXT.md](CONTEXT.md) | 领域术语表：世界线、Divergence Meter、D-Mail、RINE、未来道具研究所… |
| [deploy/README.md](deploy/README.md) | 部署与运维手册（本地 + 线上 + 备份恢复 + 排障） |
| [theme/README.md](theme/README.md) | 主题开发说明：构建、打包、装到本地 Halo、新增模板/token、组件与开关、评论（Artalk）、SEO 与订阅、人工走查清单 |
| [specs/deployment-baseline/spec.md](specs/deployment-baseline/spec.md) | M0 已发布的规格基线 |
| [specs/theme-foundation/spec.md](specs/theme-foundation/spec.md) | M1 已发布的规格基线 |
| [specs/theme-interaction/spec.md](specs/theme-interaction/spec.md) | M2 已发布的规格基线 |
| [specs/theme-pages/spec.md](specs/theme-pages/spec.md) | M3a 已发布的规格基线 |
| [specs/integrations/spec.md](specs/integrations/spec.md) | M4a 已发布的规格基线 |
| [specs/external-plugins/spec.md](specs/external-plugins/spec.md) | M4b 已发布的规格基线 |
| [changes/add-halo-deploy-base](changes/add-halo-deploy-base) | M0 变更档案：提案、任务、设计决策、代码审查报告 |
| [changes/add-theme-skeleton](changes/add-theme-skeleton) | M1 变更档案：提案、任务、设计决策、代码审查报告 |
| [changes/add-core-components](changes/add-core-components) | M2 变更档案：提案、任务、设计决策、代码审查报告 |
| [changes/add-page-layouts](changes/add-page-layouts) | M3a 变更档案：提案、任务、设计决策、代码审查报告 |
| [changes/add-comments-and-seo](changes/add-comments-and-seo) | M4a 变更档案：提案、任务、设计决策、代码审查报告 |
| [changes/add-external-integrations](changes/add-external-integrations) | M4b 变更档案：提案、任务、设计决策、代码审查报告 |

## 设计约定

配色 tokens（主题开发时以此为准，详见技术方案）：

| Token | 值 | 用途 |
|-------|-----|------|
| `--sg-bg` | `#0a0a0f` / `#050508` | 页面主背景（研究所地下室的昏暗感） |
| `--sg-green` | `#00ff41` | CRT 终端荧光绿：标题、链接、高亮 |
| `--sg-green-dim` | `#0f9d3a` | 荧光绿次级色（描边、hover 过渡） |
| `--sg-nixie` | `#ff9500` → `#ff6a00` | 辉光管暖橙：Divergence Meter 数字 |
| `--sg-alpha` | `#4fc3f7` | α 世界线主题色（蓝） |
| `--sg-beta` | `#ff6d5a` | β 世界线主题色（橙红） |
| `--sg-text` | `#e6e6ea` | 主文字色 |

几条硬约定：

- **正文用浅色、荧光绿只做强调**——荧光绿正文长时间阅读会疲劳；对比度需过 AA。
- **Divergence Meter 默认显示 `1.048596%`**，可切换到真实数据模式。
- **简洁模式**（Plain Mode）一键关闭全部动效，并自动尊重 `prefers-reduced-motion`。
- 世界线双主题（α/β）通过 CSS 变量 + `localStorage` 记忆。

## 已知限制

- **恢复演练尚未真实执行过一次**：转储导入验证被本机命令安全策略拦下，步骤已写入运维手册，待人工执行一次。
- **`registry.fit2cloud.com` 拉取可能停滞**：Docker Hub 上的 `halohub/halo:2.27.0` 与其同源同摘要，可通过 `.env` 里的 `HALO_IMAGE` 切换。
- **域名、服务器、ICP 备案与线上真实部署尚未开始**（属于 M0 的范围外事项）。
- **主题的视觉表现未做浏览器自动化**：断点、吸顶、焦点环、对比度、以及 M2 的动效观感（扫描线、粒子、辉光、打字机、辉光管滚动）与 M3a 的页面形态（世界线横幅、CRT 终端、时间轴、成员/友链卡片）按 [theme/README.md](theme/README.md) 的走查清单人工确认。端到端脚本断言的是服务端响应结构与静态资源，抓不到 JS 改写后的 DOM。
- **看板娘的启用未能自动化验证**：插件安装接口返回 200，但 Halo 2.27 会把被禁用的插件名写进 `plugins/disabled.txt`，`PUT plugins/{name}/plugin-state` 返回 200 也不会移除该记录，插件恒为 `DISABLED`。端到端脚本因此降级为「安装成功 + 打印手工启用步骤」；实际启用需在控制台点一次。
- **umami 叠加层未做真实启动验证**：本机启动该叠加层被安全守卫拦下（命令文本含 `.env` 路径），只验证了静态渲染（`static-check.sh --analytics`）与主题侧脚本注入（`check-theme.sh --analytics`）。
- **搜索依赖发行版自带插件**：全新实例的 `plugins/` 已预设 `PluginSearchWidget`，所以搜索开箱可用；若上游移除该预设，需要自行安装插件。
- **CI 未在 GitHub Actions 上实跑过**：本地用与 CI 相同的命令验证通过（`static-check.sh --all`、`check-theme.sh --all`）。
- **造的数据形态单一**：预览脚本只造 3 个分类、3 篇文章、2 个页面，且都是二级分类、无置顶、无子分类；更复杂的内容形态（多级分类、大量分页、草稿与私密文章）待后续补充。
- **D-Mail 密码解锁（M3b）尚不可行**：Halo 2.27 的 `PostSpec` 没有密码字段（`visible` 只有 `PUBLIC/INTERNAL/PRIVATE`），主题层拿到的正文已是明文，遮不住；需要自研插件或改用密文方案，属独立立项。
- **评论按「站点名」归属，没有 siteKey**：Artalk 前端配置里只有 `site`（实测 2.10.0 的 `dist/Artalk.js` 中 `siteKey` 出现 0 次），所以主题的 `comments_site_name` 必须与 Artalk 后台站点名一致，否则评论会落到另一个站点。
- **`og:url` 与 `canonical` 依赖站点地址**：模板里只有相对 permalink，拼绝对地址要读站点对外 URL；拿不到时这两个标签不会输出（宁缺不错）。在控制台配好站点地址或给 Halo 正确的 `--halo.external-url` 后自动出现。
- **`/artalk` 前缀反代只在本地验过**：`caddy validate`/`caddy adapt` 确认规则正确（`handle_path` 会剥前缀），但没有在真实域名 + 证书下跑过，第一次线上部署需要确认评论接口可达。

## 版权

- 本项目为个人学习与自用项目，视觉设计均为原创致敬，**不使用任何《命运石之门》官方素材**。
- 评论系统、看板娘模型等第三方组件遵循各自的许可协议。

---

本仓库的变更使用 [spec-superflow](https://github.com/MageByte-Zero/spec-superflow) 的 planned 流程推进：提案 → 任务 → 设计 → 实现 → 审查 → 归档，全过程留痕在 `changes/` 与 `specs/` 中。已完成 M0（`add-halo-deploy-base`）、M1（`add-theme-skeleton`）、M2（`add-core-components`）、M3a（`add-page-layouts`）与 M4a（`add-comments-and-seo`）。
