# M2 核心组件 —— 整段审查报告

- 变更：`add-core-components`（M2）
- 审查范围：`5c5b5d0fdf0c6612ebef412417014ea279e619e9..f65fc8d`（含复审时的定点修复）
- 审查策略：Native `final`（由执行者本人审查完整 diff，不派子代理）
- 判定：**pass**（首轮 1 项 Important 已定点修复并复审）

## 逐任务核对

| 任务 | 交付 | 核对结论 |
|---|---|---|
| 1.1 | `tokens.css` 增加世界线/动效/效果层变量与 `[data-motion="off"]` 归零 | 齐备；`--motion-*` 全链路引用 |
| 1.2 | `layout.html` 输出 `data-worldline`/`data-motion`、效果层、两个开关、boot 脚本 | 齐备；boot 脚本在 head 内、服务端默认值兜底 |
| 1.3 | `index.html` 的 Divergence Meter（服务端按位直出）与打字机挂载点 | 齐备；`data-value`/`data-live`/`data-source` 均有 |
| 1.4 | `settings.yaml` 五项交互设置 | 齐备；`select`/`checkbox` 格式与官方一致 |
| 1.5 | `check-theme.sh --components` | 齐备；11 项断言，含 motion 变量与钩子 |
| 2.1 | `logic.mjs` + `logic.d.mts` + `unit-logic.mjs` | 齐备；29 项单测通过 |
| 2.2 | `worldline.ts` / `motion.ts` | 齐备；`data-motion-source` 语义正确 |
| 2.3 | `divergence.ts` | **有缺陷，见 I-1** |
| 2.4 | `typewriter.ts` / `particles.ts` / `pointer-glow.ts` | 齐备；均有 motion 状态与降级判断 |
| 2.5 | `main.ts` 装配 + DOMContentLoaded 兜底 | 齐备 |
| 3.1 | `preview-test.sh` 首页 DOM 断言 + 实例重建 | 齐备；30/30 通过 |
| 3.2 | `theme/README.md` 组件与开关文档 | 齐备 |
| 3.3 | 体积/性能抽查 | 齐备；JS 7.00 kB（预算 25 kB） |

## 发现

### I-1（Important，必须修）：客户端重渲染丢失辉光管样式

`theme/src/js/divergence.ts:40-42` 用 BEM 双下划线类名渲染单元：

```ts
if (unit.type === "digit") span.className = "sg-divergence__digit";
else if (unit.type === "dot") span.className = "sg-divergence__dot";
```

而样式表里的选择器已改为单横线（`theme/src/css/main.css:715` 的 `.sg-divergence-digit`、`:721` 的 `.sg-divergence-dot`）——为规避 Thymeleaf 的 `__` 预处理（见 design.md 已知事实）。服务端直出的 HTML 用新类名，所以静态校验与 `preview-test.sh` 全部通过；但 `divergence.ts` 在 `initDivergence()` 末尾无条件 `render(current)`，会立刻把服务端渲染的单元替换成**没有样式的**同名文本，辉光管在首屏 JS 执行后变成裸文字。

这是「静态断言看着对、运行时是错的」典型漏检：`preview-test.sh` 抓的是服务端响应体，抓不到 DOM 被 JS 改写后的结果。

**修复（f65fc8d）**：类名同步为 `sg-divergence-digit` / `sg-divergence-dot`；同时在 `check-theme.sh --components` 增加第 6 条交叉断言——JS 里写死的 `sg-*` 类名必须能在样式表或模板里找到（`sg-worldline`/`sg-motion` 两个 localStorage 键名除外）。负向验证：把类名改回双下划线后 `--components` 立刻报 `通过 11 项，失败 1 项`，改回后恢复 `12/12`；重新构建并 `--reset` 起站后，线上 bundle 含 `sg-divergence-digit`、不含 `sg-divergence__digit`。

### 次要（记录，不阻塞）

- **M-1**：`typewriter.ts` 写入 `data-typing-done` 但无人消费；动效从 off 切回 on 时不会重新播放。属可接受的设计取舍（重播会打断阅读）。
- **M-2**：`pointer-glow.ts` 不监听 `sg:motion`，切到简洁模式后靠 CSS 的 `:root[data-motion="off"] .sg-glow { display:none }` 隐藏，监听器仍在。行为正确，仅多一份无用的 pointermove 回调。
- **M-3**：`particles.ts` 的 `readInk()` 直接读 `--sg-green`（原始层）而非语义层 `--accent`，世界线切换时粒子颜色不跟随。属视觉取舍，已由走查清单覆盖。

## 风险

- **R-1**：视觉正确性无浏览器自动化，只能人工走查（README 11 项清单）。
- **R-2**：CI 只跑 `check-theme.sh` 与构建，不跑 `preview-test.sh`（需要 Docker 与端口，不适合托管 runner）。
- **R-3**：仅在空站点验证过；有文章、有分类、有评论时 hero 与列表的组合未覆盖。

## 验证证据

- `node theme/verify/unit-logic.mjs` → 29 项通过
- `bash theme/verify/check-theme.sh --all` → 38 项通过（含新增的 JS 类名交叉断言）
- `bash theme/verify/check-theme.sh --components` → 12 项通过；负向验证（改回 `__` 类名）→ 11 项通过 1 项失败
- `bash deploy/verify/static-check.sh --all` → 25 项通过
- `bash theme/verify/preview-test.sh --reset --keep` → 30 项通过（首页 200/8521 B，六路由齐备，静态资源 200）
- 线上 bundle 检查：`main-BhABRd8j.js` 含 `sg-divergence-digit`，不含 `sg-divergence__digit`
