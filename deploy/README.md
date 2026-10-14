# Halo 部署手册

本目录是一套可复现的 Halo + PostgreSQL 编排定义：本地与线上共用同一份基础定义，环境差异全部收敛到 `.env` 与生产叠加层，避免"本地能跑、线上跑不起来"。

## 目录结构

```text
deploy/
├── docker-compose.yml       # 基础编排：halo + halodb，本地与线上共用
├── docker-compose.prod.yml  # 生产叠加层：追加 Caddy 反向代理与 443
├── .env.example             # 变量模板，复制为 .env 后按需修改
├── caddy/Caddyfile          # 反向代理与自动证书配置
├── backup/backup.sh         # 每日备份：数据库转储 + 附件打包
├── verify/
│   ├── static-check.sh      # 静态校验，不依赖 Docker 守护进程
│   └── boot-test.sh         # 启动级验证，真实拉起服务并验证数据落盘
└── data/                    # 运行时数据（已被 .gitignore 排除）
    └── halo2/               # Halo 工作目录：附件、配置、插件
```

PostgreSQL 的数据**不在** `deploy/data/` 里，而是放在命名卷 `sg-blog-halodb-data`（原因见「数据目录」）。

## 前置条件

- Docker Engine 24+ 与 Docker Compose v2（`docker compose version` 可验证）。
- 本地端口 `8090` 未被占用；线上还需要 `80` 与 `443`。
- 首次启动需拉取 `registry.fit2cloud.com/halo/halo:2.27.0` 与 `postgres:15`，约数百 MB。
- 若该镜像库在本机拉取缓慢或停滞，可在 `.env` 里把 `HALO_IMAGE` 换成 Docker Hub 的 `halohub/halo:2.27.0`。两者同源同摘要，只是镜像库不同；`.env` 不入库，属于本机设置。

## 首次启动

```bash
cp deploy/.env.example deploy/.env
# 编辑 deploy/.env，至少把 POSTGRES_PASSWORD 改成强密码
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d
```

首次启动会初始化数据库并创建 Halo 的工作目录，通常需要 30～60 秒。等待就绪：

```bash
curl -f http://localhost:8090/actuator/health/readiness
```

返回 `{"status":"UP"}` 即表示站点已就绪。也可以直接用仓库里的启动级验证脚本代劳（会顺带验证数据落盘）：

```bash
bash deploy/verify/boot-test.sh
```

## 进入 Console

浏览器打开 <http://localhost:8090>，首次访问会引导创建管理员账号。创建完成后进入 Console：<http://localhost:8090/console>。

> 首次创建的管理员账号只存在于数据库里（命名卷 `sg-blog-halodb-data`，见「数据目录」）。删掉这个卷等于丢掉整站，请勿在未备份时执行。

## 查看日志

```bash
docker compose -f deploy/docker-compose.yml --env-file deploy/.env logs -f halo
docker compose -f deploy/docker-compose.yml --env-file deploy/.env logs -f halodb
```

只看最近若干行（排障时更常用）：

```bash
docker compose -f deploy/docker-compose.yml --env-file deploy/.env logs --tail 100 halo
```

## 停止服务

```bash
# 停止并移除容器，数据目录保持不动
docker compose -f deploy/docker-compose.yml --env-file deploy/.env down

# 仅重启 Halo（改了 .env 里的镜像版本后这样最省事）
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d halo
```

`down` 不会删除 `deploy/data/`，也不会删除数据库命名卷 `sg-blog-halodb-data`。若要彻底重置本地环境，需同时删除两者（见「数据目录」）——这是不可恢复操作，务必先备份。

## 数据目录

持久化数据分两处存放，性质不同：

| 位置 | 容器内路径 | 内容 | 存放方式 |
| --- | --- | --- | --- |
| 命名卷 `sg-blog-halodb-data` | `/var/lib/postgresql/data` | 文章、评论、用户、配置 | Docker 命名卷 |
| `deploy/data/halo2/` | `/root/.halo2` | 上传的附件、插件、Halo 本地配置 | 绑定挂载 |

**数据库为什么用命名卷**：PostgreSQL 的 `initdb` 会把数据目录 `chmod` 成 `0700`，而 Windows 上的绑定挂载（DrvFs）不支持 `chmod`，容器会以下面的错误无限重启：

```text
initdb: error: could not change permissions of directory
  "/var/lib/postgresql/data": Operation not permitted
```

命名卷位于 WSL2 的 ext4 上，权限语义与 Linux 服务器一致，因此本地与线上可以共用同一份定义。数据库的备份与迁移本来就走 `pg_dump` / `pg_restore`（见「备份与恢复演练」），不依赖目录拷贝，所以命名卷不会增加运维步骤。

```bash
docker volume inspect sg-blog-halodb-data     # 查看卷的挂载点与元信息
docker volume rm sg-blog-halodb-data          # 彻底删除数据库（不可恢复，先备份）
```

`deploy/data/halo2/` 是绑定挂载，`docker compose down` 后仍在，整目录 `rsync` 即可完成附件迁移。

## 静态校验

不依赖 Docker 守护进程，clone 后即可运行：

```bash
bash deploy/verify/static-check.sh            # 基础编排 + 必备文件
bash deploy/verify/static-check.sh --vars     # 环境变量注入与替换
bash deploy/verify/static-check.sh --eol      # 脚本换行符与 git 属性
bash deploy/verify/static-check.sh --docs     # 本手册章节完整性
bash deploy/verify/static-check.sh --all      # 以上全部（含生产叠加层）
```

提交前建议至少跑一次 `--all`。

---

# 线上部署

线上与本地共用 `docker-compose.yml`，差异只体现在生产叠加层与 `.env`，因此不存在"两份配置各自漂移"的问题。

## 服务器部署

**前置准备**

- 一台 2C2G 及以上的云服务器，Ubuntu 22.04 / Debian 12。
- 安装 Docker Engine 与 Compose 插件，并确认 `docker compose version` 可用。
- 安全组只放行 `22`（限管理 IP）、`80`、`443`；**不要**放行 `8090`。

**部署步骤**

```bash
# 1. 获取代码
git clone <你的仓库地址> /srv/zql-blog && cd /srv/zql-blog

# 2. 生成变量文件并修改三处：POSTGRES_PASSWORD、DOMAIN、HALO_EXTERNAL_URL
cp deploy/.env.example deploy/.env
vi deploy/.env

# 3. 上线前先做静态校验（此时无需 DNS 已生效）
bash deploy/verify/static-check.sh --all

# 4. 启动（基础定义 + 生产叠加层）
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml \
  --env-file deploy/.env up -d
```

`.env` 里与线上相关的三项：

| 变量 | 线上取值 | 说明 |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | 强随机密码 | 只在数据库**首次初始化**时生效，见「故障排查」 |
| `DOMAIN` | 例如 `blog.yourdomain.com` | Caddy 据此申请证书 |
| `HALO_EXTERNAL_URL` | `https://blog.yourdomain.com` | Halo 生成链接与 RSS 时使用，必须带 `https://` |

**升级版本**：只改 `.env` 里的 `HALO_IMAGE`，然后

```bash
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml \
  --env-file deploy/.env up -d halo
```

**Caddy 配置校验**（不需要在服务器上装 caddy）：

```bash
docker run --rm -e DOMAIN="${DOMAIN:-blog.example.com}" \
  -v "$PWD/deploy/caddy:/etc/caddy:ro" caddy:2-alpine \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

> `-e DOMAIN=...` 不能省略：Caddyfile 用 `{$DOMAIN:...}` 读取域名，若变量缺失会退化成默认值；带默认值是为了让独立校验也能通过，线上始终由 compose 注入真实域名。

## 域名与备案

1. **域名解析**：在域名服务商处添加 A 记录，指向服务器公网 IP。`dig +short blog.yourdomain.com` 能返回该 IP 即生效。
2. **ICP 备案**：使用中国大陆节点的服务器必须先完成 ICP 备案（通常 1～3 周）。备案期间可先用香港或海外节点跑通流程，之后再迁移——站点状态就是附件目录 `deploy/data/halo2/` 与数据库卷，迁移时 `rsync` 附件、用 `pg_dump` + `psql` 搬数据库、带上 `.env` 再 `up -d` 即可。
3. **备案与内容一致性**：备案主体、站点名称需与实际内容一致，个人博客按"个人"类型备案即可。
4. **证书申请时机**：Caddy 通过 ACME 自动申请证书，要求 `80`/`443` 已放行**且** DNS 已解析到本机。DNS 未生效就启动 Caddy 会导致反复失败，可能触发 Let's Encrypt 速率限制（每周每域名 5 次失败上限），因此建议解析生效后再启动生产叠加层。
5. **公安备案**：部分省份要求 ICP 备案通过后再做公安联网备案，以当地要求为准。

## 备份与恢复演练

**备份内容**：一次运行同时产出数据库转储与附件压缩包，两者按同一时间戳配对，恢复时必须成对使用。

```bash
bash deploy/backup/backup.sh --dry-run     # 先看会执行什么
bash deploy/backup/backup.sh               # 真实备份
bash deploy/backup/backup.sh --keep 7      # 临时改成保留 7 天
bash deploy/backup/backup.sh --out /srv/halo-backup
```

产物落在 `deploy/backup/out/`（已加入 `.gitignore`）：

- `halo-db-<时间戳>.sql.gz` —— `pg_dump --clean --if-exists` 输出，可由 `psql` 直接重放
- `halo-attachments-<时间戳>.tar.gz` —— `deploy/data/halo2` 整目录，含上传附件、插件与配置

**每日定时**（保留 30 天）：

```bash
crontab -e
# 追加：
30 3 * * * cd /srv/zql-blog && bash deploy/backup/backup.sh >> deploy/backup/out/cron.log 2>&1
```

**上传到对象存储**：在 `.env` 中配置 `COS_UPLOAD_CMD`，备份脚本会把两份产物路径作为参数交给它，例如 `COS_UPLOAD_CMD=coscmd upload`。留空则只保留本地产物。

**恢复演练**（建议每季度做一次，不要等到真出事）：

```bash
# 1. 停站，避免恢复过程中有写入
docker compose -f deploy/docker-compose.yml --env-file deploy/.env down

# 2. 还原数据库（转储自带 DROP/CREATE，可重复执行）
gunzip -c deploy/backup/out/halo-db-<时间戳>.sql.gz | \
  docker compose -f deploy/docker-compose.yml --env-file deploy/.env \
  exec -T halodb psql -U halo -d halo

# 3. 还原附件（归档内顶层就是 halo2/）
tar -xzf deploy/backup/out/halo-attachments-<时间戳>.tar.gz -C deploy/data

# 4. 起站并确认文章、图片、插件都在
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d
curl -f http://localhost:8090/actuator/health/readiness
```

演练时优先在一台临时机器上还原，确认无误再动线上。

## 故障排查

**先看状态与日志**

```bash
docker compose -f deploy/docker-compose.yml --env-file deploy/.env ps
docker compose -f deploy/docker-compose.yml --env-file deploy/.env logs --tail 100 halo
```

| 症状 | 常见原因 | 处理 |
| --- | --- | --- |
| 浏览器访问域名返回 502 | Halo 尚未通过健康检查，Caddy 已就绪 | 看 `halo` 日志；首次启动需 30～60 秒 |
| Halo 容器反复重启 | 数据库连不上，或内存不足 | 确认 `halodb` 是 `healthy`；2C2G 上把 `JVM_OPTS` 调小 |
| `halodb` 反复重启，日志出现 `initdb: ... Operation not permitted` | 数据库数据目录被绑定挂载到 Windows 路径（DrvFs 不支持 `chmod`） | 确认 `docker-compose.yml` 里是 `halodb_data:/var/lib/postgresql/data`，不要改成 `./data/db`；见「数据目录」 |
| 改了 `POSTGRES_PASSWORD` 后连不上数据库 | 该变量只在数据目录**首次初始化**时生效 | 用旧密码改回去；确需改密码就进容器执行 `ALTER ROLE halo PASSWORD '...'`，别删数据目录 |
| 证书申请失败 | DNS 未解析、80/443 未放行，或触发了速率限制 | `docker compose logs caddy`；修好后等待限额窗口重置 |
| `curl localhost:8090` 通、域名不通 | Caddy 没起来 | 确认启动命令带了 `-f deploy/docker-compose.prod.yml` |
| 端口被占用 | 本机已有 8090/80/443 服务 | `ss -ltnp` 找出占用者；Halo 端口只在 `.env` 之外的 compose 文件中定义 |
| `docker compose` 报变量为空 | 漏了 `--env-file deploy/.env` | 补上参数，或用 `bash deploy/verify/static-check.sh --vars` 复查 |
| 脚本报 `\r: command not found` | Windows 检出时被转成 CRLF | 已由 `.gitattributes` 的 `eol=lf` 防住；用 `static-check.sh --eol` 复查 |

**提交或上线前的自检**

```bash
bash deploy/verify/static-check.sh --all      # 静态：语法、变量、EOL、手册
bash deploy/verify/boot-test.sh               # 启动级：真实起站 + 数据落盘验证
```

