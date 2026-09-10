# 案例 12：客户端安装、升级与 Setup Key 接入

> 目标：为没有控制台账号的使用者发放一台设备的一次性注册凭据，明确计划使用期与回收点，并提供 Windows、macOS、Linux 可直接执行的安装、连接、检查和退出命令。

> 本文是可复制的操作与验收清单，不代表本仓库已经在真实终端或生产环境完成部署验证。

## 1. 最终效果

完成后应达到：

- 使用者无需 NetBird Dashboard 账号，即可用一把 One-off Setup Key 注册一台设备。
- Windows、macOS 或 Linux 客户端连接到指定自建 Management URL，并只进入计划内 Auto Group。
- 授权设备能通过真实 TCP / HTTPS 访问指定资源，非授权设备不能通过 NetBird 获得同等访问。
- Setup Key 只用于首次注册；升级和普通重启继续使用原 Peer 身份，不重复注入 Key。
- 需要一年使用期时，由管理员单独记录权限复核 / 回收日期；不把 Setup Key 过期时间误当成已注册 Peer 的访问期限。
- 人员离职、设备丢失或升级失败时，有明确的控制面撤权、客户端回退和验证入口。

## 2. 上线前检查

管理员先确认：

- Management URL、TLS 证书和客户端下载地址来自可信渠道。
- 已创建最小权限 Auto Group、Resource 和 Policy，没有把人员设备加入 `All` 或管理组。
- 每台人员设备使用单独的 One-off Key，usage limit=`1`；One-off 不配置大于 `1` 的上限。
- 已登记设备负责人和权限复核 / 回收日期；到期动作是处理 Peer、组或 Policy，不是只等待 Key 过期。
- 已记录授权目标的域名、IP、协议和端口，并准备一台不在授权组的 Peer 做拒绝测试。
- Windows 使用 v0.78.1 的固定 MSI 地址和官方 SHA256；macOS / Linux 明确原安装渠道。
- 升级已有设备前，已记录 Peer 名称、NetBird IP、客户端版本、路由、DNS 和身份目录备份。
- 已定义失败停止条件：Management / Signal 未连接、Peer 进入错误组、非授权设备可访问或无关网络回归时停止扩大范围。

使用者上线前确认：

- 客户端 LAN、其他 VPN、Docker 网段与目标私网不重叠。
- 本机时间正确，HTTPS 能访问 Management URL。
- Setup Key 通过安全渠道收到，注册后不保留在脚本、Shell 历史、截图或聊天记录中。

## 3. 控制台账号和 Setup Key 的区别

普通使用者只需要连接 VPN 时，不必创建 NetBird 管理后台账号。管理员可以创建 Setup Key，并通过 Auto Groups 和 Policies 限定设备权限。

人用设备推荐参数：

| 字段 | 推荐值 |
| --- | --- |
| Name | `person-device-YYYYMMDD` |
| Expires | 尽可能短的注册窗口，例如 24 小时 |
| Reusable | false |
| Usage limit | 1 |
| Auto Groups | 仅加入该人员需要的访问组 |
| Ephemeral | false |

一次性 Key 只能注册一台设备。Windows 和 macOS 各注册一台时，应创建两把 Key。Setup Key 是凭据，不应写入仓库、工单截图或长期聊天记录；传递后应要求使用者尽快完成注册。

`Expires` 只限制还能否用 Key 注册新 Peer，不会让已注册设备在该日期自动断开。若
业务要求“一年使用期”，应在资产台账或权限治理流程中单独记录回收日期，并在到期
时删除 / 禁用 Peer、移出访问组或调整 Policy。

NetBird v0.77.1 起，Public API 会拒绝 One-off 与 `usage_limit > 1` 的组合并返回
HTTP `422`。需要批量注册服务器或 Runner 时，使用短期、有限次数的 Reusable
Key，参见 [用 Setup Key 做自动化接入](09-automation-with-setup-keys.md)。

## 4. Windows 安装和连接

从官方 release 下载与你的 CPU 架构匹配的 MSI。生产环境应发放固定版本下载地址，并同时提供 SHA256 校验值。

在管理员 PowerShell 中校验安装包签名：

```powershell
$Msi = ".\netbird_installer_0.78.1_windows_amd64.msi"
Get-AuthenticodeSignature $Msi |
  Format-List Status, StatusMessage, SignerCertificate

$Release = Invoke-RestMethod `
  "https://api.github.com/repos/netbirdio/netbird/releases/tags/v0.78.1"
$Asset = $Release.assets |
  Where-Object { $_.name -eq "netbird_installer_0.78.1_windows_amd64.msi" }
$Asset | Select-Object name, digest, browser_download_url

$ExpectedHash = $Asset.digest -replace "^sha256:", ""
$ActualHash = (Get-FileHash $Msi -Algorithm SHA256).Hash.ToLowerInvariant()
if (-not $ExpectedHash -or $ActualHash -ne $ExpectedHash) {
  throw "NetBird MSI SHA256 mismatch"
}
```

只有签名状态为 `Valid`，且 SHA256 与 v0.78.1 官方 Release API 的 asset digest
一致时才安装。当前 amd64 MSI 的预期值为
`sha256:91fdc2bc4ecd45e0a3773ac06587edb023d64f138dadcc1bb672d14de842cbc5`。
`netbird_0.78.1_checksums.txt` 不包含 MSI，不能用它代替上面的 asset digest 核对。

安装后连接：

```powershell
$SecureSetupKey = Read-Host "NetBird Setup Key" -AsSecureString
$SetupCredential = [pscredential]::new("netbird", $SecureSetupKey)
try {
  $env:NB_SETUP_KEY = $SetupCredential.GetNetworkCredential().Password
  & "$env:ProgramFiles\Netbird\netbird.exe" up `
    --management-url "https://netbird.example.com"
} finally {
  Remove-Item Env:NB_SETUP_KEY -ErrorAction SilentlyContinue
  $SetupCredential = $null
  $SecureSetupKey.Dispose()
}

& "$env:ProgramFiles\Netbird\netbird.exe" status
& "$env:ProgramFiles\Netbird\netbird.exe" networks list
```

Setup Key 只存在于当前 PowerShell 进程及 `netbird up` 子进程的环境中，不会进入
命令历史或命令行参数；完成后立即清理。仍应在受控终端执行，因为本机管理员可以
检查其他进程。

如果安装在其他目录，先定位程序：

```powershell
Get-Command netbird.exe -ErrorAction SilentlyContinue
Get-ChildItem "$env:ProgramFiles" -Filter netbird.exe -Recurse -ErrorAction SilentlyContinue
```

## 5. macOS 安装和连接

命令行安装：

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
```

使用 Setup Key 连接自建管理端：

```bash
SETUP_KEY_FILE="$(mktemp)"
cleanup_setup_key() {
  rm -f "$SETUP_KEY_FILE"
  unset NETBIRD_SETUP_KEY
}
trap cleanup_setup_key EXIT HUP INT TERM
chmod 600 "$SETUP_KEY_FILE"

read -rsp 'NetBird Setup Key: ' NETBIRD_SETUP_KEY
printf '\n'
printf '%s' "$NETBIRD_SETUP_KEY" >"$SETUP_KEY_FILE"
unset NETBIRD_SETUP_KEY

sudo netbird up \
  --management-url "https://netbird.example.com" \
  --setup-key-file "$SETUP_KEY_FILE"

cleanup_setup_key
trap - EXIT HUP INT TERM

sudo netbird status
sudo netbird networks list
```

若 `netbird` 不在当前 PATH：

```bash
command -v netbird
sudo /usr/local/bin/netbird status
```

## 6. Linux 安装和连接

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh

SETUP_KEY_FILE="$(mktemp)"
cleanup_setup_key() {
  rm -f "$SETUP_KEY_FILE"
  unset NETBIRD_SETUP_KEY
}
trap cleanup_setup_key EXIT HUP INT TERM
chmod 600 "$SETUP_KEY_FILE"

read -rsp 'NetBird Setup Key: ' NETBIRD_SETUP_KEY
printf '\n'
printf '%s' "$NETBIRD_SETUP_KEY" >"$SETUP_KEY_FILE"
unset NETBIRD_SETUP_KEY

sudo netbird up \
  --management-url "https://netbird.example.com" \
  --setup-key-file "$SETUP_KEY_FILE"

cleanup_setup_key
trap - EXIT HUP INT TERM

sudo netbird status
sudo netbird networks list
```

macOS / Linux 示例用权限为 `0600` 的临时文件避免 Key 进入历史和进程参数，并用
`trap` 处理常规退出与中断。注册后仍要确认临时文件已删除并撤销已消费的 One-off
Key；强制断电或 `kill -9` 不会触发 Shell 清理函数。

服务器自动化接入应使用专用短期 Key 和专用 Auto Group，不复用人用 Key。单台服务器使用 One-off、usage limit=`1`；批量自动化使用有限次数的 Reusable。

## 7. 发给使用者的最小模板

```text
NetBird VPN 客户端

管理地址：https://netbird.example.com
Setup Key：NBSETUP-EXAMPLE-REPLACE-ME
Setup Key 注册截止：YYYY-MM-DD HH:MM
设备权限复核 / 回收日期：YYYY-MM-DD
授权范围：Git 服务和指定内网主机

注意：此 Key 只能注册一台设备，请不要转发。完成注册后无需登录管理后台。
```

随后附上对应系统的安装、`up`、`status` 三组命令即可。不要把多个平台都塞给不需要的使用者。

## 8. Windows 原地升级

升级前记录状态、路由、接口 metric 和 NRPT，并备份本机身份：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" version
& "$env:ProgramFiles\Netbird\netbird.exe" status
Get-NetRoute -AddressFamily IPv4 |
  Select-Object DestinationPrefix, NextHop, RouteMetric, InterfaceIndex
Get-NetIPInterface -AddressFamily IPv4 |
  Select-Object InterfaceAlias, InterfaceIndex, InterfaceMetric, ConnectionState
Get-DnsClientNrptPolicy -Effective
$BackupPath = "C:\ProgramData\Netbird.backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
Copy-Item "C:\ProgramData\Netbird" $BackupPath -Recurse
```

推荐直接安装新版签名 MSI 完成覆盖升级。若旧安装目录或卸载器阻塞升级：

1. 保留 `C:\ProgramData\Netbird` 备份。
2. 卸载旧客户端。
3. 安装已校验签名和 SHA256 的 v0.78.1 MSI。
4. 如果旧卸载器删除了同名 Windows 服务，再执行一次新版 MSI 的 Repair。
5. 启动服务并检查原 Peer 身份是否保持。

v0.77.1 修复了 Windows 更新器读取旧安装结果、静默更新时 UI 文件被占用、安装器
自行重启系统，以及更新后 UI 继承错误用户环境的问题。升级时仍需注意：

- 不要在安装进度中手工结束 `msiexec`、NetBird 服务或重启电脑。
- 静默更新会抑制自动重启；如果结果为 `3010` 或 `1641`，按“安装成功但需要重启”
  处理，在维护窗口手工重启后再次验收。
- 更新后 NetBird UI 应在当前用户会话恢复；UI 没出现时先检查服务、版本和隧道
  状态，不要把不存在的 `netbird down --cleanup` 当成修复动作。

```powershell
Get-Service NetBird
& "$env:ProgramFiles\Netbird\netbird.exe" version
& "$env:ProgramFiles\Netbird\netbird.exe" status
Get-Process netbird-ui -ErrorAction SilentlyContinue
Get-DnsClientNrptPolicy -Effective
```

`v0.77.1` 的 `netbird down` 不支持 `--cleanup`；该写法只会返回
`unknown flag`，不会清除注册状态。需要重装或替换身份时，应先备份状态目录，
再按管理员批准的设备回收流程删除旧 Peer，不能依赖一个无效参数。

## 9. macOS 和 Linux 升级

使用原安装渠道升级，避免同一机器混用包管理器和脚本安装路径：

```bash
netbird version
sudo netbird status
curl -fsSL https://pkgs.netbird.io/install.sh | sh
sudo netbird version
sudo netbird status
```

升级不应重新输入 Setup Key。若客户端要求重新注册，先检查状态目录、服务用户和原配置是否被清除。

## 10. 授权设备连接验收

客户端至少验证：

```text
Management: Connected
Signal: Connected
```

再使用真实协议测试授权资源：

Windows：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" version
Resolve-DnsName git.example.com
Find-NetRoute -RemoteIPAddress 10.20.30.11
Test-NetConnection 10.20.30.11 -Port 443
curl.exe -I https://git.example.com/
```

macOS：

```bash
netbird version
dig +short git.example.com
route -n get 10.20.30.11
curl -I --connect-timeout 10 https://git.example.com/
```

Linux：

```bash
netbird version
getent ahosts git.example.com
ip route get 10.20.30.11
curl -I --connect-timeout 10 https://git.example.com/
```

管理员还要确认：

- 新 Peer 自动进入预期组，没有进入宽泛管理组。
- 只有计划内 Policy 对该组生效。
- 路由实际选择 NetBird 预期接口，真实 TCP / HTTPS 成功，不能只用 `ping`。
- 未授权 VPC 主机访问失败。
- 一次性 Setup Key 的 usage 已消耗，随后撤销或删除。

## 11. 非授权设备验证

准备一台明确不在授权 Auto Group、且没有其他 Policy 可到达目标的 Peer。尽量让
它与授权设备使用相同平台和接入网络，以减少环境差异。

Windows：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" status
& "$env:ProgramFiles\Netbird\netbird.exe" networks list
Find-NetRoute -RemoteIPAddress 10.20.30.11
Test-NetConnection 10.20.30.11 -Port 443 -InformationLevel Detailed
```

macOS：

```bash
netbird status
netbird networks list
route -n get 10.20.30.11
nc -vz -G 5 10.20.30.11 443
curl --silent --show-error \
  --connect-timeout 5 \
  --output /dev/null \
  --write-out 'http=%{http_code}\n' \
  --resolve git.example.com:443:10.20.30.11 \
  https://git.example.com/
```

Linux：

```bash
netbird status
netbird networks list
ip route get 10.20.30.11
nc -vz -w 5 10.20.30.11 443
curl --silent --show-error \
  --connect-timeout 5 \
  --output /dev/null \
  --write-out 'http=%{http_code}\n' \
  --resolve git.example.com:443:10.20.30.11 \
  https://git.example.com/
```

预期证据：

- 非授权 Peer 不在来源组，且没有意外的直接 Peer Policy 或宽泛 `All` Policy。
- `nc` 无法建立 TCP 连接，带正确 SNI / 证书域名的 `curl` 输出 `http=000`。任何
  HTTP 状态码都表示请求已经到达 HTTPS 服务，不能把 `401`/`403` 或证书错误当成
  NetBird 网络拒绝。
- 客户端没有得到该 Resource 的预期 NetBird 路径；以当前对象模型的实际执行层
  为准，并用目标日志或来源地址排除其他直连路径。
- Dashboard 中授权组成员和 Policy 依赖数量没有因测试发生变化。

如果目标也能从公网或本地 LAN 直接访问，`curl` 成功不能证明 NetBird Policy
泄漏。此时必须结合客户端实际路由、目标侧来源地址，或改用只能经 NetBird 到达
的内网控制目标完成拒绝测试。

## 12. 常见故障

### 12.1 Windows Wintun 创建失败

先检查服务和日志，再重启服务同步：

```powershell
Get-Service NetBird
Restart-Service NetBird
& "$env:ProgramFiles\Netbird\netbird.exe" status --detail
```

不要在没有保存身份数据时反复卸载和 cleanup。

### 12.2 Windows 连接成功但访问不到内网

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" networks list
Find-NetRoute -RemoteIPAddress 10.20.30.11
Get-NetRoute -AddressFamily IPv4 |
  Select-Object DestinationPrefix, NextHop, RouteMetric, InterfaceIndex
Get-NetIPInterface -AddressFamily IPv4 |
  Select-Object InterfaceAlias, InterfaceIndex, InterfaceMetric, ConnectionState
```

Windows 对相同前缀长度的候选路由使用“Route Metric + Interface Metric”的总和
排序。v0.77.1 已让 NetBird 的候选路由判断与该规则一致；多网卡、Wi-Fi + 以太网
或同时运行其他 VPN 时，不能只比较 `RouteMetric`。先记录两项 metric、重叠 CIDR
和 `Find-NetRoute` 结果，再检查 Network、Resource、Policy、Routing Peer、目标
端口和云安全组，不要直接修改 metric 或只测 `ping`。

### 12.3 Windows 断开或升级后 DNS / NRPT 异常

```powershell
Get-DnsClientNrptPolicy -Effective
Resolve-DnsName git.example.com
& "$env:ProgramFiles\Netbird\netbird.exe" status --detail
```

v0.77.1 会枚举并清理 NetBird 自己创建的 NRPT 项，覆盖本地、组策略和旧版本留下
的布局，同时保留其他产品的规则。发现残留时先保存上述输出，重新连接后正常执行
一次 `down` 并复查；仍异常则收集 NetBird 调试包和 Windows DNS 配置。不要清空
整张 NRPT 表、删除其他 VPN / 安全产品的规则或把重启系统当成唯一修复。

### 12.4 更新后 UI 没有恢复

v0.77.1 会用当前登录用户的环境重新启动 UI。若仍未出现：

```powershell
Get-Service NetBird
& "$env:ProgramFiles\Netbird\netbird.exe" version
& "$env:ProgramFiles\Netbird\netbird.exe" status
Start-Process "$env:ProgramFiles\Netbird\netbird-ui.exe"
```

如果服务和隧道正常，可先按 UI 单独故障处理；不要删除身份目录或重复使用 Setup
Key 创建第二个 Peer。

### 12.5 Setup Key 无法再次使用

如果它是 One-off，这是预期行为。One-off 的实际语义始终是单次使用，Public API
中的 `usage_limit` 不得大于 `1`；为新人员设备单独创建一把 Key，批量自动化才
使用短期 Reusable。

## 13. 回滚与权限回收

### 13.1 先从控制面撤销访问

人员离职、设备丢失或错误加入高权限组时，管理员按影响范围执行：

1. 先把目标 Peer 移出敏感访问组，或停用这台设备依赖的错误 Policy。
2. 丢失或不再使用的设备在 Dashboard 中删除 Peer。
3. 撤销仍未使用的 Setup Key，并检查 Activity 记录。
4. 复核原授权组、Resource 和其他 Peer 没有被误删。

只 revoke Setup Key 不会让已经注册的 Peer 下线；必须处理 Peer、组或 Policy。

### 13.2 客户端临时断开

用户临时断开：

```powershell
& "$env:ProgramFiles\Netbird\netbird.exe" down
```

```bash
sudo netbird down
```

仅让客户端执行 `down` 不等于权限已回收。断开后用实际路由和目标 TCP 再验证一次，
确认流量没有继续经过 NetBird。

### 13.3 Windows 升级回退

1. 保留失败版本的日志、安装结果、路由和 NRPT 输出。
2. 安装上一版已验证且签名、SHA256 均正确的 MSI，不手工覆盖程序文件。
3. 保留当前 `C:\ProgramData\Netbird`，先验证原 Peer 身份能否直接恢复。
4. 只有状态目录确认损坏，且备份后没有成功注册过新身份时，才停止服务并恢复升级前
   备份；不要把同一份身份复制给另一台同时在线的设备。
5. 启动服务，确认 Peer 名称、NetBird IP、Management / Signal 和授权资源都恢复。

身份恢复示例中的时间戳必须替换为实际备份值：

```powershell
Stop-Service NetBird
Rename-Item "C:\ProgramData\Netbird" "C:\ProgramData\Netbird.failed-YYYYMMDDHHMMSS"
Copy-Item "C:\ProgramData\Netbird.backup-YYYYMMDDHHMMSS" `
  "C:\ProgramData\Netbird" -Recurse
Start-Service NetBird
& "$env:ProgramFiles\Netbird\netbird.exe" status
```

macOS / Linux 也应通过原安装渠道回退到已验证版本，并保留原身份状态。
`netbird down --cleanup` 在 `v0.77.1` 中不是有效命令。若身份确实丢失，由管理员
删除旧 Peer 后再签发新的 One-off Key，不要让旧新两个设备记录长期并存。

### 13.4 回滚成功标准

- 被回收设备离线或已从 Dashboard 删除，且不再属于敏感组。
- 未使用 Key 已撤销，已注册 Peer 的撤权不依赖 revoke Key。
- 计划移除的 NetBird 路由和 NetBird 自有 NRPT 项已消失，其他 DNS / VPN 规则仍在。
- 原授权目标已无法经 NetBird 访问，无关公网、LAN 和其他 VPN 仍正常。
- 如果是版本回退，原 Peer 身份、NetBird IP 和允许的真实业务访问恢复。

## 14. 官方参考

- https://docs.netbird.io/get-started/install
- https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
- https://docs.netbird.io/manage/peers/bootstrap-via-config-file
- https://github.com/netbirdio/netbird/releases/tag/v0.77.1
- https://learn.microsoft.com/windows-server/networking/technologies/network-subsystem/net-sub-interface-metric
