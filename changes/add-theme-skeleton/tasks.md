# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
|---|---|---|---|
| 1 | 主题工程可构建打包，配色与字体两条全局约束就位，全部路由模板齐全 | 无 | `bash theme/verify/check-theme.sh` |
| 2 | 本地 Halo 能安装并激活该主题，六类路由渲染出带 SG 标记与页脚声明的页面 | 批次 1 | `bash theme/verify/preview-test.sh` |
| 3 | 每次推送都自动跑部署静态校验与主题构建 | 批次 1 | `bash deploy/verify/static-check.sh --all && bash theme/verify/check-theme.sh` |

## 任务

- [x] **1.1 初始化主题工程**：新建 `theme/`（`package.json`、`vite.config.ts`、`theme.yaml`、`settings.yaml`、`src/` 骨架、`theme/.gitignore`），主题名 `z-blog-sg`；完成后 `theme/dist/` 能产出可安装的 zip；证明：`cd theme && pnpm install && pnpm build`。
- [x] **1.2 定义配色 token**：新建 `theme/src/css/tokens.css`，写入 DR-1 八个原始 token 与语义层变量；完成后其余样式只能用语义变量取色；证明：`bash theme/verify/check-theme.sh --tokens`。
- [x] **1.3 自托管字体**：新建 `theme/src/css/fonts.css`，通过 `@fontsource` 引入 Orbitron / JetBrains Mono / Noto Sans SC（中文用 `chinese-simplified` 子集，`font-display: swap`）；完成后构建产物只引用本地 woff2；证明：`bash theme/verify/check-theme.sh --fonts`。
- [x] **1.4 建立基础布局**：在 `theme/src/partials/layout.html` 写统一骨架（`<slot name="head">` 与 `<slot />` 占位：页头导航、内容区、页脚含 DR-5 声明），并建 `theme/src/partials/` 下的文章卡片与分页片段；在 `theme/src/css/main.css` 写三档断点与窄屏折叠导航；完成后任意模板套用同一骨架；证明：`bash theme/verify/check-theme.sh --layout`。
- [x] **1.5 补齐路由模板**：为首页、文章、独立页、归档、分类、标签、作者与 404 建模板骨架，全部套用统一 layout；完成后构建产物含 10 个路由模板；证明：`bash theme/verify/check-theme.sh --templates`。
- [x] **1.6 编写主题静态校验**：新建 `theme/verify/check-theme.sh`（`--tokens`/`--fonts`/`--layout`/`--templates`/`--docs`/`--all`），断言对象是构建产物而不是源码；证明：`bash theme/verify/check-theme.sh`。
- [x] **1.7 记录主题开发说明**：新建 `theme/README.md`，写构建、打包、安装到本地 Halo、新增模板与新增 token 的约定；证明：`bash theme/verify/check-theme.sh --docs`。
- [ ] **2.1 编写本地预览验证**：新建 `theme/verify/preview-test.sh`，起站、完成 Halo 初始化、安装并激活主题、`curl` 六类路由断言 SG 标记与页脚声明、结束时清理；证明：`bash theme/verify/preview-test.sh`。
- [ ] **2.2 记录视觉走查清单**：在 `theme/README.md` 追加桌面/移动人工走查清单（导航、页脚、正文对比度、无横向溢出、字体是否生效）；证明：`bash theme/verify/check-theme.sh --docs`。
- [ ] **3.1 建立推送校验流水线**：新建 `.github/workflows/ci.yml`，对 push 与 PR 跑 `static-check.sh --all` 与主题 `pnpm install && pnpm build && check-theme.sh`；证明：`bash deploy/verify/static-check.sh --all && bash theme/verify/check-theme.sh`（与 CI 完全相同的命令本地跑通）。

## 实施备注

- 主题名 `z-blog-sg` 必须与 Halo 内的安装目录名一致，`theme-package` 产出的 zip 也按这个名字命名。
- `theme/templates/` 与 `theme/assets/` 是构建产物，不入库；任何预览或安装动作之前都必须先构建。
- 模板语法是 Thymeleaf（`.html`），Halo 2.27 为 Thymeleaf 3.1：不要使用 `#request`/`#response`/`#session`/`#servletContext`，链接用 permalink 或 `settings.yaml` 配置项。
- 所有色值只能出现在 `tokens.css` 中；`check-theme.sh --tokens` 会扫描其余样式里的色值字面量并判失败。
- 本地预览依赖 Halo 实例；本机实例此前从未完成初始化，`preview-test.sh` 需要自带初始化步骤，若接口不可用则退化为一次性人工初始化并在报告里标注。
- 批次 2 的断言必须在主题被激活之后执行，否则拿到的是初始化引导页而不是主题渲染结果。
