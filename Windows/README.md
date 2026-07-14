# Windows 11 版本使用说明

## 打包环境

1. 使用 Windows 11 x64。
2. 安装 [.NET 8 SDK x64](https://dotnet.microsoft.com/download/dotnet/8.0)。
3. 保持项目目录结构完整，不要只复制 `Windows` 文件夹。

## 一键打包

在项目根目录双击 `build-win11.bat`。脚本会自动执行 Release、自包含、单文件打包，并生成：

```text
dist-win11\ChatGPT.exe
```

生成的 EXE 不要求目标电脑另外安装 .NET 运行时。

## 数据目录

应用默认读取：

```text
%USERPROFILE%\.codex\sessions
```

如果该目录还不存在，先在 Windows 版 Codex 中运行至少一个会话。

## 功能

- 屏幕顶部中央显示 `ChatGPT · Week xx% · 项目状态`。
- 点击顶部胶囊展开周额度、每日活动、统计总览。
- 每日活动格子悬停立即显示当天 Token 和会话数。
- 右下角系统托盘支持刷新、开机启动和退出。
- 只有同一会话从运行中真实切换到完成时才发送通知，并播放系统通知音。

## 通知看不到时

打开 Windows 11 的“设置 → 系统 → 通知”，确认允许 `ChatGPT` 发送通知，同时关闭“请勿打扰”。

## 开机启动

右键系统托盘中的 ChatGPT 图标，勾选“开机自动启动”。取消勾选即可关闭。
