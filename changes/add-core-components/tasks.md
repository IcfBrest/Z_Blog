# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
| --- | --- | --- | --- |
| 1 | 世界线与简洁模式的样式层、骨架挂载点、首页辉光管 hero、五项设置项与 `--components` 断言就绪 | 无 | `bash theme/verify/check-theme.sh --components` |
| 2 | 运行时模块就绪：纯逻辑有 node 单测，世界线/简洁模式/辉光管/打字机/粒子全部接线 | 批次 1 | `node theme/verify/unit-logic.mjs` |
| 3 | 端到端 DOM 断言、组件文档与体积/性能抽查完成 | 批次 2 | `bash theme/verify/preview-test.sh` |

## 任务

- [x] **1.1 扩展 token 语义层**：在 `theme/src/css/tokens.css` 增加 `[data-worldline="alpha"]` 与 `[data-worldline="beta"]` 两组强调色映射（各含 `--accent`、`--link`、`--border`）、`--motion-fast`/`--motion-base`/`--motion-slow` 时长变量、以及 `[data-motion="off"]` 与 `prefers-reduced-motion` 的时长归零块；完成后世界线切换只靠改一个属性即可换色。证明：`bash theme/verify/check-theme.sh --tokens`。
- [x] **1.2 改造骨架挂载点**：在 `theme/src/partials/layout.html` 的 `<html>` 上输出服务端默认 `data-worldline`/`data-motion`，加入世界线切换按钮、简洁模式开关、全屏扫描线层、粒子画布容器、首页辉光管挂载点与首屏 boot 内联脚本；完成后任一页面的 HTML 都带齐这些标记。证明：`bash theme/verify/check-theme.sh --components`。
- [x] **1.3 改造首页 hero**：把 `theme/src/index.html` 的 hero 换成 Divergence Meter（六位小数 + `%` 按位拆分，`data-value` 输出服务端初值）、`El Psy Kongroo.` 打字机文本与数据源切换控件；完成后首页 hero 渲染辉光管数值而非纯文字。证明：`bash theme/verify/check-theme.sh --components`。
- [x] **1.4 增加主题设置项**：在 `theme/settings.yaml` 的 `basic` 分组加入 `worldline_default`（select：beta/alpha）、`plain_mode_default`（checkbox）、`divergence_source`（select：attractor/live）、`effects_particles`（checkbox）、`effects_pointer_glow`（checkbox），并把 `theme/theme.yaml` 版本升到 1.1.0；完成后管理员可在 Console 看到并修改这五项。证明：`bash theme/verify/check-theme.sh --components`。
- [x] **1.5 新增组件断言**：在 `theme/verify/check-theme.sh` 增加 `--components` 子命令，断言世界线三变量双套覆盖、`data-motion` 禁用块与 `prefers-reduced-motion`、扫描线与粒子层标记、辉光管挂载点、两个切换控件、五项设置项及其默认值、以及全站 CSS 不出现裸时长字面量（只放行 `tokens.css` 的 `--motion-*` 定义）；完成后静态层回归可自动判定。证明：`bash theme/verify/check-theme.sh --components`。
- [x] **2.1 落地纯逻辑与单测**：新建 `theme/src/js/logic.mjs`（`resolveWorldline`、`resolveMotion`、`formatDivergence`、`padDigits`）与 `theme/verify/unit-logic.mjs`，覆盖非法存储值、系统偏好与手动覆盖优先级、空站点 `0.000000`、补零与拆分位数；完成后交互决策不依赖浏览器即可验证。证明：`node theme/verify/unit-logic.mjs`。
- [x] **2.2 接线世界线与简洁模式**：新建 `theme/src/js/worldline.ts` 与 `theme/src/js/motion.ts`，读写 `localStorage`（全部 `try/catch`）、翻转 `<html>` 属性、同步控件 `aria-pressed` 与文案；完成后点按钮立即换色/停动效且刷新保持。证明：`cd theme && pnpm build`。
- [x] **2.3 实现辉光管组件**：新建 `theme/src/js/divergence.ts`，按位渲染六位小数与 `%`、播放滚动数字动画、在两种数据源间切换并更新 `aria-label`；简洁模式下直接显示终值；完成后首页数值可交互切换。证明：`cd theme && pnpm build`。
- [x] **2.4 实现打字机与粒子**：新建 `theme/src/js/typewriter.ts`、`theme/src/js/particles.ts`、`theme/src/js/pointer-glow.ts`，按 `devicePixelRatio` 上限 2 与视口宽度/指针类型降级，简洁模式下不启动；完成后 hero 文本逐字出现、背景有星点、桌面端有跟随辉光。证明：`cd theme && pnpm build`。
- [x] **2.5 组装与降级收口**：在 `theme/src/js/main.ts` 按模块装配各动效、尊重 `data-motion` 状态、在 `matchMedia` 变化时重算，并保证无 JS 时页面结构完整；完成后模块互不重复绑定事件。证明：`bash theme/verify/check-theme.sh --components`。
- [x] **3.1 扩展端到端断言**：在 `theme/verify/preview-test.sh` 增加首页 DOM 断言（`data-worldline`、`sg-divergence`、`sg-scanline`、世界线与简洁模式控件、设置项默认值生效），并把组件的 JS/CSS 资源 200 纳入检查；完成后预览验证同时覆盖交互层。证明：`bash theme/verify/preview-test.sh`。
- [x] **3.2 补组件文档与走查项**：在 `theme/README.md` 增加「组件与开关」章节（四个组件的作用、两个开关、五项设置项、CSP 注意事项）并在人工走查清单加入世界线切换与简洁模式两项；完成后新人能按文档验证交互。证明：`bash theme/verify/check-theme.sh --docs`。
- [x] **3.3 抽查体积与性能**：记录构建产物的 JS/CSS 增量（目标 < 25 KB）与主题包总大小，断言动画只作用于 `transform`/`opacity` 且无裸时长，把测量结果写入 `theme/README.md` 的构建产物说明；完成后可回归性能预算。证明：`bash theme/verify/check-theme.sh --all`。

## 实施备注（仅在必要时）

- `--components` 目前不存在，由 1.5 引入；1.2、1.3、1.4 的证明依赖它，因此批次 1 的证明应在 1.5 完成后统一跑一次。
- 新增断言必须**追加**到 `check-theme.sh`，不得改写 M1 已有的 25 项（`--tokens`/`--fonts`/`--layout`/`--templates`/`--docs`），否则会掩盖既有回归。
- 内联 boot 脚本要避免出现 `</script>` 字面量，写成单行或拆分字符串；`localStorage` 访问一律 `try/catch`。
- 辉光管的初值由模板直出（`data-value`），JS 只负责过渡，保证无 JS 时数值正确。
- 空站点 `live` 数据源显示 `0.000000` 是既定行为，不要为了好看伪造数字。
- 动画时长只允许引用 `--motion-*`；确实需要例外时在 `check-theme.sh` 里加白名单并写明理由。
