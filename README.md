# XDown

XDown 是一个 HarmonyOS NEXT 原生的 X（Twitter）视频保存工具。

粘贴 X 视频链接，在设备本地解析可用清晰度，下载后保存到系统图库。解析、下载和 Cookie 都留在本机，不经过自建服务器。

<img src="assets/icon.png" width="96" alt="XDown 图标" />

## 安装

从 [Releases](https://github.com/sirion123/XDown/releases/latest) 下载未签名 HAP，使用 [auto-installer](https://github.com/likuai2010/auto-installer/) 安装；安装器会用自己的证书完成签名，不使用开发者的个人签名。

## 功能

- 解析 `x.com` / `twitter.com` 的视频帖子
- 支持公开视频，以及登录后可见的受保护视频
- 选择可用清晰度后下载
- 保存到系统图库
- 下载历史、播放预览、清理缓存
- 官方 HdsTabs 沉浸光感底部导航
- 深色 / 浅色模式
- 5 种主题色可切换
- 自定义背景图片
- 仅保留 X 平台，Provider 层保留后续扩展接口

## 环境

| 组件 | 版本 |
|---|---|
| HarmonyOS SDK | API 26（26.0.0 Release） |
| DevEco Studio Command Line Tools | 26.0.0.851 |
| hvigor | 6.26.8 |
| ohpm | 26.0.0.630 |
| Node.js | 22.x |

## 构建

```powershell
ohpm install
hvigorw --mode module -p module=entry@default assembleHap --no-daemon
```

`build-profile.json5` 不包含任何签名材料。首次构建前，在 DevEco Studio 中打开项目，使用 **File → Project Structure → Signing Configs** 配置自动签名，或在本地自行配置证书。

构建产物位于：

```text
entry/build/default/outputs/default/
```

安装到设备：

```powershell
hdc install entry/build/default/outputs/default/entry-default-signed.hap
```

## 项目结构

```text
AppScope/                    应用级配置与图标
entry/src/main/ets/
  entryability/              UIAbility 生命周期、分享入口
  pages/                     HomePage、ResolveDetailPage、LoginPage
  components/                GlassCard、TaskCard、FormatOptionList 等
  providers/                 ProviderAdapter、ProviderRegistry、XProvider
  services/                  Resolve、Download、Cookie、MediaSave
  storage/                   HistoryRepository、SettingsRepository
  models/                    解析结果、下载任务、媒体条目
entry/src/main/resources/    字符串、颜色、图标
```

新增平台时，实现 `ProviderAdapter`，在 `ResolveService.registerProviders()` 注册，并扩展 `ProviderType`、`LinkNormalizer` 与 `CookieService` 即可。

## 已知限制

- 当前只支持 X，不支持其他平台
- 仅支持 `/{用户}/status/{帖子ID}` 形式的帖子链接
- 纯文本、图片帖子会返回“无视频”
- 仅下载 MP4，暂不处理 HLS 或音视频分离格式
- X 的 GraphQL queryId 和网页公开 bearer 可能随 X 更新而变化；若解析失效，需要同步更新 `XProvider` 中的常量
- 需要登录才能查看的内容，请先在设置中登录 X 账号
- 不绕过 DRM、付费墙或平台访问限制

## 隐私

- Cookie 仅保存在本机应用 Preferences 中
- 退出登录会清理应用侧 Cookie 和 WebView Cookie
- 链接、视频和登录信息不会上传到自建服务器
- 应用不收集账号密码，也不记录签名媒体地址

## 使用须知

本项目仅用于保存你有权访问和备份的内容。请遵守 X 的服务条款和所在地版权法规，不要用本项目下载、传播未经授权的内容。

---

本项目由AI完成，本人未编写任何代码。
