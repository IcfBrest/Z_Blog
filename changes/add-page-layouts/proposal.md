# 变更提案

## 背景（Why）

M1 交付了主题骨架与 10 个路由模板，M2 交付了交互层（世界线切换、Divergence Meter、CRT 装饰层、简洁模式）。但当前的页面只是「能渲染」：模板里是通用的标题 + 列表 + 正文，`DR-2` 要求的页面级视觉映射几乎没有落地——文章详情没有 CRT 终端容器，也没有「D-Mail 发送记录」元信息；归档是一列普通的年度标题，不是世界线时间轴；首页没有世界线横幅；关于页与友链页没有研究所成员卡与友链卡片；分类页看不出「世界线分支」的含义。

同时暴露了一个验证盲区：`theme/verify/preview-test.sh` 只在**空站点**上断言路由可达与骨架标记，因此文章详情、归档时间轴、分类节点这些「有内容才出现」的结构从来没有被自动验证过。M2 的审查报告把这条列为剩余风险 R-3。

这个变更要把 `DR-2` 的六行页面映射逐行变成可验证的模板结构，并把预览验证从「空站点」推进到「有数据」。

## 变更内容（What Changes）

- **首页**：新增世界线 SVG 横幅（原创绘制，不使用任何官方素材），节点由分类数据驱动，当前分类高亮；保留既有 Divergence Meter 与打字机。
- **文章详情**：正文包进 CRT 终端容器（标题栏 + 容器内扫描线 + 辉光边框）；头部新增「D-Mail 发送记录」元信息（发送时间、发信人、世界线=分类）。
- **归档**：改为竖向世界线时间轴，年年份为节点、月为子节点、文章挂在折线上，节点带辉光。
- **列表 / 分类 / 标签**：统一终端列表形态，分类名带「世界线分支」徽章；分类页给出该分支的世界线标识。
- **关于 / 友链**：`page.html` 增加 CRT 容器，并按主题设置项识别「关于页」「友链页」，渲染研究所成员卡网格与友链卡片网格。
- **404 / 错误页**：统一成 CRT 错误终端外壳，与其它页面同构。
- **验证能力**：`preview-test.sh` 增加造数据步骤（分类、文章、关于页、友链页），并对文章详情、归档、分类页做结构断言；`check-theme.sh` 新增 `--pages` 断言集。

## 范围（Scope）

### 范围内（In Scope）

- `theme/src/` 下的模板与样式改造：`index.html`、`post.html`、`page.html`、`archives.html`、`categories.html`、`category.html`、`tags.html`、`tag.html`、`error/error.html`，新增 `partials/worldline-banner.html`、`partials/post-meta.html`。
- 主题设置项新增两项：`member_page_slug`（默认 `about`）、`friends_page_slug`（默认 `friends`）。
- `theme/verify/check-theme.sh` 新增 `--pages`；`theme/verify/preview-test.sh` 新增造数据与结构断言。
- 文档：`theme/README.md` 的页面结构与造数据说明。

### 范围外（Out of Scope）

- 密码文章与 D-Mail 解锁（`FR-2`）：Halo 2.27 的 `PostSpec` 没有 `password` 字段，主题层无法遮蔽明文，方案未定，单独立为 M3b。
- Artalk 评论、搜索、看板娘、统计、SEO（M4）。
- 世界线切换的「强差异视觉」（α/β 大色块与纹样）——本变更只做分类维度的世界线分支标识。
- 真实文章内容与文案润色（M5 首发文章）。
- 任何真实《命运石之门》官方素材。

## 影响与验证

**影响区域**

- `theme/src/**`（模板与 CSS，新增两个 partial）
- `theme/settings.yaml`（+2 个设置项，`theme.yaml` 版本升到 1.2.0）
- `theme/verify/*.sh`（新增断言集与造数据流程）
- 不改 `deploy/`、不改 Halo 核心、不引入新依赖

**完成证明**

- `bash theme/verify/check-theme.sh --all` 全绿（含新增 `--pages` 断言）
- `bash theme/verify/preview-test.sh --reset --keep` 全绿，且断言覆盖：文章详情含 CRT 容器与 D-Mail 元信息、归档含时间轴节点、分类页含世界线分支标识、关于页含成员卡、友链页含友链卡片
- `bash deploy/verify/static-check.sh --all` 仍全绿（无回归）
- 造数据具备幂等性：连续跑两次不产生重复分类/文章/页面
