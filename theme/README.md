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
│   ├── error/error.html    错误页（Halo 2 要求是 error/error.html，不是顶层 error.html）
│   ├── partials/           构建期片段（不会单独进入产物）
│   │   ├── layout.html     统一骨架：页头 / 内容区 / 页脚 / 动效开关
│   │   ├── post-card.html  文章卡片
│   │   └── pagination.html 分页
│   ├── css/
│   │   ├── tokens.css      DR-1 配色 token + 世界线/动效变量（唯一颜色来源）
│   │   ├── fonts.css       自托管字体引入
│   │   └── main.css        布局与组件样式
│   └── js/
│       ├── main.ts         入口：按序装配各模块
│       ├── logic.mjs       纯逻辑（可被 node 直接单测）
│       ├── worldline.ts    α/β 世界线切换
│       ├── motion.ts       简洁模式
│       ├── divergence.ts   Divergence Meter
│       ├── typewriter.ts   打字机
│       ├── particles.ts    星空粒子
│       └── pointer-glow.ts 鼠标跟随辉光
├── verify/
│   ├── check-theme.sh      静态校验（检查构建产物）
│   ├── unit-logic.mjs      运行层纯逻辑单测（node 直接跑，无需浏览器）
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

体积预算（M2 起，回归时看这三个数）：

| 产物 | M1 基线 | M2 当前 | 增量 |
|---|---|---|---|
| `templates/assets/main-*.js` | 0.67 kB | 7.00 kB（gzip 2.70 kB） | +6.33 kB |
| `templates/assets/main-*.css` | 141.78 kB | 142.36 kB（gzip 59.92 kB） | +0.58 kB |
| `dist/z-blog-sg-<版本>.zip` | 5.48 MB | 5.50 MB | +0.02 MB |

交互层 JS 的预算是 **25 kB**（未压缩），当前 7.00 kB；主题包的体积几乎全部来自中文字体分片，加动效基本不影响下载量。`check-theme.sh --components` 会断言动画只用 `transform`/`opacity` 且时长一律引用 `--motion-*`，避免回归时悄悄引入重排。

## 打包

```bash
cd theme
pnpm build
```

`pnpm build` = `vite build && theme-package`，产出 `theme/dist/z-blog-sg-<版本>.zip`（约 5.5 MB，体积主要来自中文字体分片，可一起打进主题包）。版本号取自 `theme.yaml` 的 `spec.version`。这个 zip 就是分发物，直接上传到 Halo 控制台安装。

## 安装到本地 Halo

两种方式，任选其一：

**方式一：上传 zip（与线上一致）**

1. `cd theme && pnpm build`
2. 打开 `http://localhost:8090/console` → 外观 → 主题 → 安装主题 → 上传 `theme/dist/z-blog-sg-<版本>.zip`
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

## 组件与开关

主题的交互层全部收敛到三个 HTML 属性和一个 settings 分组：`<html data-worldline>`、`<html data-motion>`、`data-motion-source="user"`。服务端先直出正确状态（禁用脚本也能看），脚本只负责接管。

### 设置项

控制台 → 外观 → 主题 → 设置 → **交互与动效**，对应 `settings.yaml` 的 `interaction` 组：

| 设置项 | 键 | 默认 | 作用 |
|---|---|---|---|
| 默认世界线 | `worldline_default` | `beta`（橙红） | 访客首次到访的世界线；`alpha` 为蓝青 |
| 简洁模式默认开启 | `plain_mode_default` | 关 | 打开后首次到访即关闭全部动效 |
| Divergence 数据源 | `divergence_source` | `attractor` | `attractor` = 固定 1.048596%；`live` = 站点真实发布数 |
| 星空粒子背景 | `effects_particles` | 开 | 关掉后不渲染 Canvas 粒子 |
| 鼠标跟随辉光 | `effects_pointer_glow` | 开 | 关掉后不注册 `pointermove` |

三个开关的优先级是固定的，写在 `src/js/logic.mjs` 的 `resolveMotion` / `resolveWorldline` 里，并有单测兜底（`node theme/verify/unit-logic.mjs`）：

1. 访客的手动选择（`localStorage` 的 `sg-motion` / `sg-worldline`）
2. 系统的 `prefers-reduced-motion: reduce`（只影响动效）
3. 主题设置项的默认值

访客一旦手动点过，简洁模式按钮就把 `data-motion-source="user"` 写到 `<html>`，CSS 里那条 `prefers-reduced-motion` 兜底规则随即让位（选择器是 `:root:not([data-motion-source="user"])`）——否则用户明明点了「动效开」，系统偏好却继续把动画压成 0 秒。

### 新增一个动效组件

1. 纯计算放进 `logic.mjs`（或同目录新增 `*.mjs`），由 `verify/unit-logic.mjs` 覆盖；TS 侧只留 DOM 操作。
2. 新模块在 `src/js/main.ts` 里按序装配：`motion` 必须最先，其余模块读它定好的 `data-motion`。
3. `data-motion="off"` 时不得注册 `requestAnimationFrame`，并监听 `sg:motion` 事件做启停（参考 `particles.ts`）。
4. 样式只用 `var(--motion-*)` 与语义色变量；`check-theme.sh --tokens` 会拦下裸色值字面量。
5. 需要服务端直出的状态走模板变量 + `th:attr`；脚本读属性，不读配置（模板里拿不到主题设置之外的上下文）。
6. 在 `check-theme.sh --components` 里加一条断言，保证产物里确实出现了该组件。

## 本地预览验证

`theme/verify/preview-test.sh` 把「起站 → 初始化 → 装主题 → 激活 → 路由断言」串成一条命令，用来在不用手点控制台的情况下确认主题真的能渲染：

```bash
bash theme/verify/preview-test.sh          # 验完停站（保留数据）
bash theme/verify/preview-test.sh --keep   # 验完保持容器运行，方便人工走查
bash theme/verify/preview-test.sh --reset  # 验前先重建实例（换模板后必须这样跑）
bash theme/verify/preview-test.sh --purge  # 验完停站并删除数据卷与 deploy/data
```

- 前提：Docker 已启动、`deploy/` 下的编排可用、`theme/dist/z-blog-sg-<版本>.zip` 已构建。
- 站点未初始化时它会自动初始化，管理员默认 `admin` / `SgPreviewPass1`；可用 `HALO_ADMIN_USER`、`HALO_ADMIN_PASS`、`HALO_ADMIN_EMAIL`、`HALO_SITE_TITLE`、`BASE_URL` 覆盖。Halo 只允许 `A-Z a-z 0-9` 与 `!@#$%^&*` 作为密码字符，默认值里因此不能出现连字符。
- 它断言六类路由（首页、归档、分类、标签、作者、404）返回预期状态码，且每页都含主题骨架标记与 DR-5 页脚声明。
- 想回到「未初始化」状态重来：用 `--reset`（在验证**之前**重建）。`--purge` 是验证**之后**的清理，两者不能互相替代。
- **同一个实例上重复跑会失败**：Halo 没有主题升级接口，同名主题装过之后 `install` 一律返回 `400 主题已存在`，此时继续激活只会验证上一次留下的旧产物。脚本会用模板 sha256 比对，发现不一致就直接报错并提示改用 `--reset`。
- `--reset` 之所以要用一次性容器删 `deploy/data`：那里的文件是容器以 root 写入的，Windows 宿主上 `rm -rf` 会逐个 `Permission denied` 并留下残骸（旧主题目录留着，下次就会装上旧模板）。

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
| 世界线切换 | 点页头 β / α 按钮 | 强调色、链接、边框在橙红与蓝青之间切换，刷新后保持 |
| 简洁模式 | 点页头的「动效 开 / 关」 | 扫描线、粒子、打字机、滚动数字同时停下，刷新后保持；再点能恢复 |
| Divergence Meter | 首页首屏 | 六位数字 + 小数点 + 百分号，橙色辉光；点下方按钮在 1.048596% 与文章数之间滚动切换 |
| 系统减少动效 | 系统开「减少动态效果」后首次访问（先清 `localStorage` 的 `sg-motion`） | 动效默认关闭，但手动点「开」仍然生效 |
| 星空与鼠标辉光 | 桌面端移动鼠标 | 星点缓慢上移，指针附近有微弱辉光；触屏与窄屏不应出现 |

发现不符时，先确认是不是没重新构建（`pnpm build-only`），再看 `templates/assets/main-*.css` 里对应规则是否生成。

## 常见问题

**构建报 `Cannot find module '@halo-dev/vite-plugin-halo-theme'`** —— 忘了 `pnpm install`。

**装了主题但站点没变化** —— 主题目录名不是 `z-blog-sg`，或没在控制台启用；也可能只跑了 `build-only` 没重新打包上传。

**页面报模板解析错误** —— 大概率用了 Thymeleaf 3.1 已移除的 `#request` / `#response` / `#session` / `#servletContext`。构建期不会报，只有渲染时才炸，所以改模板后一定跑 `preview-test.sh`。

**`Could not parse as expression: "dot' : 'sg-divergence"`** —— 表达式里出现了双下划线。Thymeleaf 把 `__` 当作表达式预处理（`__${...}__`）的分隔符，所以 `${ch == '.' ? 'sg-divergence__dot' : 'sg-divergence__digit'}` 会在第一个 `__` 处被截断、后半段当成独立表达式解析。BEM 的 `__` 命名只在普通 `class` 属性里安全；一旦进 `${...}`，改用 `-`（本项目就是 `sg-divergence-digit` / `sg-divergence-dot`）。
