# docs 目录说明

本目录是 NetBird 仓库的结构化实践手册，按用途分层：

- `selfhosted/`
  - `quickstart-modern.md`：官方推荐安装入口
  - `docker-compose-config-cheatsheet.md`：配置速查（不改脚本）
  - `legacy-zitadel-path.md`：历史兼容路径与迁移说明
  - `combined-container-migration-checklist.md`：旧架构到 `netbird-server` 迁移检查清单

- `cases/`
  - `01-openvpn-replacement.md`：OpenVPN 替代
  - `02-whitelisted-system-access.md`：企业内部白名单系统接入
  - `03-kubernetes-connectivity.md`：K8S 网络打通
  - `04-exit-node-and-proxy.md`：出口与反向代理形态
  - `05-multi-cloud-connectivity.md`：多云互通
  - `06-official-advanced-scenarios.md`：官方推荐高级实践清单

- `operations/`
  - `firewall-and-hardening.md`：端口与安全加固
  - `operations-playbook.md`：日常运维、备份、升级与回滚

建议按以下顺序阅读：

1. `selfhosted/quickstart-modern.md`
2. `cases/*`（按业务场景）
3. `operations/*`
4. `selfhosted/legacy-zitadel-path.md`
