# 画框 · FrameStudio

一个运行在 HarmonyOS 上的照片相框工具：从系统图库选择照片，读取照片 EXIF 拍摄参数，在照片边缘生成可定制的参数相框，并保存为新的 JPEG 图片。

FrameStudio 的目标是让“选照片 → 选相框 → 保存”足够简单，同时保留摄影爱好者需要的排版自由度。照片处理在设备本地完成，不依赖云端服务。

## 功能

### 相册

- 创建、删除相册；按创建时间倒序展示。
- 使用 HarmonyOS 系统图片选择器导入图片，单次最多选择 100 张。
- 相册卡片以照片堆叠形式展示，照片带有“未处理”状态提示。
- 进入相册详情后以网格浏览照片，双指捏合可在 1～5 列之间调整网格密度。
- 点击照片进入套框页面，长按照片可从相册移除；空相册支持长按删除。
- 为照片暂存相框后，可在相册详情中批量导出已配置的照片。

### 相框设计

- 内置 5 套模板：极简白、经典黑、杂志、胶片、暗夜。
- 创建和编辑自定义相框，设计保存在本地。
- 支持开关和拖动排序以下元素：
  - 自定义文字
  - 光圈、快门、ISO、焦距
  - 相机型号、拍摄时间、GPS 经纬度
  - 相机 Logo
- 支持信息带竖向/横向排列，以及左对齐、居中、右对齐。
- 可分别调整上/左/右白边、下方白边和文字区域宽度。
- 可调整单个元素的字号、颜色、粗细、水平/垂直位置，并选择是否允许元素进入照片区域。
- 拖动元素时提供常用位置吸附参考线，也可以恢复元素默认排版。
- 支持 8 个内置相机品牌 Logo，也支持从系统图库上传自定义 Logo。
- 支持相框颜色、透明度和沉浸光感、透明、磨砂、高斯模糊等视觉效果。
- 可从系统图库选择示例照片，在设计过程中实时查看真实照片和 EXIF 效果。

### 预览与导出

- `FramePreview` 和 `FrameExporter` 共用布局计算逻辑，预览与导出使用同一套元素位置和排版规则。
- 自动读取并格式化常见 EXIF：`f/1.8`、`1/125s`、`ISO100`、`24mm`、相机型号、拍摄时间和 GPS。
- 使用 ArkGraphics2D 离屏 Canvas 绘制相框和文字，再编码为质量 94 的 JPEG。
- 为避免大图导致内存压力，导出前将照片最长边限制为 4096 像素。
- 通过系统照片创建对话框保存，用户可以在系统界面确认或取消保存。
- 单张导出和相册批量导出均可用；导出成功后会更新照片的已处理状态。

### 设置

- 演示登录/退出状态，并使用 preferences 持久化。
- 提供恢复购买、会员权益等演示入口。
- 展示应用版本和关于信息。

## 使用流程

1. 打开“相册”页，点击右上角 `+` 创建相册。
2. 在系统图片选择器中导入照片。
3. 点击相册卡片进入详情，再点击照片打开“照片套框”。
4. 选择一个内置或自定义相框：
   - 点击“暂存”会把当前相框配置记录到照片，供后续批量导出。
   - 点击“导出”会立即生成 JPEG 并打开系统保存对话框。
5. 需要创建模板时，进入“设计”页，点击“新增设计”，在预览区和底部控制面板中调整参数后保存。
6. 返回相册详情，点击“批量导出”可一次处理所有已暂存相框的照片。

## 技术实现

- **语言**：ArkTS
- **UI**：ArkUI 声明式 UI
- **应用模型**：HarmonyOS Stage 模式，单 `EntryAbility`
- **导航**：`Navigation` + `NavPathStack`
- **当前工程配置**：HarmonyOS SDK 6.0.1（API 21），目标设备为 `phone` 和 `tablet`
- **本地存储**：`@kit.ArkData` preferences
- **图像与 EXIF**：`@kit.ImageKit`
- **绘制与编码**：`@kit.ArkGraphics2D`、JPEG ImagePacker
- **图片选择与保存**：`@kit.MediaLibraryKit`
- **窗口与系统栏**：透明状态栏/导航栏，依据页面深浅色动态切换图标颜色

工程未在 `module.json5` 中声明独立的照片读写权限，图片选择和保存均通过 HarmonyOS 系统组件完成。

## 项目结构

```text
.
├── AppScope/                         # 应用级资源与 bundle 配置
├── entry/
│   ├── build-profile.json5           # Entry 模块构建配置
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── entryability/     # EntryAbility，沉浸式窗口初始化
│       │   │   ├── model/            # 相册、相框和 EXIF 数据模型
│       │   │   ├── pages/            # Index：Navigation 和三 Tab 入口
│       │   │   ├── service/          # FrameExporter：Canvas 渲染与导出
│       │   │   ├── util/             # 状态栏样式工具
│       │   │   └── view/              # 页面与可复用 UI 组件
│       │   └── resources/             # 字符串、颜色、图标、Logo 等资源
│       ├── test/                      # 本地单元测试
│       └── ohosTest/                  # 设备/模拟器测试
├── hvigor/                            # Hvigor 配置
├── pic/                               # 设计稿和视觉参考图
├── build-profile.json5                # 应用级构建配置
├── hvigorfile.ts                      # 应用 Hvigor 入口
└── oh-package.json5                   # OHPM 工程配置
```

关键模块关系如下：

```text
Index
├── GalleryTab ────── AlbumStore ───── preferences
│   └── AlbumDetailPage
│       └── PhotoEditPage ── FramePreview ── FrameExporter
├── DesignTab
│   └── FrameDesignPage ─── FramePreview
└── SettingsTab ───── FrameConfig（登录状态）
```

## 数据与持久化

应用使用同一个 preferences 存储 `huakuang_store`：

| Key | 内容 |
| --- | --- |
| `albums` | 相册、照片 URI、导入时间、处理状态和暂存的相框 ID |
| `custom_frames` | 用户创建的相框配置和元素排版信息 |
| `logged_in` | 演示登录状态 |

原始照片仍由系统图库管理，应用主要保存照片 URI 和相框配置。导出文件先写入应用缓存目录，再交给系统照片保存对话框。当前导出流程不会把原始 EXIF 元数据重新写入新 JPEG；拍摄参数会以文字形式绘制在相框上。

## 环境要求

推荐使用：

- DevEco Studio 6.0.1 或兼容版本
- HarmonyOS SDK 6.0.1（API 21）
- Windows、macOS 或 Linux 上可运行的 DevEco Studio 环境
- 真机或本地模拟器（Phone/Tablet）
- 可用的 OHPM/SDK 下载网络

如果使用本地模拟器，建议在 `Tools → Device Manager → Local Emulator` 中创建 Phone 或 Tablet 设备，并在 SDK Manager 中安装对应的 HarmonyOS 系统镜像。若设备管理器只显示 Wearable，检查是否进入了穿戴设备仿真器入口、地区设置、代理和 SDK 镜像目录。

## 在 DevEco Studio 中运行

1. 使用 DevEco Studio 打开本项目根目录，不是只打开 `entry` 子目录。
2. 等待项目同步并完成 OHPM 依赖解析。
3. 在 SDK Manager 中安装 HarmonyOS SDK 6.0.1/API 21；需要模拟器时同时安装 Emulator 和 Phone/Tablet 镜像。
4. 连接 HarmonyOS 真机或启动 Phone/Tablet 模拟器。
5. 选择 `entry` 模块和 `default` 构建目标，点击 Run。

照片导入和系统保存对话框依赖真实的系统图库环境。模拟器中如果没有可用图片，需要先向模拟器图库导入测试图片。

## 构建与签名

在 DevEco Studio 中选择 `Build → Build Hap(s) → Build Hap(s)` 即可构建 HAP。

当前仓库未提交机器相关的签名证书和 profile。未配置签名时，构建产物通常为未签名 HAP，例如：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

将应用安装到真机或发布到应用市场前，需要在 DevEco Studio 的 Signing 配置中选择/生成有效的签名证书、Profile 和密钥。不要把个人证书、密钥或机器专属 `local.properties` 提交到版本库。

本项目已在 DevEco Studio 6.0.1 环境完成构建验证；当前仅有 API 弃用提示和异常处理建议类警告，没有阻断构建的 ArkTS 编译错误。

## 测试

工程包含两套 Hypium 测试入口：

- `entry/src/test/`：本地单元测试
- `entry/src/ohosTest/`：真机/模拟器测试

现有测试主要是工程模板级 smoke test（字符串断言），尚未覆盖相册持久化、EXIF 格式化、Canvas 导出和 UI 手势等完整业务场景。建议在接入新设备或修改导出逻辑后，至少手动验证：导入照片、读取 EXIF、单张导出、批量导出、取消保存和大图导出。

## 已知限制与后续计划

- 设置页的登录、会员和恢复购买仍是演示功能。
- 照片编辑页目前支持选择相框、暂存和导出；相框的完整参数编辑需要从“设计”页进入。
- 暂存相框依赖当前自定义设计 ID；删除自定义相框后，之前暂存该 ID 的照片将无法参与批量导出。
- 导出结果是新的 JPEG，不会自动保留原始文件的全部 EXIF 元数据。
- 暂无导出后直接调用系统分享面板的功能。
- 暂无真正的华为账号体系和 IAP 会员订阅。
- 相框风格和 Logo 资源仍可继续扩展。

## 设计稿

`pic/` 目录保存了项目不同阶段的界面设计稿和视觉参考：

- `4.png`：相框编辑页方向
- `5.png`：相册页方向
- `6.jpg`：底部悬浮胶囊导航参考
- `1.jpg`～`3.jpg`：早期概念稿

设计稿是视觉参考，最终交互和页面结构以 `entry/src/main/ets/` 中的实现为准。

## 许可证

当前仓库未提供单独的 LICENSE 文件。如需公开发布或复用，请先补充许可证并确认图片、Logo 和第三方依赖的授权范围。
