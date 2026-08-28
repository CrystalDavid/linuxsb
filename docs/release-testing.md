# 华为邀请测试发布规范

## 当前发布身份

| 项目 | 当前值 | 状态 |
| --- | --- | --- |
| 应用名称 | 烧饼社区 | 已确认 |
| bundleName | `com.david.shaobingcommunity` | 本地 Release 包已切换；待在 AGC 重新创建并绑定 APP ID |
| versionName | `1.0.0` | 已确认 |
| versionCode | `1000000` | 已确认；后续测试版本不得低于已发布测试版本 |
| target / compatible API | 24 / 23 | 满足当前真机 API 26 运行 |
| 本地真机包 | debug Profile 签名 HAP | 仅用于已登记真机调试，不能作为邀请测试 release 包 |
| App Pack | 已完成 Release `.app` 结构构建 | 已核验 `releaseType: Release`；当前为 unsigned，待 DevEco 托管签名 |
| 隐私政策 | [公开页面](https://crystaldavid.github.io/linuxsb-privacy/) | GitHub Pages 已发布，匿名 HTTPS 访问返回 200 |

公共仓库中的 `build-profile.json5` 必须保持 `signingConfigs: []`。证书、Profile、keystore 路径和密码只能保留在开发者本机或华为云托管签名中，不得进入 Git。

## Mate 80 Pro Max 安装验收

2026-08-26 已将最新签名 HAP 覆盖安装到 HUAWEI Mate 80 Pro Max（`SGT-AL10`，HarmonyOS `7.0.0.102`，API 26）。应用可启动，普通首页 `Web` 节点为 0；首页 90Hz 双向惯性滑动和主题冷/热加载数据见 [performance.md](performance.md)。

## AppGallery Connect 邀请测试流程

1. 登录 AppGallery Connect，在 HarmonyOS 应用列表中确认应用名称、APP ID 与 `bundleName` 一致；
2. 使用 DevEco Studio 的 AppGallery Connect / Testing Only 上传方式生成或选择 release 签名，重新构建 `.app`；
3. 在“应用上架 > 软件包管理”上传 `.app`，使用场景选择“仅测试”，等待合法性解析完成；
4. 在“应用测试/元服务测试 > 测试用户”创建外部测试群组；
5. 优先使用“邀请码添加”：设置有效期和人数上限，避免提前收集测试者华为账号；若手动添加，优先使用邮箱格式华为账号；
6. 在“版本列表”创建“邀请测试”版本，设置最长不超过 90 天的测试时间并选取已解析软件包；
7. 填写图标、名称、应用介绍、测试说明、隐私声明、负责人联系方式和审核说明；
8. 选择测试群组；
9. 提交审核。此操作会把应用资料和软件包发送给华为并创建对外测试任务，执行前必须由账号持有人最终确认；
10. 审核通过后获取版本分享链接，将邀请码拼接到分享链接后发送给受信任测试者。

华为当前规则：最多创建 300 个外部测试群组，所有外部群组累计去重不超过 10000 名测试用户；邀请码默认有效期 30 天；邀请测试单个版本最长 90 天；在架邀请测试与公开测试版本合计不超过 100 个。

## 提交资料草案

### 应用介绍

烧饼社区是 LinuxSB 社区的非官方 HarmonyOS 客户端。

### 测试说明

本版本用于验证 Mate 80 Pro Max 等 HarmonyOS 设备上的首页滑动、分页加载、主题打开、图片加载、深浅色模式、官方登录及登录后回复/发帖流程。请勿在反馈中附带账号、Cookie、验证码或其他敏感信息；问题可通过测试任务预留的联系方式反馈。

### 审核说明

该应用为 LinuxSB 非官方第三方客户端，不冒充站方。账号登录在 LinuxSB 官方网页完成；应用不采集密码或验证码。应用只申请网络访问和网络状态权限，不集成广告或第三方统计 SDK。普通业务页面为 HarmonyOS ArkUI 原生界面，ArkWeb 仅用于用户主动打开的官方登录页。

## 发布前阶段门

- [x] 最新代码通过构建，HAP 已安装到 API 26 真机；
- [x] `.app` App Pack 能成功组装；
- [x] 真机首页 Web 节点为 0；
- [x] 真机滑动与主题冷/热加载已有有效证据；
- [ ] 为 `com.david.shaobingcommunity` 重新创建并绑定 AGC APP ID；
- [x] production bundleName 已在本地确认为 `com.david.shaobingcommunity`；
- [x] Release SDK 重新构建完成，包内 `releaseType` 已核验为 `Release`；
- [ ] 使用 release 或华为云托管证书重新签名；
- [ ] 软件包合法性检测通过；
- [x] 隐私政策已通过 HTTPS 对公众可访问；
- [ ] 填写负责人联系方式、测试时间和测试人数；
- [ ] 账号持有人确认后提交邀请测试审核；
- [ ] 审核通过并生成分享链接 / 邀请码。
