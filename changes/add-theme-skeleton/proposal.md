# 变更提案

## 背景（Why）

M0 交付了可复现的运行底座，但站点现在仍是 Halo 默认主题：没有主题工程、没有 Steins;Gate 配色、没有自托管字体，也没有任何自定义模板。需求文档 M1 的验收标准是「默认页面在桌面与移动端可用、配色符合 DR-1」，而 M2 的 Divergence Meter、α/β 双主题、CRT 动效都要挂在这个骨架上，M3 的页面铺开更是逐页替换它的模板。因此先把它做出来：一个可构建、可打包、可安装到 Halo 的最小主题工程，把「配色只有一个来源」和「字体全自托管」这两条全局约束先落到代码里，之后所有视觉工作都只在这套 token 与布局上叠加，不必回头重构。

没有这一层，M2 每做一个组件都要先临时搭一套 CSS 变量与模板回路，M3 则会把结构问题放大到每个页面。

## 变更内容（What Changes）

- 新增 `theme/` 主题工程（Vite + `@halo-dev/vite-plugin-halo-theme`），`pnpm build` 产出可安装的主题包。
- 把 DR-1 的八个配色 token 定义为唯一颜色来源，并补一层语义变量（背景/表面/文字/强调/边框/链接），组件只引用语义变量。
- 自托管 Orbitron / JetBrains Mono / Noto Sans SC 三套字体，构建产物中不出现任何外部字体服务。
- 建立基础布局：页头导航、内容区、页脚（含 DR-5 非官方粉丝作品声明）与三档响应式断点。
- 补齐 Halo 路由模板骨架：首页、文章、独立页、归档、分类、标签、作者与 404。
- 新增两套验证入口：主题静态校验（检查构建产物）与本地预览验证（起站、初始化、安装激活、路由断言）。
- 新增 GitHub Actions，对每次推送跑部署静态校验与主题构建校验。

## 范围（Scope）

### 范围内（In Scope）

- `theme/` 工程初始化：`package.json`、`vite.config.ts`、`theme.yaml`、`settings.yaml`、`src/` 骨架、`theme/.gitignore`。
- `theme/src/css/tokens.css`：DR-1 八个原始 token + 语义层。
- `theme/src/css/fonts.css`、`theme/src/css/main.css`：字体引入、基础排版、布局与断点。
- `theme/src/layout.html` 与 `theme/src/partials/`：页头、页脚、分页、文章卡片。
- `theme/src/` 下的路由模板骨架与 `error.html`（404）。
- `theme/verify/check-theme.sh`、`theme/verify/preview-test.sh`。
- `theme/README.md`：构建、打包、安装、新增模板的约定与人工走查清单。
- `.github/workflows/ci.yml`。

### 范围外（Out of Scope）

- Divergence Meter、CRT 扫描线/辉光/打字机/粒子等动效：属于 M2。
- α/β 世界线双主题切换、简洁模式（Plain Mode）开关：属于 M2。
- 各页面的最终视觉（首页世界线横幅、归档时间轴、研究所徽章、404 终端文案）：属于 M3。
- D-Mail 密码解锁、Artalk 评论、搜索插件、看板娘、umami 统计：属于 M3/M4。
- 域名、服务器、ICP 备案、线上部署与 HTTPS 验收：属于 M0 遗留的外部事项。
- 主题 i18n：需求已定中文为主、不做多语言。
- 真实设备/浏览器自动化视觉走查：本机无浏览器自动化环境，视觉确认由人工在本地实例完成。

## 影响与验证

- **影响区域**：仓库根新增 `theme/` 与 `.github/workflows/`；`deploy/` 的编排与既有三份文档不改动；本地预览需要 Halo 实例运行，但不需要域名或服务器。
- **完成证明**：
  - `bash theme/verify/check-theme.sh` 通过：主题包可构建，八个 token 齐全，构建产物不含外部字体服务，模板齐全，三档断点存在，页脚声明存在。
  - `bash theme/verify/preview-test.sh` 通过：本地起站后主题被安装并激活，首页/归档/分类/标签/文章详情/不存在的路径均返回预期响应，且每个响应都含页头导航与页脚声明。
  - CI 在首次推送后运行成功（与本地同一组命令）。
