# z-blog-sg · 主题工程

命运石之门风格的个人博客主题（非官方粉丝作品，仅供个人使用）。主题名 `z-blog-sg`，必须与 Halo 内的安装目录名一致。

模板是 **Thymeleaf**（`.html`），不是 Halo 1.x 的 FreeMarker。Halo 2.26 起为 Thymeleaf 3.1，`#request`、`#response`、`#session`、`#servletContext` 都不再可用；页面链接一律用 permalink 或 `settings.yaml` 里的配置项，不要试图从请求对象推导 URL。

## 目录结构

```
theme/
├── src/                    源码（改这里）
│   ├── index.html          首页
│   ├── post.html           文章详情
│   ├── page.html           独立页面
│   ├── archives.html       归档
│   ├── categories.html     分类列表
│   ├── category.html       单个分类
│   ├── tags.html           标签列表
│   ├── tag.html            单个标签
│   ├── author.html         作者页
│   ├── error.html          404
│   ├── partials/           构建期片段（不会单独进入产物）
│   │   ├── layout.html     统一骨架：页头 / 内容区 / 页脚
│   │   ├── post-card.html  文章卡片
│   │   └── pagination.html 分页
│   ├── css/
│   │   ├── tokens.css      DR-1 配色 token（唯一颜色来源）
│   │   ├── fonts.css       自托管字体引入
│   │   └── main.css        布局与组件样式
│   └── js/main.ts          样式入口
├── verify/
│   ├── check-theme.sh      静态校验（检查构建产物）
│   └── preview-test.sh     本地预览验证（起站 + 渲染断言）
├── theme.yaml              主题元数据
├── settings.yaml           主题设置项
├── templates/              构建产物（不入库）
└── dist/                   打包产物 z-blog-sg-*.zip（不入库）
```

`templates/`、`assets/`、`dist/` 都是构建产物，已被 `.gitignore` 排除。**clone 之后必须先构建**，否则不能安装也没有东西可校验。

## 环境要求

- Node ≥ 20.19（本机 v24.19.0）
- pnpm ≥ 9（本机 11.23.0）

## 构建

```bash
cd theme
pnpm install
pnpm build-only     # 只构建：生成 templates/ 与 templates/assets/
```

构建结果：

- `templates/*.html` —— 10 个路由模板，`<include>` 在构建期做文本替换：骨架与片段被直接内联进每个路由文件
- `templates/` 里**不应**出现 `layout.html`。一旦出现，说明 include 解析到了 `src/layout.html` 而不是 `src/partials/layout.html`，产物会变成没有任何页面内容的空壳（`check-theme.sh` 会直接报错）
- `templates/assets/main-<hash>.css` —— 打包后的样式，含全部 token 与 `@font-face`
- `templates/assets/*.woff2` —— 自托管字体分片（Noto Sans SC 按 unicode-range 切片）

## 打包

```bash
cd theme
pnpm build
```

`pnpm build` = `vite build && theme-package`，产出 `theme/dist/z-blog-sg-1.0.0.zip`（约 5.5 MB，体积主要来自中文字体分片，可一起打进主题包）。这个 zip 就是分发物，直接上传到 Halo 控制台安装。

## 安装到本地 Halo

两种方式，任选其一：

**方式一：上传 zip（与线上一致）**

1. `cd theme && pnpm build`
2. 打开 `http://localhost:8090/console` → 外观 → 主题 → 安装主题 → 上传 `theme/dist/z-blog-sg-1.0.0.zip`
3. 启用该主题

**方式二：直接放进主题目录（开发时更快）**

```bash
cd theme && pnpm build-only
DEST=../deploy/data/halo2/themes/z-blog-sg
rm -rf "$DEST"
mkdir -p "$DEST"
cp -r templates/. "$DEST/"
cp theme.yaml settings.yaml "$DEST/"
```

安装目录名必须正好是 `z-blog-sg`，否则 Halo 会认为 `metadata.name` 不匹配而拒绝加载。改完模板重新 `pnpm build-only` 后，在控制台「主题 → 重新加载」即可看到效果，不用反复上传 zip。

想边改边看：`pnpm dev`（=`vite build --watch`），另开一个终端刷页面。

## 新增页面模板

1. 在 `src/` 下新建 `<路由名>.html`，例如 `src/links.html`。
2. 第一行必须是 `<include src="layout.html">`，最后一行 `</include>`，中间内容会在构建期被塞进骨架（`src/partials/layout.html`）的默认 `<slot />` 位置。骨架用的是 `<slot>` / `<slot name="head">` 占位，**不是** Thymeleaf 的 `th:fragment` + `th:replace`。
3. 需要改 `<title>` 时，用 `<template name="head">` 包裹：

```html
<include src="layout.html">
  <template name="head">
    <title th:text="|友链 - ${site.title}|">友链</title>
  </template>

  <h1 class="sg-hero__title">友链</h1>
</include>
```

4. 需要的模板变量以 Halo 文档为准（`posts`、`post`、`singlePage`、`archives`、`categories`、`category`、`tags`、`tag`、`author`）；Finder 用 `postFinder`、`menuFinder` 等。不要凭记忆猜方法名，查 [主题文档](https://docs.halo.run/developer-guide/theme/index.md)。
5. 构建后 `templates/<路由名>.html` 应当出现，且 `bash theme/verify/check-theme.sh --templates` 仍然通过。

## 新增配色 token

原则：**颜色只有一个来源**。`src/css/tokens.css` 是唯一允许写色值的地方，其他样式一律用 `var(--语义变量)`。

1. 在 `tokens.css` 的「原始 token」区加一行，例如 `--sg-danger: #ff5f56;`。
2. 如果需要组件语义，再在「语义层」加一行 `--danger: var(--sg-danger);`。
3. 组件里只用 `var(--danger)`，不要直接写 `var(--sg-danger)`——M2 切世界线时只改语义层。
4. 跑 `bash theme/verify/check-theme.sh --tokens`：它会扫描 `tokens.css` 之外的所有样式，发现色值字面量就判失败。

## 本地预览验证

`theme/verify/preview-test.sh` 把「起站 → 初始化 → 装主题 → 激活 → 路由断言」串成一条命令，用来在不用手点控制台的情况下确认主题真的能渲染：

```bash
bash theme/verify/preview-test.sh          # 验完停站（保留数据）
bash theme/verify/preview-test.sh --keep   # 验完保持容器运行，方便人工走查
bash theme/verify/preview-test.sh --purge  # 验完停站并删除数据卷与 deploy/data
```

- 前提：Docker 已启动、`deploy/` 下的编排可用、`theme/dist/z-blog-sg-<版本>.zip` 已构建。
- 站点未初始化时它会自动初始化，管理员默认 `admin` / `SgPreviewPass1`；可用 `HALO_ADMIN_USER`、`HALO_ADMIN_PASS`、`HALO_ADMIN_EMAIL`、`HALO_SITE_TITLE`、`BASE_URL` 覆盖。Halo 只允许 `A-Z a-z 0-9` 与 `!@#$%^&*` 作为密码字符，默认值里因此不能出现连字符。
- 它断言六类路由（首页、归档、分类、标签、作者、404）返回预期状态码，且每页都含主题骨架标记与 DR-5 页脚声明。
- 想回到「未初始化」状态重来：`bash theme/verify/preview-test.sh --purge`。

## 人工走查清单

自动化只能断言 CSS 规则与 DOM 结构，真实视觉需要人眼确认。每次改动布局后按下面走一遍（`bash theme/verify/preview-test.sh --keep` 可以把站点留着）：

| 检查项 | 怎么看 | 合格标准 |
|---|---|---|
| 桌面布局 | 1440px 宽打开首页 | 内容居中、单列、两侧留白对称，无横向滚动条 |
| 平板布局 | 缩到 900px 左右 | 留白收窄、标题略小，导航仍然一行展开 |
| 手机布局 | 缩到 390px 或真机 | 导航折叠成 `≡`，点开纵向展开；正文不出现横向滚动 |
| 页头 | 滚动页面 | 页头吸顶，底部有绿色细边，标题在左上、导航在右 |
| 页脚 | 滚到底部 | 有橙色 `非官方粉丝作品（fan homage），Steins;Gate © MAGES./Nitroplus` 一行 |
| 字体 | 打开 DevTools → Network → Font | 只有本域名下的 `woff2` 请求，没有 `fonts.googleapis.com` |
| 正文对比度 | 文章详情页正文 | 深底浅字，长时间阅读不刺眼；标题与正文层级分明 |
| 链接与焦点 | Tab 键遍历 | 焦点环为橙色且清晰可见，链接悬停变亮绿 |
| 代码块 | 含代码的文章 | 等宽字体、横向可滚动、不撑破容器 |
| 404 | 访问 `/this-page-does-not-exist` | 显示「未找到该世界线」与返回首页链接 |

发现不符时，先确认是不是没重新构建（`pnpm build-only`），再看 `templates/assets/main-*.css` 里对应规则是否生成。

## 常见问题

**构建报 `Cannot find module '@halo-dev/vite-plugin-halo-theme'`** —— 忘了 `pnpm install`。

**装了主题但站点没变化** —— 主题目录名不是 `z-blog-sg`，或没在控制台启用；也可能只跑了 `build-only` 没重新打包上传。

**页面报模板解析错误** —— 大概率用了 Thymeleaf 3.1 已移除的 `#request` / `#response` / `#session` / `#servletContext`。构建期不会报，只有渲染时才炸，所以改模板后一定跑 `preview-test.sh`。
