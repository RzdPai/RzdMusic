/*
 * 华为账号 / 云空间相关的**判断逻辑**（纯计算，不碰状态、不发请求）。
 *
 * 单独放一个文件的原因：两条登录路径（系统 Account Kit 与网页 OAuth）都要用同一套
 * 「这个错误码算不算‘系统路径走不通’」的判据，放在某一个服务里会让另一条链路反向依赖它。
 *
 * 官方依据：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/errorcode-account-kit
 * 日志关键字：RzdHuaweiLogin / RzdHuaweiCloud。
 */

/**
 * Account Kit 常见错误码（见 errorcode-account-kit）。
 * 用普通 `enum`（不跨模块做静态字段初始化 ⇒ 无初始化顺序依赖）。
 */
export enum HuaweiAccountCode {
  /** 应用指纹证书校验失败：AGC 未登记当前签名证书指纹 / client_id 配错 ⇒ 侧载安装必然命中。 */
  FINGERPRINT = 1001500001,
  /** 上一次请求还在处理中（重复请求）。 */
  DUPLICATE = 1001500002,
  /** 不支持该 scopes 或 permissions（含账号注册地不支持）。 */
  UNSUPPORTED = 1001500003,
  /** 设备的华为账号未登录。 */
  NOT_LOGIN = 1001502001,
  /** 应用未授权（用户没在系统页面同意）。 */
  NOT_AUTHORIZED = 1001502002,
  /** 入参无效（client_id 与实际应用不一致、签名 profile 无效等）。 */
  INVALID_PARAM = 1001502003,
  /** 网络异常。 */
  NETWORK = 1001502005,
  /** 内部错误（华为账号服务器 / 其他内部错误）。 */
  INTERNAL = 1001502009,
  /** 用户取消授权 —— 这是用户主动选择的，不该自动回退。 */
  USER_CANCEL = 1001502012,
  /** 应用未申请 scopes / permissions。 */
  NO_SCOPE = 1001502014,
  /** 系统服务异常（通用错误码，官方处理建议即「应用展示其他登录方式」）。 */
  SYSTEM = 12300001,
  /** 本应用内部的 state 一致性校验失败（自己拼的码）。 */
  STATE_MISMATCH = -10001
}

/**
 * 这个错误码是否说明「系统登录这条路在这台设备 / 这个安装包上走不通」⇒ 应自动回退网页授权。
 *
 * 判据来源（每条都取官方「可能原因」，不是猜的）：
 *   - 1001500001 应用指纹证书校验失败 —— 侧载/换签名后 AGC 指纹对不上，系统路径永远失败；
 *   - 1001502001 华为账号未登录 —— 系统登录的前提就是设备已登录华为账号；
 *   - 1001502003 入参无效 —— client_id 与实际应用不一致 / 签名 profile 无效（未上架常见）；
 *   - 1001500003 不支持该 scopes/permissions —— 账号注册地或设备不支持该能力；
 *   - 1001502014 未申请 scopes/permissions —— 应用侧没拿到该权限；
 *   - 12300001 系统服务异常 —— 官方处理建议就是「应用展示其他登录方式」。
 *
 * 明确**不**回退的：
 *   - 1001502012 用户取消授权：用户自己关掉的，回退成网页反而违背意图；
 *   - 1001502002 未授权：用户可在系统页面同意后重试，弹网页没有意义；
 *   - 1001502005 网络异常 / 1001502009 内部错误 / 1001500002 重复请求：临时性故障，重试即可。
 *
 * @param code Account Kit 抛出的错误码（0 / 未知码一律按「不明确」处理，不回退）。
 * @returns 为 true 时调用方应打开网页授权登录。
 */
export function huaweiNeedsWebFallback(code: number): boolean {
  return code === HuaweiAccountCode.FINGERPRINT ||
    code === HuaweiAccountCode.NOT_LOGIN ||
    code === HuaweiAccountCode.INVALID_PARAM ||
    code === HuaweiAccountCode.UNSUPPORTED ||
    code === HuaweiAccountCode.NO_SCOPE ||
    code === HuaweiAccountCode.SYSTEM;
}

/** 该错误码是否「系统登录能力缺失」（文案里说明侧载/签名/设备不支持）。 */
export function huaweiIsCapabilityUnavailable(code: number): boolean {
  return code === HuaweiAccountCode.FINGERPRINT ||
    code === HuaweiAccountCode.INVALID_PARAM ||
    code === HuaweiAccountCode.UNSUPPORTED;
}

/**
 * 回退原因的短文案（给用户看，也进 hilog）。
 * 只说「为什么走网页」；完整错误文案由 HuaweiAccountService.describeError 负责。
 */
export function huaweiFallbackReason(code: number): string {
  if (code === HuaweiAccountCode.FINGERPRINT) {
    return '当前安装包的签名未被系统华为账号服务识别（侧载安装常见）';
  }
  if (code === HuaweiAccountCode.NOT_LOGIN) {
    return '设备还没有登录华为账号';
  }
  if (code === HuaweiAccountCode.UNSUPPORTED) {
    return '本设备或当前华为账号不支持系统登录能力';
  }
  if (code === HuaweiAccountCode.INVALID_PARAM) {
    return '系统登录参数无效（应用未上架 / 签名 profile 不被认可）';
  }
  if (code === HuaweiAccountCode.NO_SCOPE) {
    return '应用未获得系统登录所需的权限';
  }
  if (code === HuaweiAccountCode.SYSTEM) {
    return '系统华为账号服务暂时不可用';
  }
  return '系统登录不可用';
}
