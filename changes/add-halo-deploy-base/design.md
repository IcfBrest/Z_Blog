# 技术设计

## 已知事实与约束

- Halo 最新稳定版为 `v2.27.0`（2026-10-14 发布，`halo-dev/halo` 的 latest release 实测）；官方 Docker Compose 文档给出的 Halo + PostgreSQL 组合使用 `postgres:15.4`，健康检查端点为 `/actuator/health/readiness`，容器内工作目录为 `/root/.halo2`。
- Halo 社区版镜像有两处官方来源：Docker Hub `halohub/halo` 与国内镜像库 `registry.fit2cloud.com/halo/halo`。
- 目标服务器为腾讯云轻量 2 核 2G：JVM 与 PostgreSQL 共享这 2G 内存。
- 域名尚未购买、国内节点是否备案未定（需求文档风险 R1），因此配置里不得写死域名或证书路径。
- Halo 的数据库连接通过启动参数传入：`--spring.r2dbc.url`、`--spring.r2dbc.username`、`--spring.r2dbc.password`、`--spring.sql.init.platform`、`--halo.external-url`。
- 本机 Docker 为 28.4.0 / Compose v2.39.2-desktop.1，使用 WSL2 后端；守护进程需在完全访问权限下启动 Docker Desktop 才会就绪。Windows 侧配置了 `127.0.0.1:29290` 代理，而 Docker Desktop 的代理设置为空，因此引擎流量是直连的：本机实测 `alpine:3.20`（约 3.4 MB）拉取耗时 72 秒。
- 本机实测镜像库差异：`postgres:15`（628 MB）与 `halohub/halo:2.27.0` 可从 Docker Hub 完整拉取，而 `registry.fit2cloud.com/halo/halo:2.27.0` 在最后一层（`9d8d42fbc560`，53.1 MB）停滞后长时间零进度；两者层摘要一致，可共享本地缓存。
- Windows 上的绑定挂载（DrvFs）不支持 `chmod`：PostgreSQL 的 `initdb` 要求把数据目录置为 `0700`，绑定挂载该目录会让容器以 `initdb: error: could not change permissions of directory "/var/lib/postgresql/data": Operation not permitted` 无限重启（启动级验证实测）。

## 目标与非目标

- **目标**：一套可复现、可移植、可被后续变更扩展的部署底座；本地与线上同源；静态可验证，无需先有服务器。
- **非目标**：主题与页面开发、插件安装与配置、统计接入、备案与域名办理、对象存储生命周期策略。

## 决策（Decisions）

### 决策：镜像版本固定为 Halo 2.27.0 + PostgreSQL 15

- **选择**：`registry.fit2cloud.com/halo/halo:2.27.0`，数据库 `postgres:15`。
- **理由**：镜像库由 Halo 官方提供，国内拉取稳定且与 Docker Hub 同源；Halo 固定到补丁号，保证任何一台机器拉到的都是同一版本，便于复现问题；PostgreSQL 取主版本标签，与官方示例同主版本（15）的同时继续获得安全补丁。
- **替代方案**：Docker Hub `halohub/halo`（国内拉取易超时）；`postgres:15.4`（与官方示例完全一致，但停留在 2023 年的补丁级，不再获得安全修复）；`postgres:16`（可用，但偏离官方已实测组合，出问题时缺少对照）。
- **后果**：Halo 升级需要显式修改 `.env` 中的版本号；数据库主版本升级需要走 `pg_dump`/`pg_restore` 迁移而不是直接换镜像。本机实测该国内镜像库会停滞，因此 `.env` 中的 `HALO_IMAGE` 就是逃生口：本机与海外节点可改用 Docker Hub 的 `halohub/halo:2.27.0`（同源同摘要），手册已写明。

### 决策：反向代理用 Caddy 2，作为生产叠加层中的服务

- **选择**：`deploy/caddy/Caddyfile` + `docker-compose.prod.yml` 中的 `caddy` 服务。
- **理由**：Caddyfile 四行即可完成自动申请与续期证书、gzip 压缩与反代，2C2G 机器上比 Nginx + certbot 少一个常驻进程与一套定时任务；域名用 `{$DOMAIN}` 注入，未购域名时静态校验依旧可跑。
- **替代方案**：Nginx（官方示例提供 upstream 片段，生态更熟，但需要自己维护 certbot 续期与 reload）；Traefik（更适合多服务与动态路由，对单站点过重）。
- **后果**：证书签发要求 80/443 可达且 DNS 已正确解析；手册中保留 Nginx 等价片段作为退路，用户若已有 Nginx 习惯可以只取其中的 `proxy_set_header` 组合。

### 决策：附件用绑定挂载 `deploy/data/halo2`，数据库用命名卷 `sg-blog-halodb-data`

- **选择**：Halo 的 `/root/.halo2` 用绑定挂载 `deploy/data/halo2`；PostgreSQL 的 `/var/lib/postgresql/data` 用命名卷 `sg-blog-halodb-data`（卷名固定，便于备份与排障时辨认）。
- **理由**：附件是普通文件，绑定挂载让备份脚本可以直接打包、迁移时整目录 `rsync`；数据库则必须用命名卷——启动级验证实测，把数据目录绑定挂载到 Windows 路径时 `initdb` 会失败并让容器无限重启：
  `chmod: changing permissions of '/var/lib/postgresql/data': Operation not permitted`，
  `initdb: error: could not change permissions of directory "/var/lib/postgresql/data": Operation not permitted`。
  根因是 Windows 绑定挂载（DrvFs）不支持 `chmod`，而 `initdb` 需要把数据目录置为 `0700`；命名卷位于 WSL2 的 ext4 上，权限语义与 Linux 服务器一致，于是本地与线上仍能共用同一份基础定义。
- **替代方案**：两者都用绑定挂载（本变更最初的选择，实测在 Windows 上不可用）；把数据库目录放到 Linux 路径或改用 `PGDATA` 子目录再预置属主（可行，但依赖宿主环境，与“本地线上同源”的目标冲突）；数据库也用绑定挂载、只在文档里标注“仅 Linux 可用”（把环境差异推给使用者）。
- **后果**：`.gitignore` 仍需覆盖 `deploy/data/`；数据库的备份与迁移只能走 `pg_dump` / `pg_restore` 而不能拷贝目录——这与 `deploy/backup/backup.sh` 的实现一致；`boot-test.sh` 的数据留存断言改为在容器内读取 `/var/lib/postgresql/data/PG_VERSION`，`--purge` 会显式删除该命名卷。

### 决策：JVM 上限外置，默认 `-Xmx512m -Xms256m`

- **选择**：`JVM_OPTS` 写入 `.env`，默认值高于官方示例。
- **理由**：官方默认堆上限为 256m，而 M4 还要加上搜索与评论插件，256m 在插件加载与索引构建时容易触发频繁 GC；512m 上限给插件留出余量，同时把下限压到 256m 避免一启动就占满。
- **替代方案**：沿用官方默认 256m（更保守，插件增多后可能不足）；不限制堆（2C2G 上会与 PostgreSQL 争抢内存）。
- **后果**：需要与 PostgreSQL 共享 2G 内存，部署后应按实际占用回调；手册中给出查看容器内存占用的命令。

### 决策：批次 1 的基础定义为唯一真相，生产差异靠叠加层与 `.env`

- **选择**：`docker-compose.yml`（基础）+ `docker-compose.prod.yml`（叠加）+ `.env`（参数）。
- **理由**：本地与线上同源，避免两套配置各自漂移；反向代理与 80/443 暴露只在生产出现，本地不占用特权端口。
- **替代方案**：本地与线上各维护一份 compose（初期简单，后续必然漂移）；把所有差异塞进基础定义并用 profile 切换（配置会变得难读）。
- **后果**：所有生产命令都必须同时传两个 `-f`，这一组合已固化进 `deploy/README.md` 与验证脚本，避免手工敲错。

## 风险与验证

- **域名与备案未定（R1）** → 域名与外部地址全部走 `.env` 变量注入 → 验证证据：`bash deploy/verify/static-check.sh --vars` 确认输出中不含未替换的 `${`。
- **本机 Docker 守护进程未运行** → 静态校验不依赖守护进程，启动级验证单独成脚本 → 验证证据：`bash deploy/verify/static-check.sh` 始终可跑；`bash deploy/verify/boot-test.sh` 在 Docker Desktop 启动后跑出健康检查与数据留存结果。
- **备份脚本只有在容器运行时才能端到端验证** → `--dry-run` 覆盖参数拼装与保留策略清理逻辑，真实转储在 Docker 可用时执行 → 验证证据：`bash deploy/backup/backup.sh --dry-run` 输出将被清理的文件清单，真实运行时用 `pg_restore --list` 读取产物。
- **2C2G 内存不足** → JVM 上限外置 → 验证证据：`docker stats --no-stream` 观察两个容器的常驻内存，超限则下调 `JVM_OPTS`。
