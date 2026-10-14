# Z_Blog · 命运石之门主题个人博客

> 「未来并不是注定不变的。所以，才要向前看。」

一个以《命运石之门》（Steins;Gate）为视觉主题的个人博客：辉光管 **Divergence Meter**、**α / β 双世界线**主题切换、CRT 终端质感的文章容器，底层是 **Halo + PostgreSQL + Caddy** 的全容器化部署。

内容以**技术笔记、生活记录与随想**为主；所有视觉元素都是原创的 SVG / CSS 致敬，不使用官方素材。

---

## 当前状态

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| **M0** | 环境与部署底座（Halo + PostgreSQL + Caddy + Docker Compose、备份脚本、运维手册） | ✅ **已完成** |
| M1 | 主题骨架（theme-starter 工程、配色 tokens、基础布局、字体自托管） | ⏳ 待开始 |
| M2 | 核心组件（Divergence Meter、CRT 动效、双主题切换、简洁模式） | ⏳ 待开始 |
| M3 | 页面铺开（首页 / 列表 / 详情 / 归档 / 关于 / 友链 / 404、D-Mail 密码解锁） | ⏳ 待开始 |
| M4 | 集成（Artalk 评论、搜索、看板娘、umami 统计、SEO） | ⏳ 待开始 |
| M5 | 打磨与发布（性能优化、恢复演练、首发文章） | ⏳ 待开始 |

> 站点目前只有 **Halo 默认主题**；Steins;Gate 主题开发从 M1 开始。

## 技术栈

| 层次 | 选型 | 说明 |
|------|------|------|
| 博客应用 | **Halo 2.27.0**（Java / Spring Boot） | 动态博客，插件与主题生态完整，支持密码文章 |
| 数据库 | **PostgreSQL 15** | 运行在**命名卷** `sg-blog-halodb-data`（Windows 绑定挂载会导致 `initdb` 权限失败） |
| 反向代理 | **Caddy 2** | 四行配置拿到自动 HTTPS 证书与续期，比 Nginx + certbot 少一个常驻进程 |
| 编排 | **Docker Compose v2** | 本地与线上共用基础编排，差异收敛到 `.env` 与生产叠加层 |
| 评论（计划） | Artalk | Go 后端 + SQLite，免独立数据库；前端做成 RINE 聊天界面样式 |
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
├── deploy/                                  # ★ M0 交付：部署底座
│   ├── docker-compose.yml                   #   Halo + PostgreSQL（本地与线上共用）
│   ├── docker-compose.prod.yml              #   生产叠加层：Caddy 80/443
│   ├── caddy/Caddyfile                      #   自动证书 + gzip + 反代 halo:8090
│   ├── backup/backup.sh                     #   pg_dump + 附件打包 + 30 天保留 + COS 钩子
│   ├── verify/static-check.sh               #   编排 / 变量 / 手册 / 换行符 静态校验
│   ├── verify/boot-test.sh                  #   真实起站 + 容器重建后数据留存验证
│   ├── .env.example                         #   环境变量模板（真实 .env 不入库）
│   └── README.md                            #   部署与运维手册
├── specs/deployment-baseline/spec.md        # 已发布的规格基线（5 条 Requirement / 9 个 Scenario）
└── changes/add-halo-deploy-base/            # M0 变更档案（proposal / tasks / design / 审查报告）
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

## 线上部署

```bash
cp deploy/.env.example deploy/.env      # 改 DOMAIN / HALO_EXTERNAL_URL / POSTGRES_PASSWORD
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml up -d
```

安全组只需放行 **22 / 80 / 443**；Halo 的 8090 只绑回环，不对外暴露。
域名解析、ICP 备案、证书申请时机、备份与恢复演练、故障排查表，全部写在 [deploy/README.md](deploy/README.md) 的「线上部署」大节。

## 自检与验证

```bash
bash deploy/verify/static-check.sh --all    # 静态校验：编排渲染、变量注入、手册章节、LF 换行符
bash deploy/verify/boot-test.sh             # 真实起站：健康接口轮询 + 容器重建后数据留存
bash deploy/backup/backup.sh --dry-run      # 备份脚本演练（不加 --dry-run 会真的产出转储）
```

## 文档

| 文档 | 内容 |
|------|------|
| [需求文档](命运石之门二次元博客-需求文档.md) | 功能 / 设计 / 非功能需求、M0–M5 任务分解、上线验收标准、风险表 |
| [技术方案](命运石之门二次元博客-技术方案.md) | Halo vs Hugo 选型对比、配色 tokens、SG 元素映射、部署架构 |
| [CONTEXT.md](CONTEXT.md) | 领域术语表：世界线、Divergence Meter、D-Mail、RINE、未来道具研究所… |
| [deploy/README.md](deploy/README.md) | 部署与运维手册（本地 + 线上 + 备份恢复 + 排障） |
| [specs/deployment-baseline/spec.md](specs/deployment-baseline/spec.md) | M0 已发布的规格基线 |
| [changes/add-halo-deploy-base](changes/add-halo-deploy-base) | M0 变更档案：提案、任务、设计决策、代码审查报告 |

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

## 版权

- 本项目为个人学习与自用项目，视觉设计均为原创致敬，**不使用任何《命运石之门》官方素材**。
- 评论系统、看板娘模型等第三方组件遵循各自的许可协议。

---

本仓库的 M0 变更使用 [spec-superflow](https://github.com/MageByte-Zero/spec-superflow) 的 planned 流程推进：提案 → 任务 → 设计 → 实现 → 审查 → 归档，全过程留痕在 `changes/` 与 `specs/` 中。
