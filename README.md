# iResign
This is an app for macOS that can (re)sign apps and bundle them into ipa files that are ready to be installed on an iOS device. Unrestricted by the applicationIdentifier in the ProvisioningProfile file, support ipa files containing .framework and .dylib. You can change the BundleIdentifier to implement install multiple identical applications on an iPhone (⚠️ You may not receive notification of the clone applications).

这是一个运行在 macOS 上的 ipa 文件签名（重签）工具，并且不受 ProvisioningProfile 文件中的 applicationIdentifier 限制，支持含有 Framework、dylib 的 ipa 文件。修改 BundleIdentifier 便可以实现在同一台 iPhone 上安装多个相同应用（⚠️ 但可能将收不到克隆应用的推送通知）。
![img](https://s3-qcloud.meiqiausercontent.com/pics.meiqia.bucket/5869/-/613c9c3971267497338e8fac6b7e3875.png)

## Usage

This app requires Xcode to be installed.

You need a provisioning profile and signing certificate, you can get these from Xcode by creating a new project.

You can then open up iOS App Signer and select your input file, signing certificate, provisioning file, and optionally specify a new application ID and/or application display name.

## Known issues
1. There is no support for some binary and bundle files, such as .appex


## Install


or you can download from https://github.com/liwx/iResign/releases/download/1.0/iResign.tgz