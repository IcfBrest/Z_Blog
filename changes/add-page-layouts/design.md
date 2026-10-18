# 设计说明

## 已知事实与约束

- **模板机制**：Halo 2 主题是 Thymeleaf `.html`；路由模板用 `<include src="layout.html">` + `<template name="head">`，骨架必须写 `<slot name="head">` / `<slot />`（M1 已固化为断言）。`__` 是表达式预处理分隔符，类名与文本里出现会渲染 500（M2 事故）。
- **已有模板变量**：`posts.items` / `posts.total` / `post.spec.*` / `post.status.permalink` / `post.categories` / `post.tags` / `cat.spec.displayName` / `cat.status.permalink` / `cat.postCount` / `archives.items[].year` / `.months[].month` / `.posts` / `singlePage.spec.title` / `singlePage.content.content` / `menuFinder.getPrimary()` / `haloCommentEnabled`。
- **`/categories` 与 `/tags` 的模型属性是 `ArrayList`**，不是分页对象（M2 事故，误用 `.items` 会 500）。
- **`PostSpec` 没有 `password` 字段**：字段只有 `title/slug/template/cover/publish/publishTime/pinned/allowComment/visible/priority/excerpt/categories/tags/htmlMetas`。`visible` 只有 `PUBLIC/INTERNAL/PRIVATE`。因此密码文章在主题层**无法**遮蔽（正文到模板时已是明文），本变更不做 `FR-2`。
- **主题没有稳定的「作者显示名」变量**：`author.spec.displayName` 只在作者页上下文存在；`post.spec.owner` 是登录用户名。所以「发信人」需要一个设置项，不能硬编码。
- **Halo 没有主题升级接口**：同名主题装过之后 `install` 一律 400，`preview-test.sh` 用 `--reset` 重建实例。
- **空站点验证盲区**：现有 `preview-test.sh` 只有空站点断言，文章详情/归档/分类节点/关于页这些「有内容才出现」的结构从未被自动验证。
- **console API 需要登录**：RSA 加密密码 → `302 /uc` → `X-XSRF-TOKEN` 头。现有脚本已封装这套流程，可直接复用为造数据的基础。
- **造数据端点（探针实测）**：分类 `POST /apis/content.halo.run/v1alpha1/categories` → 201，重复建返回 400「检测到有重复的名称」（`title: 名称重复`）；文章 `POST /apis/api.console.halo.run/v1alpha1/posts` → 200，请求体是 `{post, content, contentPatch}`，`spec.publish: true` 即直接发布（会生成 baseSnapshot）；独立页面 `POST /apis/api.console.halo.run/v1alpha1/singlepages` → 200，请求体键名是 `page`；`PUT .../posts/{name}/publish` → 200 且幂等。普通资源的 `POST /apis/content.halo.run/v1alpha1/posts` 直接 500（缺 snapshot），不能用于造数据。
- **文章与分类的访问路径**：文章 permalink 模式是 `/archives/{slug}`，分类页是 `/categories/{slug}`；断言分别用 `/archives/<slug>` 与 `/categories/<slug>`。
- **Halo 初始化自带「默认分类」**：全新实例在初始化时就已经有一个 `默认分类`，脚本再建技术 / 生活 / 随想三个分类后，横幅与分类总览各出现 **4** 个节点。因此断言写「不少于 3」而不是等值——把 Halo 的内置数据当成回归会一直误报。

## 目标与非目标

**目标**

1. 让 `DR-2` 的六行页面映射逐行可断言：首页横幅、文章详情 CRT 容器 + D-Mail 元信息、归档时间轴、分类世界线分支、关于成员卡、友链卡片、404 错误终端。
2. 让预览验证从「空站点」升级为「有数据」：造分类、文章、页面，再断言结构。
3. 保持 2C2G 与国内网络的成本约束：不新增运行时依赖，不引入 Canvas/SVG 库，动效仍受简洁模式与 `prefers-reduced-motion` 约束。

**非目标**

- 不做密码文章（需要插件或后端能力，M3b）。
- 不做 α/β 的强差异视觉（本变更只做分类维度的世界线分支标识）。
- 不改配色 token 与字体策略（沿用 DR-1、DR-4）。
- 不引入评论、搜索、统计（M4）。

## 决策（Decisions）

### 决策：世界线横幅用内联 SVG 且节点来自分类

**选择**：在 `partials/worldline-banner.html` 里手写内联 `<svg>`，横向一条折线串起若干节点；节点集合取分类列表（首页取全部已发布分类，最多 5 个），每个节点链到分类页，当前页所属分类高亮。

**理由**：纯 SVG 随模板直出，禁脚本时依然完整；不增加任何依赖与二进制资源；节点数量由数据决定，不需要 Canvas 与 JS 布局计算。版权上完全原创（只有折线、圆点、文字），不触碰官方素材。

**替代方案**：① Canvas 绘制——需要 JS，且禁脚本时页面缺一块；② 静态图片——不能随分类变化，且引入二进制资产与版权风险；③ CSS 画折线——节点对齐在响应式下难做。

**后果**：SVG 的 `viewBox` 固定比例，窄屏只能等比缩放，节点文字在小屏会偏小；因此小屏隐藏节点文字、只保留圆点，并降低节点上限为 3。

### 决策：CRT 终端容器是纯 CSS 结构件，扫描线只作用在容器内

**选择**：新增 `.sg-terminal` 组件（标题栏 + 内容区 + 容器内扫描线伪元素 + 辉光边框），文章详情、独立页面、404 错误页共用。全局 `.sg-scanline` 仍由 layout 提供，`.sg-terminal` 内部那条是**局部**叠加。

**理由**：文章详情需要「终端窗口」感，而全局扫描线是整页叠层，两者语义不同；用局部伪元素可以在容器圆角内裁切，不与全屏叠层冲突。纯 CSS 也保证简洁模式下自动归零（复用 `--motion-*` 与 `data-motion` 规则）。

**替代方案**：① 用全局扫描线代替——没有窗口边界，看不出「终端容器」；② 引入终端仿真库——过度依赖。

**后果**：容器内扫描线与全局扫描线叠加时亮度略高，需要在 `.sg-terminal` 内降低局部叠层透明度；`check-theme.sh --pages` 需要断言局部扫描线与全局叠层是两条不同规则。

### 决策：D-Mail 元信息做成 partial，发信人取主题设置项

**选择**：新增 `partials/post-meta.html`，渲染「发送时间 / 发信人 / 世界线」三段；发信人取新增设置项 `master_name`（默认「站长」），世界线取第一分类的 `displayName`（无分类时显示「未观测」。

**理由**：Halo 模板没有稳定的作者显示名字段（见「已知事实」），硬编码「站长」又不利于改称呼；一个 text 设置项的代价远小于硬编码。

**替代方案**：① 硬编码「站长」——改名要改模板；② 用 `post.spec.owner`——访客看到的是登录名 `admin`；③ 用 `authorFinder` ——只有作者页上下文才有对象。

**后果**：设置项从 5 个增加到 8 个（`master_name`、`member_page_slug`、`friends_page_slug`），`settings.yaml` 的默认值断言要同步扩展。

### 决策：归档改为真时间轴（有序列表 + CSS 折线）

**选择**：`archives.html` 从「年度 section + 月份 div + ul」改成 `<ol class="sg-timeline">`，年与月都是 `<li>` 节点，文章挂在 `<ol class="sg-timeline__posts">` 里；折线由容器的 `::before` 竖线承担，节点用 `::after` 圆点 + 辉光。

**理由**：语义上归档本来就是有序序列，`<ol>` 比一堆 `div` 更准确；竖线用一个伪元素比给每项画边框更省 DOM，也更容易在窄屏保持连续。

**替代方案**：① 保留 div 结构只改样式——语义仍是「扁平列表」，且折线要靠每项 border 拼接，容易断在分页处；② Canvas 时间轴——可读性与可访问性都差。

**后果**：`archives.hasPrevious()/hasNext()` 的分页保留在时间轴之外；时间轴在 ≤480px 需要把年份节点改成横向贴边，否则左边距吃掉可读宽度。

### 决策：关于页与友链页用「slug 命中」而非自定义页面模板

**选择**：`page.html` 读取新增设置项 `member_page_slug`（默认 `about`）与 `friends_page_slug`（默认 `friends`），当 `singlePage.spec.slug` 命中时在正文**上方**渲染成员卡网格 / 友链卡片网格，正文仍由站长在后台写 Markdown。

**理由**：Halo 的自定义页面模板（`spec.template` → 模板文件名约定）没有在文档与实测中被确认，赌一个未验证的机制会让整个关于页失效；slug 命中是纯模板比较，可测、可回退，且换 slug 只需改设置项。

**替代方案**：① 自定义页面模板——机制未验证，风险高；② 在 Markdown 里写 HTML 卡片——Halo 编辑器会做内容清洗（sanitize），样式类可能被丢弃；③ 用 repeater 设置项存成员数据——settings 的 repeater 支持未验证，且会让「改成员」必须进主题设置。

**后果**：成员卡与友链卡片的**数据**仍在文章正文（Markdown 表格或列表），模板只负责外壳与网格样式；这意味着「卡片」不是结构化数据，排序与字段由站长自己保证。这一取舍写进 `theme/README.md`，避免以后误以为有数据结构。

### 决策：造数据走 console API，且必须先探测端点

**选择**：`preview-test.sh` 增加造数据步骤，通过 console API 创建 3 个分类、3 篇文章（分属不同分类）、2 个独立页面（关于/友链）；每个资源创建前先按 `slug`/`name` 查询，存在则跳过（幂等）。**第一个任务就是写探针脚本确认端点与最小请求体**，成功前不写正式流程。

**理由**：Halo 的文章创建涉及 Post 资源 + 内容快照两步（`spec.releaseSnapshot/headSnapshot`），端点与必填字段没有文档保证；先探测再实现，避免把错误假设写进脚本再花时间调试。幂等是硬要求——`preview-test.sh` 会被反复执行。

**替代方案**：① 直接写 SQL 插入——绕过 Halo 的资源索引与快照，数据会「存在但打不开」，不可接受；② 手工在 Console 里造数据——不可重复、无法进 CI；③ 用 Halo 的 import 功能导入——需要准备 Halo 导出格式，脆弱。

**后果**：造数据能力只存在于验证脚本里，不进入运行时；失败时脚本要给出明确提示（哪个端点、哪个字段），并允许 `--with-content` 之外的回退路径（只跑空站点断言）。若探测失败，本变更的批次 2 降级为「手工造数据 + 结构断言脚本」，并在审查报告里记为已验证缺口。

## 风险与验证

| 风险 | 影响 | 应对 |
|------|------|------|
| console API 造文章需要多步（Post + Snapshot），端点不确定 | 批次 2 无法自动化 | 先写探针；失败则降级为手工造数据 + 只保留结构断言，并在报告记录缺口 |
| 世界线横幅在窄屏挤压标题 | 首页视觉退化 | 359/480 断点隐藏节点文字，只留圆点；上限从 5 降到 3 |
| 归档时间轴 CSS 在长列表下性能或错位 | 可读性 | 折线用单个伪元素，节点用 `::after`；≤480px 单独适配 |
| 新增 3 个设置项破坏既有 `settings.yaml` 断言 | 校验失败 | 同步扩展 `check-theme.sh` 的设置项与默认值断言 |
| slug 命中方案让「关于页」依赖设置项 | 配错就不显示成员卡 | 默认值即项目约定（`about`/`friends`），README 写明；断言检查默认值存在 |
| 主题版本升级需要重建实例 | 验证中断 | 沿用 `--reset`，`theme.yaml` 版本升到 1.2.0 |

验证方式：`check-theme.sh --pages`（模板结构静态断言）+ `preview-test.sh --reset --keep`（造数据后的端到端结构断言）+ `check-theme.sh --all` 与 `deploy/verify/static-check.sh --all` 防回归。
