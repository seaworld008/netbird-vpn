# docs 目录说明

本目录是 NetBird 仓库的结构化实践手册，按用途分层：

- `selfhosted/`
  - `quickstart-modern.md`：官方推荐安装入口
  - `upstream-version-status.md`：NetBird 官方最新版本核对记录
  - `docker-compose-config-cheatsheet.md`：配置速查（不改脚本）

- `cases/`
  - `01-openvpn-replacement.md`：OpenVPN 替代，含路由节点、资源、策略、验证和回滚
  - `02-whitelisted-system-access.md`：企业内部白名单系统接入，含单资源单组、后端白名单、授权/非授权验证
  - `03-kubernetes-connectivity.md`：K8S 网络打通、完整 YAML、验证与回滚
  - `04-exit-node-and-proxy.md`：Exit Node、Reverse Proxy、`netbird expose` 临时发布
  - `05-multi-cloud-connectivity.md`：AWS / GCP / Azure 多云互通、云防火墙、分阶段验证
  - `06-official-advanced-scenarios.md`：进阶最佳实践，含策略模型、域名资源、Setup Key、高可用和审计模板

- `operations/`
  - `firewall-and-hardening.md`：阿里云安全组、端口与安全加固
  - `operations-playbook.md`：日常运维、备份、升级、回滚与排障 SOP

建议按以下顺序阅读：

1. `selfhosted/quickstart-modern.md`
2. `selfhosted/upstream-version-status.md`
3. `selfhosted/docker-compose-config-cheatsheet.md`
4. `cases/*`（按业务场景）
5. `operations/*`
