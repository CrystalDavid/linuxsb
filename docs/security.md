# 安全与隐私规范

## 登录与会话

- App 不提供用户名、密码或验证码输入框；用户只在 linux.sb 官方页面登录。
- ArkWeb 只允许存在于 `OfficialLoginPage`，且只允许 linux.sb 登录流程。
- 只读取 `bbs_auth` 与 `bbs_csrf` 所需信息，在内存中构造请求 Header。
- Cookie 不写入 Preferences、文件、数据库或文档，不输出原值、片段或可逆摘要。
- 登录页关闭后销毁 ArkWeb；普通业务继续通过 RCP 请求。

## 网络与写操作

- 读请求由 Repository 通过 `RcpForumTransport` 发起。
- 新主题只允许 POST `/topic_edit`，回复只允许 POST `/reply_edit`，字段必须匹配 BBS1 v8.6.5 契约。
- 写请求必须同时具备有效内存会话和 CSRF，并且只能由用户在编辑页面明确点击触发。
- 自动测试只能使用 fake transport，禁止向真实社区创建、编辑或删除内容。
- 不增加常驻代理、中转服务器或隐藏网页网络桥。
- 图片上传走第三方外链图床（美团图床），该请求必须匿名：不携带 `bbs_auth`/`bbs_csrf` 等论坛 Cookie，也不发送 `_csrf`。`RcpForumTransport` 在图床分支中硬性跳过 Cookie 头，即使调用方误传也不会外泄。
- 上传目标白名单只允许 linux.sb 附件端点与图床主备端点，其它 URL 一律重写回论坛首页，避免把用户选择的图片发往任意地址。
- CSRF 取自 `bbs_csrf` Cookie 时必须先做 URL 解码（Cookie 值常以 `%3D` 等形式编码），否则提交会因令牌不一致被服务端拒绝。
- 写失败提示需带出 HTTP 状态码与服务端正文片段以便定位，但正文片段只取去标签后的前 120 字，不得包含 Cookie、CSRF 或完整凭据。
- 称号抽取、装备、赠送、熔炼、回收、合成、交易和烧饼兑换等 Portal 写操作必须显示明确二次确认；页面浏览和本地验收不得自动提交真实操作。
- 私信、通知、积分和钱包响应只在内存中解码为有限领域模型，不持久化原始 HTML，不在日志中记录私信正文、表单值或会话凭据。
- 私信发送必须由会话页发送按钮触发，写入目标仅允许同源数字路由 `/direct_messages/{partner_id}`；自动化验收不得点击发送。私信图片沿用匿名图床，论坛 Cookie 与 CSRF 不得发送到图床。
- 个人资料写入只允许同源 `/profile`、`/username_change`、`/avatar_upload`。用户名、简介、密码、预置头像和图库头像都必须由用户明确点击并确认；自动化验收不得提交。头像 multipart 字段固定为 `avatar`，Cookie/CSRF 只发送给 `https://linux.sb/avatar_upload`，不得复用匿名图床分支或把资料字段写入日志。

## 华为 IAP

- “投喂开发者”四档均为 `ProductType.CONSUMABLE` 一次性商品；“pro 订阅”只是档位名称，不得实现或宣传为自动续费、会员或论坛权益。
- 购买只能由用户点击明确金额后触发。弹窗展示、设置页加载、自动化截图和启动流程都不得调用 `createPurchase`。
- IAP Kit 与 LinuxSB 会话完全隔离：不得向华为传递 Cookie、CSRF、帖子、私信、头像、密码或验证码，也不得把华为购买数据附加到论坛请求。
- 应用不自建收银台，不接触银行卡、支付密码或华为账号密码。购买数据、签名、订单号和支付结果不得写入日志、Preferences、截图证据或 Git；应用只解析完成一次性商品消耗所需字段并调用 `finishPurchase`。
- 正式邀请测试前必须在 AGC 配置四个固定商品 ID，并用沙盒账号验证取消、无效商品、成功购买和消耗确认。没有沙盒或账号持有人明确确认时，真实支付统一为 `NOT RUN`。

## 日志

允许记录：请求阶段、状态码、耗时、响应长度、布尔会话状态、解码数量和匿名响应指纹。

禁止记录：

- Cookie / Authorization / CSRF 的值；
- 用户密码、验证码和官方登录页表单内容；
- 华为购买数据、订单号、签名、支付结果和支付凭据；
- 完整私密响应正文；
- 本机证书、Profile、keystore 路径或密码；
- 可直接还原用户会话的网络快照。

## Git 与构建材料

- 公共 `build-profile.json5` 的 `signingConfigs` 必须为空。
- `*.p12`、`*.p7b`、`*.pem`、`*.key`、`*.jks`、`*.keystore`、`local.properties`、`.env*` 均不得提交。
- `artifacts/`、日志、截图、HTML 快照与 HAP 构建产物只保留在本地。
- 推送前检查 staged 文件名、文件大小和敏感关键词；发现疑似密钥时停止提交并人工确认。
- AGC APP ID、IAP 商品和 release 证书属于外部发布状态；真正创建商品、上传软件包或提交审核前必须由账号持有人最终确认。

## 原生边界

`scripts/NoWebOutsideLogin.ps1` 必须通过。新增 `Web`、`WebCookieManager` 或 ArkWeb import 时，必须能证明它位于授权登录边界内；否则视为架构和安全回归。

## 外部代码与资产

参考外部仓库时记录来源与固定提交，只移植已获授权且必要的实现。不得复制对方签名材料、账号数据、Cookie、私有配置或无法确认许可的品牌资产。
