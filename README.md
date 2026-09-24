# 桌面日历 · macOS Desktop Calendar

一个原生 macOS WidgetKit 桌面小组件，显示公历月视图、农历、二十四节气和中国法定节假日。

## 功能

- 公历月视图、农历日期与二十四节气
- 2026 年国务院公布的法定节假日及调休标记
- 中秋、国庆等节日名称和倒计时
- 点击小组件打开网页日历
- WidgetKit 时间线在跨天、电脑唤醒后自动刷新
- 作为系统桌面小组件运行，支持 Mission Control、空间切换和系统桌面布局
- 提供中号、大号两种尺寸

## 系统要求

- macOS 14.0 及以上
- Xcode 16 及以上
- Apple Developer 账号（免费账号即可，用于开发签名）

## 构建与安装

1. 用 Xcode 打开 `DesktopCalendar.xcodeproj`。
2. 在 `DesktopCalendar` 和 `DesktopCalendarWidget` 两个 target 的 **Signing & Capabilities** 中选择你自己的 Team。如有冲突，把 Bundle Identifier 改成你自己的前缀。
3. 选择 `DesktopCalendar` scheme，Product → Archive 或直接 Build。
4. 把生成的 `DesktopCalendar.app` 拷贝到 `/Applications` 或 `~/Applications`，运行一次以注册小组件。

也可以用命令行构建：

```bash
xcodebuild -project DesktopCalendar.xcodeproj \
  -scheme DesktopCalendar \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  DEVELOPMENT_TEAM=<你的 Team ID> \
  -allowProvisioningUpdates \
  build
```

> WidgetKit 扩展需要正规的开发签名才能被系统识别。`build-widget.sh` 使用 ad-hoc 签名，只适合快速检查能否编译，生成的小组件可能不会出现在小组件列表里。

## 使用

1. 在桌面右键，选择“编辑小组件”。
2. 搜索“桌面日历”，选择中号或大号并添加。
3. 拖动到合适的位置。

## 数据说明

- 2026 年放假和调休数据来自国务院办公厅《关于 2026 年部分节假日安排的通知》。其他年份的节假日数据暂未内置，欢迎提交 PR。
- 农历日期由 macOS 系统日历计算。
- 底部“宜/忌”为本地展示文案，不作为专业黄历依据。

## 声明

界面风格参考了搜索引擎中的日历卡片，本项目为个人学习作品，与任何搜索引擎服务商无关。

## 许可证

[MIT](LICENSE)
