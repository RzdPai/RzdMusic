# 删除流光背景设置，播放页固定网格

实际开工基线：HEAD `4110791`，与请求描述的 `de74b78` 不同；已有未跟踪文件 `docs/upstream-scrubber.md` 未改动。未提交本轮更改。

## 变更清单与唯一锚点

- `features/setting/src/main/ets/view/SettingsDetailPage.ets`：`PlaybackSheet()` 删除流光 SubTitle + CapsuleSelector 整块、Local、初始化、导入。
- `features/setting/src/main/ets/view/SettingPage.ets`：旧设置页同样删除入口、Local、初始化、导入，避免删除资源后仍有引用。
- `features/setting/src/main/resources/base/element/string.json`：删除 `setting_sub_playback_flow_light`。全仓没有该 key 的 en_US 定义。
- `features/player/src/main/ets/view/PlaybackPage.ets`：删除流光状态、监听、偏好读取、shader 控制器、流光 builder/能力检测/常量、流光专用异步取色。保留共享封面 tint 发布与网格取源；原 `MeshCoverBg({...})` 构造块与 HEAD 逐字一致。原 `applyFlowLightColors` 去掉 shader 更新后改名 `applyCoverTint`，保留网格共用静默窗口重试。
- `common/musicbasic/src/main/ets/model/PlaybackFlowLightState.ets`：无使用者，删除文件。
- `common/musicbasic/Index.ets`：删除该状态导出。
- `common/musicbasic/src/main/ets/constants/Constants.ets`：删除该状态 key。
- `common/musicbasic/src/main/ets/util/MusicStoreService.ets`：保留 get/set 接口和旧偏好 key，注释明确“播放页已固定为网格背景”。

唯一新诊断关键字：`RzdPlaybackMeshOnly`；进入播放页输出 `background=mesh fixed=1`。原 `RzdBgPhaseMesh` 可继续检查网格取源和画布。日志只证明路径配置，不替代设备像素验证。

mini-bar 交接文件、ThemeState、依赖、权限未修改。

## grep 证据

全仓检索表达式：

```text
playbackFlowLight|PlaybackFlowLightState|PLAYBACK_FLOW_LIGHT_STATE|getPlaybackFlowLight|setPlaybackFlowLight|setting_sub_playback_flow_light|FLOW_LIGHT
```

修改后（本报告创建前）共 14 处匹配，全部解释如下：

| 文件 | 行号 | 保留原因 |
| --- | --- | --- |
| common/musicbasic/src/main/ets/util/MusicStoreService.ets | 44,700,705,709,714 | 旧偏好键及备份/云同步兼容接口 |
| common/musicbasic/src/main/ets/util/DataBackupService.ets | 49,228,288 | 保留旧备份导入导出格式 |
| features/player/src/main/ets/account/HuaweiCloudSync.ets | 580,643,644 | 保留旧云同步格式 |
| products/default/src/main/ets/pages/Index.ets | 475 | 原有旧 AppStorage 初始化，播放页已不消费；遵守不改壳层/mini-bar 范围 |
| common/musicbasic/src/main/ets/model/CoverTintState.ets | 19 | 共享 tint 类型的历史 HDS 说明，无流光调用 |
| docs/我的页照搬与底栏两页签-20261011.md | 55 | 历史文档，未改 |

设置 ets 与播放页对上述表达式均零匹配；整个功能目录只剩云同步 3 处兼容匹配。删除的状态类型/key、字符串资源在源码与资源零引用。该报告包含检索词，所以再次全仓搜索时需将本报告计作说明文本。

## 验证

- `git diff --check`：通过。
- `tools/check-mini-bar.ps1`：A–F 全部 PASS。
- default debug `assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`：exit 0，`BUILD SUCCESSFUL in 1 min 55 s 547 ms`。存在编译警告，完整记录见同目录 `playback-mesh-only-build.log`。
- 签名 HAP：`products/default/build/default/outputs/default/musichomesample-default-signed.hap`，23,626,632 bytes；内部 `ets/modules.abc` 命中 `RzdPlaybackMeshOnly`。
- `hdc list targets`：`[Empty]`。
- 验证等级：源码级、编译级、产物级通过，未上机，不声称已修复。

上机判据：设置页播放设置不再出现“流光背景”；播放页仍显示原有网格背景（包含旧设置曾开启/关闭两种安装数据）；打开/关闭播放器与 mini-bar 交接表现保持原样。
