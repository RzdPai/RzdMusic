/*
 * Copyright (c) 2026 RzdPai
 *
 * libmpv 的 NAPI 桥（最小面）。
 *
 * 设计取舍：**不做事件循环**。mpv 的 wakeup/observe 回调需要常驻线程 + 跨线程回 ArkTS，
 * 复杂度高、易崩；我们改成 ArkTS 侧每 250ms 轮询 `getProperty()`（`time-pos`/`duration`/`eof-reached`/`pause`）。
 * 对"音乐播放 + 进度条"完全够用，也把 native 侧压到最小。
 *
 * 导出（ArkTS 侧见 types/libmpvnative/Index.d.ts）：
 *   create(): boolean          建实例 + 初始化（只允许一个实例，重复调用返回已有实例）
 *   command(args: string[]): boolean        例如 ['loadfile', url]
 *   setProperty(name, value): boolean       'pause'|'volume'|'speed'|'af'|'ao' …
 *   getProperty(name): string               'time-pos'|'duration'|'eof-reached'|'pause'|'media-title'
 *   isAvailable(): boolean                  探针：mpv_create 能成功即 true
 *   destroy(): void
 */

#include <string>
#include <vector>

#include <napi/native_api.h>
#include <hilog/log.h>

#include "mpv/client.h"

namespace {
constexpr const char *TAG = "RzdMpvNative";
mpv_handle *g_mpv = nullptr;

#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, 0xD001, TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0xD001, TAG, __VA_ARGS__)

/** 从 ArkTS 数组取出字符串列表（跳过非字符串项）。 */
std::vector<std::string> ToStringVector(napi_env env, napi_value value) {
    std::vector<std::string> out;
    uint32_t len = 0;
    if (napi_get_array_length(env, value, &len) != napi_ok) {
        return out;
    }
    for (uint32_t i = 0; i < len; i++) {
        napi_value item = nullptr;
        if (napi_get_element(env, value, i, &item) != napi_ok || item == nullptr) {
            continue;
        }
        size_t strLen = 0;
        if (napi_get_value_string_utf8(env, item, nullptr, 0, &strLen) != napi_ok) {
            continue;
        }
        std::string s;
        s.resize(strLen + 1);
        if (napi_get_value_string_utf8(env, item, s.data(), s.size(), &strLen) == napi_ok) {
            s.resize(strLen);
            out.push_back(s);
        }
    }
    return out;
}

/** 取单个字符串参数。 */
bool GetStringArg(napi_env env, napi_value value, std::string &out) {
    size_t len = 0;
    if (value == nullptr || napi_get_value_string_utf8(env, value, nullptr, 0, &len) != napi_ok) {
        return false;
    }
    out.resize(len + 1);
    if (napi_get_value_string_utf8(env, value, out.data(), out.size(), &len) != napi_ok) {
        return false;
    }
    out.resize(len);
    return true;
}

napi_value MakeBool(napi_env env, bool v) {
    napi_value result = nullptr;
    napi_get_boolean(env, v, &result);
    return result;
}

napi_value MakeString(napi_env env, const std::string &s) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, s.c_str(), s.size(), &result);
    return result;
}

/** 懒创建 mpv 实例（首次调用时 initialize，并注入适合音频播放的默认参数）。 */
bool EnsureInstance() {
    if (g_mpv != nullptr) {
        return true;
    }
    g_mpv = mpv_create();
    if (g_mpv == nullptr) {
        LOGE("mpv_create failed");
        return false;
    }
    // 音频优先：不建视频输出、不要窗口；日志降到 warn；缓存中等。
    mpv_set_option_string(g_mpv, "vo", "null");
    mpv_set_option_string(g_mpv, "ao", "ohaudio");
    mpv_set_option_string(g_mpv, "video", "no");
    mpv_set_option_string(g_mpv, "idle", "yes");
    mpv_set_option_string(g_mpv, "keep-open", "no");
    mpv_set_option_string(g_mpv, "cache", "yes");
    mpv_set_option_string(g_mpv, "demuxer-max-bytes", "64MiB");
    mpv_set_option_string(g_mpv, "msg-level", "all=warn");
    if (mpv_initialize(g_mpv) < 0) {
        LOGE("mpv_initialize failed");
        mpv_terminate_destroy(g_mpv);
        g_mpv = nullptr;
        return false;
    }
    LOGI("mpv initialized");
    return true;
}

napi_value JsCreate(napi_env env, napi_callback_info info) {
    return MakeBool(env, EnsureInstance());
}

napi_value JsIsAvailable(napi_env env, napi_callback_info info) {
    if (g_mpv != nullptr) {
        return MakeBool(env, true);
    }
    // 探针：建一次再销毁（避免把"可用性检查"变成常驻实例）
    return MakeBool(env, EnsureInstance());
}

napi_value JsCommand(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1 || !EnsureInstance()) {
        return MakeBool(env, false);
    }
    std::vector<std::string> args = ToStringVector(env, argv[0]);
    if (args.empty()) {
        return MakeBool(env, false);
    }
    std::vector<const char *> cargs;
    cargs.reserve(args.size() + 1);
    for (auto &s : args) {
        cargs.push_back(s.c_str());
    }
    cargs.push_back(nullptr);
    int rc = mpv_command(g_mpv, cargs.data());
    if (rc < 0) {
        LOGE("mpv_command rc=%{public}d", rc);
    }
    return MakeBool(env, rc >= 0);
}

napi_value JsSetProperty(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    std::string name;
    std::string value;
    if (argc < 2 || !EnsureInstance() || !GetStringArg(env, argv[0], name) || !GetStringArg(env, argv[1], value)) {
        return MakeBool(env, false);
    }
    int rc = mpv_set_property_string(g_mpv, name.c_str(), value.c_str());
    if (rc < 0) {
        LOGE("mpv_set_property_string %{public}s rc=%{public}d", name.c_str(), rc);
    }
    return MakeBool(env, rc >= 0);
}

napi_value JsGetProperty(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    std::string name;
    if (argc < 1 || !EnsureInstance() || !GetStringArg(env, argv[0], name)) {
        return MakeString(env, "");
    }
    char *value = mpv_get_property_string(g_mpv, name.c_str());
    if (value == nullptr) {
        return MakeString(env, "");
    }
    std::string s(value);
    mpv_free(value);
    return MakeString(env, s);
}

napi_value JsDestroy(napi_env env, napi_callback_info info) {
    if (g_mpv != nullptr) {
        mpv_terminate_destroy(g_mpv);
        g_mpv = nullptr;
        LOGI("mpv destroyed");
    }
    napi_value undef = nullptr;
    napi_get_undefined(env, &undef);
    return undef;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"create", nullptr, JsCreate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isAvailable", nullptr, JsIsAvailable, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"command", nullptr, JsCommand, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setProperty", nullptr, JsSetProperty, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getProperty", nullptr, JsGetProperty, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroy", nullptr, JsDestroy, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "mpvnative",
    .nm_priv = nullptr,
    .reserved = {0},
};
} // namespace

extern "C" __attribute__((constructor)) void RegisterMpvNativeModule() {
    napi_module_register(&g_module);
}
