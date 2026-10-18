
## cwd 警告（ensure-branch 自动写入）

- 隔离上下文：`D:\WorkProject\Zql_Blog`
- Bash cwd 不持续：每条命令都会回到会话初始目录，不会记住上一次的 cd
- 强制规则：后续实现编辑必须使用隔离上下文内的绝对路径，或每条命令以前缀 `cd D:\WorkProject\Zql_Blog &&` 开头
