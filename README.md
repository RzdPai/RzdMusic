# RzdMusic

洛雪音乐的鸿蒙版 - 派音

## 构建与发布

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-and-publish.ps1
```

| 参数 | 作用 |
| --- | --- |
| `-Products default` | 只构建指定 product（默认 `default,pc`） |
| `-Release` | 出正式 App Pack（`assembleApp` + release，产物 `*.app`） |
| `-SkipBuild` | 跳过编译，直接上传已有产物 |
| `-SkipNotify` | 只构建 + 上传，不发推送 |
| `-DryRun` | 只打印将执行的动作，不上传不推送 |
| `-RemoteSuffix '-pr1'` | 旁支构建，远端名加后缀，不覆盖正式包 |

### 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `DEVECO_SDK_HOME` | `D:\command-line-tools\sdk` | HarmonyOS SDK |
| `RZD_JDK_HOME` | `C:\Users\Administrator\Tools\jdk\jdk-17.0.2` | 打包阶段需要 java，缺了会 `spawn java ENOENT` |
| `HVIGOR_USER_HOME` | `<仓库>\..\.buildcache\hvigor` | 需可写 |
| `npm_config_cache` | `<仓库>\..\.buildcache\npm` | 需可写 |
| `RZD_HVIGORW` | `D:\command-line-tools\bin\hvigorw.bat` | hvigor 启动器 |
| `RZD_DAV_USER` / `RZD_DAV_PASS` | 无，**必须自己设** | 上传用的 WebDAV 账号，缺了脚本会显式报错 |

## 本地构建

```powershell
$env:DEVECO_SDK_HOME='D:\command-line-tools\sdk'
$env:HVIGOR_USER_HOME='C:\Users\Administrator\Desktop\RzdProject\.buildcache\hvigor'
$env:npm_config_cache='C:\Users\Administrator\Desktop\RzdProject\.buildcache\npm'
$env:JAVA_HOME='C:\Users\Administrator\Tools\jdk\jdk-17.0.2'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
D:\command-line-tools\bin\hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

PC 形态把 `-p product=default` 换成 `-p product=pc`；正式包换成
`assembleApp --mode project -p product=default -p buildMode=release`。
