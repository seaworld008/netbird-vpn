# 案例 12：客户端安装、升级与 Setup Key 接入

> 目标：为没有控制台账号的使用者发放一台设备的一年期连接权限，并提供 Windows、macOS、Linux 可直接执行的安装、连接、检查和退出命令。

## 1. 控制台账号和 Setup Key 的区别

普通使用者只需要连接 VPN 时，不必创建 NetBird 管理后台账号。管理员可以创建 Setup Key，并通过 Auto Groups 和 Policies 限定设备权限。

人用设备推荐参数：

| 字段 | 推荐值 |
| --- | --- |
| Name | `person-device-YYYYMMDD` |
| Expires | 1 year |
| Reusable | false |
| Usage limit | 1 |
| Auto Groups | 仅加入该人员需要的访问组 |
| Ephemeral | false |

一次性 Key 只能注册一台设备。Windows 和 macOS 各注册一台时，应创建两把 Key。Setup Key 是凭据，不应写入仓库、工单截图或长期聊天记录；传递后应要求使用者尽快完成注册。

## 2. Windows 安装和连接

从官方 release 下载与你的 CPU 架构匹配的 MSI。生产环境应发放固定版本下载地址，并同时提供 SHA256 校验值。

在管理员 PowerShell 中校验安装包签名：

```powershell
Get-AuthenticodeSignature .\netbird_installer_0.76.3_windows_amd64.msi |
  Format-List Status, StatusMessage, SignerCertificate
Get-FileHash .\netbird_installer_0.76.3_windows_amd64.msi -Algorithm SHA256
```

安装后连接：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" up `
  --management-url "https://netbird.example.com" `
  --setup-key "NBSETUP-EXAMPLE-REPLACE-ME"

& "$env:ProgramFiles\Netbird\netbird.exe" status
& "$env:ProgramFiles\Netbird\netbird.exe" networks list
```

如果安装在其他目录，先定位程序：

```powershell
Get-Command netbird.exe -ErrorAction SilentlyContinue
Get-ChildItem "$env:ProgramFiles" -Filter netbird.exe -Recurse -ErrorAction SilentlyContinue
```

## 3. macOS 安装和连接

命令行安装：

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
```

使用 Setup Key 连接自建管理端：

```bash
sudo netbird up \
  --management-url "https://netbird.example.com" \
  --setup-key "NBSETUP-EXAMPLE-REPLACE-ME"

sudo netbird status
sudo netbird networks list
```

若 `netbird` 不在当前 PATH：

```bash
command -v netbird
sudo /usr/local/bin/netbird status
```

## 4. Linux 安装和连接

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
sudo netbird up \
  --management-url "https://netbird.example.com" \
  --setup-key "NBSETUP-EXAMPLE-REPLACE-ME"
sudo netbird status
sudo netbird networks list
```

服务器自动化接入应使用专用短期 Key、有限 usage limit 和专用 Auto Group，不复用人用 Key。

## 5. 发给使用者的最小模板

```text
NetBird VPN 客户端

管理地址：https://netbird.example.com
Setup Key：NBSETUP-EXAMPLE-REPLACE-ME
有效期：YYYY-MM-DD
授权范围：Git 服务和指定内网主机

注意：此 Key 只能注册一台设备，请不要转发。完成注册后无需登录管理后台。
```

随后附上对应系统的安装、`up`、`status` 三组命令即可。不要把多个平台都塞给不需要的使用者。

## 6. Windows 原地升级

升级前记录状态并备份本机身份：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" version
& "$env:ProgramFiles\Netbird\netbird.exe" status
Copy-Item "C:\ProgramData\Netbird" "C:\ProgramData\Netbird.backup" -Recurse
```

推荐直接安装新版签名 MSI 完成覆盖升级。若旧安装目录或卸载器阻塞升级：

1. 保留 `C:\ProgramData\Netbird` 备份。
2. 卸载旧客户端。
3. 安装新版 MSI。
4. 如果旧卸载器删除了同名 Windows 服务，再执行一次新版 MSI 的 Repair。
5. 启动服务并检查原 Peer 身份是否保持。

```powershell
Get-Service NetBird
Restart-Service NetBird
& "$env:ProgramFiles\Netbird\netbird.exe" version
& "$env:ProgramFiles\Netbird\netbird.exe" status
```

不要先执行 `netbird down --cleanup`，这可能清除本机注册状态并要求新 Key。

## 7. macOS 和 Linux 升级

使用原安装渠道升级，避免同一机器混用包管理器和脚本安装路径：

```bash
netbird version
sudo netbird status
curl -fsSL https://pkgs.netbird.io/install.sh | sh
sudo netbird version
sudo netbird status
```

升级不应重新输入 Setup Key。若客户端要求重新注册，先检查状态目录、服务用户和原配置是否被清除。

## 8. 连接验收

客户端至少验证：

```text
Management: Connected
Signal: Connected
```

再使用真实协议测试授权资源：

Windows：

```powershell
Resolve-DnsName git.example.com
Test-NetConnection 10.20.30.11 -Port 443
curl.exe -I https://git.example.com/
```

macOS / Linux：

```bash
dig +short git.example.com
curl -I --connect-timeout 10 https://git.example.com/
```

管理员还要确认：

- 新 Peer 自动进入预期组，没有进入宽泛管理组。
- 仅两条计划内 Policy 对该组生效。
- 未授权 VPC 主机访问失败。
- 一次性 Setup Key 的 usage 已消耗，随后撤销或删除。

## 9. 常见故障

### Windows Wintun 创建失败

先检查服务和日志，再重启服务同步：

```powershell
Get-Service NetBird
Restart-Service NetBird
& "$env:ProgramFiles\Netbird\netbird.exe" status --detail
```

不要在没有保存身份数据时反复卸载和 cleanup。

### 连接成功但访问不到内网

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" networks list
Get-NetRoute -AddressFamily IPv4 | Sort-Object DestinationPrefix
```

依次检查 Network 选择、资源、Policy、Routing Peer、目标端口和云安全组。不要只测 `ping`。

### Setup Key 无法再次使用

如果它是一次性 Key，这是预期行为。不要把 Key 改为无限复用；为新设备单独创建一把 Key。

## 10. 退出与回收

用户临时断开：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" down
```

```bash
sudo netbird down
```

人员离职或设备丢失时，管理员应禁用/删除 Peer、移出访问组、撤销未使用 Setup Key，并检查 Activity 记录。仅让客户端执行 `down` 不等于权限已回收。

官方参考：

- https://docs.netbird.io/get-started/install
- https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
