# 设计

## 已知事实与约束

- `theme/src/css/tokens.css` 已有原始 token、派生值与语义层（`--accent`/`--link`/`--border` 等），文件末尾已有 `:root[data-worldline="beta"]` 三行占位，只重映射 `--accent`、`--link`、`--border`。世界线切换只需在这一层扩展，不必改任何组件样式。
- `theme/src/partials/layout.html` 的 `<script type="module" src="/js/main.ts">` 用绝对路径：include 会把骨架内联进各路由模板，相对路径会按「使用方模板的目录」解析（M1 实测 `./js/main.ts` 在 `error/error.html` 下构建失败）。
- 骨架里 `<slot name="head">` 位于 `<head>` 开头，其后才是脚本标签；放在 slot 之外、head 常规位置的标签对所有页面生效。
- `theme/settings.yaml` 现有 `basic` 分组只有 `custom_footer`。官方表单格式用 `$formkit: select`（`options: [{label, value}]`）与 `$formkit: checkbox`（`value: true/false`），分组用 `- group: <id>` + `label`。
- Halo 用服务端 Thymeleaf 渲染，模板里可读 `theme.config.basic.<设置名>`，因此「无 JS 时按默认值渲染」可以直出属性，不需要客户端兜底。
- 本机没有 Playwright 一类的浏览器自动化，视觉正确性只能由 `preview-test.sh` 的 DOM 断言 + README 人工走查清单覆盖。
- Canvas 粒子与鼠标辉光在移动端耗电明显，必须按指针类型与视口宽度降级。
- **Thymeleaf 的 `__` 是表达式预处理分隔符**：`${ch == '.' ? 'sg-divergence__dot' : 'sg-divergence__digit'}` 会在第一个 `__` 处被截断，渲染期报 `Could not parse as expression: "dot' : 'sg-divergence"`（构建期完全正常，只有真实渲染才炸）。BEM 的 `__` 只能出现在普通 `class` 属性里，进 `${...}` 必须换成 `-`；本实现因此用 `sg-divergence-digit` / `sg-divergence-dot`。
- **同名同版本的重复安装不会更新模板**：Halo 没有主题升级接口，`install` 对已存在主题返回 `400`，继续激活只会渲染上一次留下的文件。`preview-test.sh` 因此比对安装目录与本地 `templates/index.html` 的 sha256，不一致就报错并要求用新增的 `--reset` 重建实例。
- **`deploy/data` 删不掉**：其中的文件由容器以 root 写入，Windows 宿主上 `rm -rf` 会逐个 `Permission denied` 并在中断后留下残骸；`--reset`/`--purge` 改用一次性 root 容器删除。
- **全新数据卷上 `compose up -d` 只「创建」不「启动」halo**：compose 判定依赖未就绪就返回非零，之后重复 `up -d` 也不会把它拉起来（实测空等 300s）。`preview-test.sh` 因此先单独起并等待 `halodb` healthy，再起 halo。

## 目标与非目标

**目标**

- 世界线、简洁模式、Divergence Meter、CRT 动效四项能力在首页与全部页面可用。
- 默认值符合「硬核 CRT 全浸入 + 简洁模式可一键关闭」的既定决策，且都能被主题设置项改写。
- 交互决策逻辑可用 `node` 单测，不依赖浏览器。

**非目标**

- 不接入访客数/评论数等真实统计数据（等 M4 的 umami）。
- 不做页面级布局改造（M3）。
- 不做浏览器视觉回归自动化。

## 决策（Decisions）

### 决策：世界线用 `<html data-worldline>` 属性 + 语义层重映射

**选择**：`data-worldline="alpha|beta"` 只改 token 语义层的少数变量，组件样式完全不感知世界线。

**理由**：语义层已是唯一取色入口（DR-1 的既有约束），在属性选择器里重映射 `--accent`/`--link`/`--border` 等于一行切换全站配色；属性比 class 更容易被设置项驱动、被测试断言。

**替代方案**：两套独立样式表按需切 `<link>` —— 会重复全部组件规则且切换必然闪烁；`body.alpha` class —— 与属性等价，但测试与模板接线更啰嗦。

**后果**：世界线只能影响语义层覆盖到的颜色，任何写死色值的组件都会切换失效。因此 `--components` 必须断言 `[data-worldline]` 块内 `--accent`/`--link`/`--border` 三个变量都存在。

### 决策：动效用单个 `data-motion` 开关，CSS 一处禁用

**选择**：`<html data-motion="on|off">`；`[data-motion="off"]` 内把动效时长变量置 0 并隐藏扫描线与粒子层；`@media (prefers-reduced-motion: reduce)` 提供等价规则，JS 失效时也生效。

**理由**：动效散布在扫描线、粒子、打字机、数字滚动多处，逐处判断开关必然漏；单点关闭 + 统一时长变量才能兑现 DR-3 的「一键关闭全部动效」。

**替代方案**：JS 逐个增删 class —— 首屏渲染到脚本执行之间的动效挡不住；`body.no-motion` class —— 等价但语义更弱。

**后果**：所有新增动效必须使用 `--motion-*` 变量；裸写时长的规则会被 `--components` 判失败（只放行 `tokens.css` 里的变量定义）。

### 决策：首屏内联 boot 脚本回放偏好，避免闪烁

**选择**：`layout.html` 的 `<head>`（slot 之外）放一段内联脚本，同步读 `localStorage` 后写下 `data-worldline`/`data-motion`；服务端已渲染的默认属性作为兜底。

**理由**：若把切换放进 `main.ts`，首屏会先按默认世界线绘制再跳变（FOUC）；内联脚本在 CSS 生效前执行，视觉上无闪烁。

**替代方案**：只靠服务端默认值不记忆 —— 违反需求；用 cookie 让服务端直出 —— Halo 模板读自定义 cookie 麻烦且增加后端耦合。

**后果**：主题包含内联脚本，严格 CSP 需放行 `'unsafe-inline'` 或改用 nonce；脚本必须用 `try/catch` 包住 `localStorage`（隐私模式会抛异常）。

### 决策：Divergence Meter 只有 attractor 与 live 两种数据源

**选择**：`attractor` 固定 `1.048596`；`live` 用 `posts.total`（服务端渲染进 `data-value`）。访客数与评论数留到 M4。

**理由**：M2 没有任何统计接入，凭空造数字违反「数据必须真实」的诚实原则；文章数是页面本来就有的可信数据。

**替代方案**：硬编码几个假数值轮播 —— 视觉更热闹但会误导访客；干脆等 M4 —— 但 M2 验收要求组件可用。

**后果**：`live` 模式在空站点显示 `0.000000`，需要单测明确覆盖这个边界，README 也要写明。

### 决策：运行时逻辑抽成 `logic.mjs` 纯函数，用 node 单测

**选择**：`resolveWorldline`、`resolveMotion`、`formatDivergence`、`padDigits` 等纯函数放 `theme/src/js/logic.mjs`，由 `theme/verify/unit-logic.mjs` 用 `node` 断言；`.ts` 模块只负责 DOM 与存储副作用。

**理由**：本机与 CI 都没有浏览器；纯函数能毫秒级验证边界（无效存储值、`prefers-reduced-motion`、空站点、补零）。

**替代方案**：jsdom/Playwright 测 DOM —— 数百 MB 依赖且 CI 需要浏览器；把逻辑写死在 `.ts` 里只做构建期检查 —— 等于没测。

**后果**：必须守住边界：`.ts` 不做决策、`logic.mjs` 不碰 `document`。`unit-logic.mjs` 用动态 `import()` 加载 `.mjs`，避免给 `theme/package.json` 加 `"type": "module"` 而影响 Vite 构建。

## 风险与验证

- **R-1 内联脚本与 CSP**：严格 CSP 会拦内联脚本。验证：`preview-test.sh` 断言 HTML 里已含服务端默认属性（脚本被拦也有正确外观），README 记明需放行。
- **R-2 动效影响性能**：粒子与辉光在低端设备可能掉帧。验证：`--components` 断言动画只作用于 `transform`/`opacity`；粒子密度按 `devicePixelRatio` 上限 2 截断，宽度 < 768px 或 `pointer: coarse` 时不启用鼠标辉光。
- **R-3 简洁模式关不干净**：新增动效若绕过统一变量会漏关。验证：`--components` 扫描裸时长字面量，只放行 `tokens.css` 里的 `--motion-*` 定义。
- **R-4 localStorage 不可用**：隐私模式抛异常。验证：单测覆盖空值与非法值分支；`.ts` 读写全部 `try/catch`。
- **R-5 两个属性互相干扰**：都在 `<html>` 上，选择器可能打架。验证：两者都写成同级属性选择器，禁用规则用后代选择器覆盖，不依赖样式表顺序。
