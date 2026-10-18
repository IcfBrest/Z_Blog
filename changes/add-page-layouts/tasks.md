# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
|------|----------|------|------|
| 1 | 六类页面（首页横幅、文章详情 CRT 与 D-Mail 元信息、归档时间轴、列表与分类分支、关于成员卡与友链卡片、404 终端）在模板与样式层就位，并有静态断言守住结构 | 无 | `bash theme/verify/check-theme.sh --pages` |
| 2 | 预览验证能自动造出分类、文章与独立页面，并对着真实内容断言页面级结构，可重复执行 | 批次 1 | `bash theme/verify/preview-test.sh --reset --keep` |
| 3 | 文档与体积预算同步，全量校验无回归 | 批次 2 | `bash theme/verify/check-theme.sh --all` |

## 任务

- [x] **1.1 新增首页世界线横幅片段并在首页引用**：新建 `theme/src/partials/worldline-banner.html`（内联 SVG，节点遍历 `categories`，上限 5，节点链到 `cat.status.permalink`，第一节点默认高亮），并在 `theme/src/index.html` 的 hero 之后 include；完成后首页首屏出现 `svg.sg-worldline` 且节点数与分类数一致；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.2 文章详情加 CRT 终端容器与 D-Mail 元信息片段**：新建 `theme/src/partials/post-meta.html`（发送时间 / 发信人 / 世界线三段，无分类时世界线为「未观测」），并把 `theme/src/post.html` 的正文包进 `section.sg-terminal`（标题栏 + 局部扫描线 + 内容区）；完成后文章详情含 `sg-terminal` 与 `sg-dmail` 两处结构且正文不被截断；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.3 归档改为世界线时间轴**：修改 `theme/src/archives.html`，把年度 section 结构换成 `ol.sg-timeline`（年 `li.sg-timeline__year`、月 `li.sg-timeline__month`、文章子列表），分页留在时间轴之外，并补空归档提示；完成后归档页含时间轴节点而非年度标题堆叠；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.4 独立页面加 CRT 容器与成员卡、友链卡片网格**：修改 `theme/src/page.html`，正文包进 `section.sg-terminal`，并新增成员卡网格（`ul.sg-member-grid`）与友链卡片网格（`ul.sg-friend-grid`），由 `singlePage.spec.slug` 与设置项 `member_page_slug`/`friends_page_slug` 决定渲染哪一个；完成后关于页出现成员卡、友链页出现友链网格、普通页面只有终端容器；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.5 列表与分类页终端化并加世界线分支徽章**：修改 `theme/src/partials/post-card.html`、`theme/src/categories.html`、`theme/src/category.html`、`theme/src/tags.html`、`theme/src/tag.html`，统一终端列表形态，分类处渲染「世界线分支」徽章（含分类名与 `postCount`）；完成后分类页含 `sg-branch` 徽章、分类总览每项同时显示名称与文章数；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.6 错误页统一为 CRT 错误终端**：修改 `theme/src/error/error.html`，套用 `section.sg-error` 终端外壳并保留「未找到该世界线」文案；完成后 404 页面含终端外壳标记；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.7 补设置项、升版本并写组件样式**：在 `theme/settings.yaml` 的交互分组后新增 `master_name`（text，默认「站长」）、`member_page_slug`（text，默认 `about`）、`friends_page_slug`（text，默认 `friends`）；`theme/theme.yaml` 版本升到 `1.2.0`；在 `theme/src/css/main.css` 与 `theme/src/css/tokens.css` 中补齐 `.sg-worldline`、`.sg-terminal`、`.sg-dmail`、`.sg-timeline`、`.sg-branch`、`.sg-member-grid`、`.sg-friend-grid` 及其断点与简洁模式规则；完成后构建产物含上述类名且不新增运行时依赖；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **1.8 给校验脚本加 `--pages` 断言集**：修改 `theme/verify/check-theme.sh`，新增 `--pages`（断言六类页面结构在源模板中存在、组件类名在构建 CSS 中存在、设置项三个默认值存在、`theme.yaml` 版本不低于 1.2.0），并把 `--pages` 纳入 `--all`；完成后 `--pages` 单独可跑且 `--all` 覆盖它；证明：`bash theme/verify/check-theme.sh --pages`。
- [x] **2.1 探针确认造数据端点与最小请求体**：新建临时脚本 `theme/verify/_probe-content.sh`，用已封装的登录流程逐一试探创建分类、文章、独立页面的 console API（方法、路径、必填字段），把结论写进 `theme/README.md` 与 `changes/add-page-layouts/design.md` 的已知事实，探针脚本用后删除；完成后端点与请求体有实测记录，未知项显式标注；证明：`bash theme/verify/preview-test.sh --reset --keep`。
- [x] **2.2 预览验证自动造数据**：修改 `theme/verify/preview-test.sh`，在装主题之前创建 3 个分类（技术/生活/随想）、3 篇已发布文章（分属不同分类）、关于页与友链页两个独立页面，全部按 slug/name 先查后建以保证幂等；完成后全新实例跑完后站点里有内容且退出码 0；证明：`bash theme/verify/preview-test.sh --reset --keep`。
- [x] **2.3 预览验证加页面级结构断言**：修改 `theme/verify/preview-test.sh`，对文章详情断言 `sg-terminal`、`sg-dmail` 与世界线分类名，对归档断言 `sg-timeline` 与年份节点，对分类页断言 `sg-branch`，对关于页断言 `sg-member-grid`、对友链页断言 `sg-friend-grid`；完成后这些断言全部为绿色且失败时能指出缺哪个标记；证明：`bash theme/verify/preview-test.sh --reset --keep`。
- [x] **2.4 验证重复执行的幂等性**：在同一实例上连跑两次预览验证（第二次不带 `--reset`），确认不新建重复分类/文章/页面且断言仍全绿；完成后第二次执行的输出里能看到「已存在，跳过」的记录；证明：`bash theme/verify/preview-test.sh --reset --keep`。
- [x] **3.1 补主题文档**：修改 `theme/README.md`，新增「页面结构」一节（六类页面与对应模板/片段/设置项）、「预览验证会造哪些数据」与「如何改关于页与友链页」，并更新目录树与走查清单；完成后文档描述的类名与设置项与实现一致；证明：`bash theme/verify/check-theme.sh --docs`。
- [x] **3.2 复核体积与全量回归**：重跑构建取产物体积，更新 `theme/README.md` 的体积预算表，并确认 `bash deploy/verify/static-check.sh --all` 与 `bash theme/verify/check-theme.sh --all` 均无回归；完成后两份报告全绿且体积仍在预算内；证明：`bash theme/verify/check-theme.sh --all`。

## 实施备注（仅在必要时）

- 世界线横幅的节点上限与窄屏收敛由模板侧 `th:each` 的 `stat.index < 5` 判定，CSS 侧再加一条 ≤480px 的隐藏文字规则；两处都要改，断言分别覆盖。
- 关于页与友链页的卡片数据**不在**模板里，仍在页面正文的 Markdown 中，模板只提供外壳与网格样式；不要为「卡片数据」新增设置项。
- 造数据必须幂等：分类按 `spec.slug`、文章与页面按 `metadata.name`（或 `spec.slug`）先查后建，任何一步失败都要打印端点、状态码与响应片段。
- 若 2.1 探针确认文章创建需要 Post + Snapshot 两步且无法稳定复现，则 2.2/2.3 降级为「手工造数据 + 只保留结构断言」，并在审查报告里记为已验证缺口，不得静默跳过。
