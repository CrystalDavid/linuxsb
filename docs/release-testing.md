# 华为邀请测试发布规范

## 当前发布身份

| 项目 | 当前值 | 状态 |
| --- | --- | --- |
| 应用名称 | 烧饼社区 | 已确认 |
| bundleName | `com.david.shaobingcommunity` | 2026-08-30 结合 AGC 软件包截图与本地配置核对，现有应用包名一致 |
| versionName | `1.1.1` | 当前邀请测试候选 |
| versionCode | `1001001` | 当前邀请测试候选；后续测试版本必须继续递增 |
| buildVersion | `3` | 对应 AGC 构建版本；高于已上传的 1.1.0 build 2 |
| target / compatible API | 24 / 23 | 当前活动产品由 API 24 SDK 编译；同一 HAP 需验证 API 24 与 API 26 向上运行兼容。若另建 target 26 产品，必须单独记录构建和双系统证据 |
| 本地真机包 | 1.1.1 release 签名 HAP 已组装并通过 `verify-app` | 用于本地安装/留档；AGC“软件包管理”上传应选择 App Pack `.app` |
| App Pack | 1.1.1 release 签名 `.app` 已组装并通过 `verify-app` | Profile 为 `release / app_gallery`；本地校验不等于 AGC 已上传、合法性已解析或 AppTest 已安装 |
| 隐私政策 | [公开页面](https://crystaldavid.github.io/linuxsb-privacy/) | GitHub Pages 已发布，匿名 HTTPS 访问返回 200 |

AGC 当前截图状态（2026-08-30）：软件包管理中已有 1.1.0（build 2）与 1.0.0（build 1），设备类型均为手机、平板、PC/2in1，使用场景均为“仅测试”；两者合法性均“已达标”。1.1.0 的上架自检为“待优化”，1.0.0 为“未检测”。1.1.1 尚未上传、未解析，也未进入 AppTest 安装验证。

公共仓库中的 `build-profile.json5` 必须保持 `signingConfigs: []`。证书、Profile、keystore 路径和密码只能保留在开发者本机或华为云托管签名中，不得进入 Git。

## 投喂开发者商品配置

| 商品 ID | 用户可见档位 | 价格 | 类型 | 状态 |
| --- | --- | --- | --- | --- |
| `linuxsb_tip_coin_1` | 投喂一个硬币 | CNY 1.00 | 消耗型一次性商品 | AGC 商品列表为空，待创建 |
| `linuxsb_tip_water_5` | 投喂一瓶水 | CNY 5.00 | 消耗型一次性商品 | AGC 商品列表为空，待创建 |
| `linuxsb_tip_coffee_9_9` | 投喂一杯咖啡 | CNY 9.90 | 消耗型一次性商品 | AGC 商品列表为空，待创建 |
| `linuxsb_tip_pro_50` | 投喂一个 pro 订阅 | CNY 50.00 | 消耗型一次性商品 | AGC 商品列表为空，待创建 |

四项都必须配置为一次性消耗型商品。“pro 订阅”只是一档投喂名称，不自动续费、不产生会员或论坛权益。商品 ID 在 AGC 创建后不可修改，必须先核对 APP ID 与 `com.david.shaobingcommunity` 的绑定关系。官方操作依据：[配置应用内商品](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-app-goods-0000002278981442)、[应用内支付购买](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/iap-purchase)、[应用测试与支付沙盒](https://developer.huawei.com/consumer/cn/doc/development/AppGallery-connect-Guides/appgallerykit-test-0000001054601485)。

## Mate 80 Pro Max 安装验收

2026-08-26 已将最新签名 HAP 覆盖安装到 HUAWEI Mate 80 Pro Max（`SGT-AL10`，HarmonyOS `7.0.0.102`，API 26）。应用可启动，普通首页 `Web` 节点为 0；首页 90Hz 双向惯性滑动和主题冷/热加载数据见 [performance.md](performance.md)。

## AppGallery Connect 邀请测试流程

1. 登录 AppGallery Connect，在 HarmonyOS 应用列表中确认应用名称、APP ID 与 `bundleName` 一致（2026-08-30 已结合软件包截图和本地配置核对）；
2. 在“项目设置 / API 管理”启用应用内支付能力，在对应应用下创建上表四个消耗型商品并配置发布国家/地区；
3. 使用 DevEco Studio 的 AppGallery Connect / Testing Only 上传方式生成或选择 release 签名，重新构建 `.app`；
4. 在“应用上架 > 软件包管理”上传 `.app`，使用场景选择“仅测试”，等待合法性解析完成；
5. 在“应用测试/元服务测试 > 测试用户”先配置支付沙盒测试账号，再创建外部测试群组；
6. 用沙盒账号逐档验证收银台金额、取消、失败、成功和消耗确认，不得用真实扣款替代发布前回归；
7. 优先使用“邀请码添加”：设置有效期和人数上限，避免提前收集测试者华为账号；若手动添加，优先使用邮箱格式华为账号；
8. 在“版本列表”创建“邀请测试”版本，设置最长不超过 90 天的测试时间并选取已解析软件包；
9. 填写图标、名称、应用介绍、测试说明、隐私声明、负责人联系方式和审核说明；
10. 选择测试群组；
11. 提交审核。此操作会把应用资料和软件包发送给华为并创建对外测试任务，执行前必须由账号持有人最终确认；
12. 审核通过后获取版本分享链接，将邀请码拼接到分享链接后发送给受信任测试者。

华为当前规则：最多创建 300 个外部测试群组，所有外部群组累计去重不超过 10000 名测试用户；邀请码默认有效期 30 天；邀请测试单个版本最长 90 天；在架邀请测试与公开测试版本合计不超过 100 个。

## 提交资料草案

### 应用介绍

烧饼社区是 LinuxSB 社区的非官方 HarmonyOS 客户端。

### 测试说明

本版本用于验证 Mate 80 Pro Max 等 HarmonyOS 设备上的首页滑动、分页加载、主题打开、图片加载、深浅色模式、官方登录、登录后回复/发帖、称号交易，以及设置页一次性“投喂开发者”支付流程。四个投喂档位均为一次性消耗型商品，不自动续费、不提供社区权益。反馈可在应用设置页进入 LinuxSB 主题 17803；请勿在反馈中附带账号、Cookie、验证码、订单号或其他敏感信息。

### 审核说明

该应用为 LinuxSB 非官方第三方客户端，不冒充站方。账号登录和 Cloudflare 人机验证均在 LinuxSB 官方网页完成；应用不采集密码或验证码。应用只申请网络访问和网络状态权限，不集成广告或第三方统计 SDK。普通业务页面为 HarmonyOS ArkUI 原生界面；设备内隐藏 ArkWeb 仅用于 linux.sb 同源请求和 Cloudflare 会话，可见 ArkWeb 只在用户登录或完成人机验证时出现。“投喂开发者”通过华为 IAP Kit 打开系统收银台，四档均为一次性消耗型商品；应用不自建支付页、不读取银行卡或支付密码。

## 发布前阶段门

- [x] 1.1.1 最新代码通过 release 构建，包内确认为 `com.david.shaobingcommunity / 1.1.1 / 1001001 / build 3 / Release / target 24 / compatible 23`；
- [x] 1.1.1 release 签名 `.app` App Pack 与 `.hap` 已在本地交付目录归档，二者均通过 `hap-sign-tool verify-app`，嵌入 Profile 均为 `release / app_gallery`；
- [x] API 24 模拟器正常首页仅保留隐藏传输 Web 1，挑战完成后可见挑战 Web 自动关闭，原生首页恢复；
- [x] 1.1.1 源码对应调试签名 HAP 已在 API 26 真机完成首页头像、滑动和根页切换专项复验；深浅色与主题冷/热加载完整发布回归仍未覆盖；
- [x] 现有 AGC 应用包名已确认为 `com.david.shaobingcommunity`，无需重新创建；
- [x] production bundleName 已在本地确认为 `com.david.shaobingcommunity`；
- [x] 本地版本号已更新为 `1.1.1 / 1001001 / build 3`；
- [x] 使用本地 release 签名构建 1.1.1 对外测试包并核验 `releaseType=Release`；
- [ ] AGC 启用 IAP 并创建四个一次性消耗型商品；
- [ ] 沙盒账号逐档完成取消、失败、成功和消耗确认；
- [x] 现有测试群组与测试用户可复用；
- [ ] 上传并解析 1.1.1 测试 App Pack；
- [ ] 软件包合法性检测通过；
- [x] 隐私政策已通过 HTTPS 对公众可访问；
- [ ] 填写负责人联系方式、测试时间和测试人数；
- [ ] 账号持有人确认后提交邀请测试审核；
- [ ] 审核通过并生成分享链接 / 邀请码。
