# 密码保险箱（PasswordVault）— 无 Mac 免签名 iOS App

一个本地账号密码管理器：主密码加密存储 + 账号分组管理 + 密码生成器。
纯本地、无服务器，用巨魔（TrollStore）直接安装，无需开发者账号、无需签名。

## 一、这个工程里有什么

```
hellotroll-ios/
├── .github/workflows/build.yml   # GitHub 云端自动编译出 ipa 的流水线
├── project.yml                   # XcodeGen 工程描述（云端自动生成 Xcode 工程）
├── README.md                     # 本手册
└── PasswordVault/                # Swift 源码
    ├── PasswordVaultApp.swift    # App 入口
    ├── Models.swift              # 数据模型（账号类型、账号记录）
    ├── CryptoManager.swift       # 加密（主密码派生密钥 + AES 加密）
    ├── VaultStore.swift          # 数据仓库（增删改查、加解锁、改主密码）
    ├── ContentView.swift         # 根视图 + 设置主密码 + 锁屏 + 主界面
    ├── AccountViews.swift        # 账号列表 / 详情 / 添加编辑
    ├── GeneratorView.swift       # 密码生成器
    ├── SettingsView.swift        # 设置页 / 修改主密码
    └── Info.plist                # App 配置
```

## 二、一次性准备（约 30 分钟）

### 1. 注册 GitHub（已完成 ✅）
- 打开 github.com 注册，建议仓库后面设为 public（免费编译）。

### 2. 安装 GitHub Desktop
- 官网下载：https://desktop.github.com
- 安装后用你的 GitHub 账号登录。

### 3. 把工程发布到 GitHub（关键步骤）
1. 打开 GitHub Desktop。
2. 菜单 **File → Add Local Repository**（添加本地仓库）。
3. "Path" 选择这个工程文件夹：
   `C:\Users\Administrator\Doubao\chats\2026-11-04\new-chat\hellotroll-ios`
4. 点 **Add Repository**。
5. 点顶部 **Publish repository**（发布仓库）。
6. 仓库名随便，比如 `password-vault`，**Description 留空**，勾选 **Keep this code private** 或保持 public 均可（推荐 public，免费编译；代码里没有你的真实数据）。
7. 点 **Publish Repository**。

> 如果你用命令行 Git，等价操作：
> ```
> cd C:\Users\Administrator\Doubao\chats\2026-11-04\new-chat\hellotroll-ios
> git init && git add . && git commit -m "first"
> git branch -M main
> git remote add origin https://github.com/<你的用户名>/password-vault.git
> git push -u origin main
> ```

### 4. 触发云端编译
- 发布后 GitHub 会自动开始编译（Actions 标签页会跑）。
- 手动触发：仓库页面 **Actions → Build IPA → Run workflow**。

### 5. 下载编译好的 ipa
- 等 Actions 跑完（约 3-6 分钟，绿色对勾）。
- 打开那个 job，拉到最底部 **Artifacts → PasswordVault-ipa**，点下载。

### 6. 传到手机并安装
- 把下载的 `PasswordVault-ipa.zip` 解压出 `PasswordVault.ipa`。
- 用微信/网盘/数据线把 `.ipa` 发到 iPhone。
- 手机上用 **巨魔（TrollStore）** 打开这个 .ipa 文件 → 点安装。
- 回到桌面，打开"密码保险箱"，首次使用会提示设置主密码。

## 三、以后每次改功能（循环，5 分钟）

1. 告诉 AI 要加什么功能。
2. AI 改好你电脑上的工程文件。
3. 打开 GitHub Desktop → 左下角写个说明 → 点 **Commit to main** → 点 **Push origin**。
4. 等 Actions 重新编译 → 下载新 ipa → 传手机 → 巨魔重装。

## 四、常见问题

- **编译失败/变红**：把 Actions 的红色报错截图发给我，我帮你改代码。
- **装了打不开**：确认手机系统版本能被巨魔支持；确认是 Release 未签名包。
- **想换图标/App 名**：改 `Info.plist` 里的 `CFBundleDisplayName` 即可。

## 安全说明

- 所有数据用主密码派生的密钥 **AES-GCM 加密**后存本地，主密码不落盘。
- 主密码忘记无法找回（无云端、无后门），务必牢记。
- 不要把自己的真实账号密码提交进 GitHub 仓库——数据只存在于你手机里。
