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

## 日志

允许记录：请求阶段、状态码、耗时、响应长度、布尔会话状态、解码数量和匿名响应指纹。

禁止记录：

- Cookie / Authorization / CSRF 的值；
- 用户密码、验证码和官方登录页表单内容；
- 完整私密响应正文；
- 本机证书、Profile、keystore 路径或密码；
- 可直接还原用户会话的网络快照。

## Git 与构建材料

- 公共 `build-profile.json5` 的 `signingConfigs` 必须为空。
- `*.p12`、`*.p7b`、`*.pem`、`*.key`、`*.jks`、`*.keystore`、`local.properties`、`.env*` 均不得提交。
- `artifacts/`、日志、截图、HTML 快照与 HAP 构建产物只保留在本地。
- 推送前检查 staged 文件名、文件大小和敏感关键词；发现疑似密钥时停止提交并人工确认。

## 原生边界

`scripts/NoWebOutsideLogin.ps1` 必须通过。新增 `Web`、`WebCookieManager` 或 ArkWeb import 时，必须能证明它位于授权登录边界内；否则视为架构和安全回归。

## 外部代码与资产

参考外部仓库时记录来源与固定提交，只移植已获授权且必要的实现。不得复制对方签名材料、账号数据、Cookie、私有配置或无法确认许可的品牌资产。
