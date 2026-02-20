#ifndef ZOMDROID_LOGGER_H
#define ZOMDROID_LOGGER_H

#if defined(__ANDROID__)
#include "android/log.h"

#define _LOG(priority, fmt, ...) \
  ((void)__android_log_print((priority), (LOG_TAG), (fmt), __VA_ARGS__))

#define ZD_PICK(_1, _2, _3, _4, _5, _6, _7, _8, NAME, ...) NAME

#define LOGF_1(msg) _LOG(ANDROID_LOG_FATAL, "[%s] %s", __func__, (msg))
#define LOGF_N(fmt, ...) _LOG(ANDROID_LOG_FATAL, "[%s] " fmt, __func__, __VA_ARGS__)
#define LOGF(...) ZD_PICK(__VA_ARGS__, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_1)(__VA_ARGS__)

#define LOGE_1(msg) _LOG(ANDROID_LOG_ERROR, "[%s] %s", __func__, (msg))
#define LOGE_N(fmt, ...) _LOG(ANDROID_LOG_ERROR, "[%s] " fmt, __func__, __VA_ARGS__)
#define LOGE(...) ZD_PICK(__VA_ARGS__, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_1)(__VA_ARGS__)

#define LOGW_1(msg) _LOG(ANDROID_LOG_WARN, "%s", (msg))
#define LOGW_N(fmt, ...) _LOG(ANDROID_LOG_WARN, (fmt), __VA_ARGS__)
#define LOGW(...) ZD_PICK(__VA_ARGS__, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_1)(__VA_ARGS__)

#define LOGI_1(msg) _LOG(ANDROID_LOG_INFO, "%s", (msg))
#define LOGI_N(fmt, ...) _LOG(ANDROID_LOG_INFO, (fmt), __VA_ARGS__)
#define LOGI(...) ZD_PICK(__VA_ARGS__, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_1)(__VA_ARGS__)

#define LOGD_1(msg) _LOG(ANDROID_LOG_DEBUG, "%s", (msg))
#define LOGD_N(fmt, ...) _LOG(ANDROID_LOG_DEBUG, (fmt), __VA_ARGS__)
#define LOGD(...) ZD_PICK(__VA_ARGS__, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_1)(__VA_ARGS__)

#define LOGV_1(msg) _LOG(ANDROID_LOG_VERBOSE, "%s", (msg))
#define LOGV_N(fmt, ...) _LOG(ANDROID_LOG_VERBOSE, (fmt), __VA_ARGS__)
#define LOGV(...) ZD_PICK(__VA_ARGS__, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_1)(__VA_ARGS__)
#else
#include <stdio.h>

#define _LOG(level, fmt, ...) \
  ((void)fprintf(stderr, "[%s] " level ": " fmt "\n", (LOG_TAG), __VA_ARGS__))

#define ZD_PICK(_1, _2, _3, _4, _5, _6, _7, _8, NAME, ...) NAME

#define LOGF_1(msg) _LOG("FATAL", "[%s] %s", __func__, (msg))
#define LOGF_N(fmt, ...) _LOG("FATAL", "[%s] " fmt, __func__, __VA_ARGS__)
#define LOGF(...) ZD_PICK(__VA_ARGS__, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_N, LOGF_1)(__VA_ARGS__)

#define LOGE_1(msg) _LOG("ERROR", "[%s] %s", __func__, (msg))
#define LOGE_N(fmt, ...) _LOG("ERROR", "[%s] " fmt, __func__, __VA_ARGS__)
#define LOGE(...) ZD_PICK(__VA_ARGS__, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_N, LOGE_1)(__VA_ARGS__)

#define LOGW_1(msg) _LOG("WARN", "%s", (msg))
#define LOGW_N(fmt, ...) _LOG("WARN", (fmt), __VA_ARGS__)
#define LOGW(...) ZD_PICK(__VA_ARGS__, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_N, LOGW_1)(__VA_ARGS__)

#define LOGI_1(msg) _LOG("INFO", "%s", (msg))
#define LOGI_N(fmt, ...) _LOG("INFO", (fmt), __VA_ARGS__)
#define LOGI(...) ZD_PICK(__VA_ARGS__, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_N, LOGI_1)(__VA_ARGS__)

#define LOGD_1(msg) _LOG("DEBUG", "%s", (msg))
#define LOGD_N(fmt, ...) _LOG("DEBUG", (fmt), __VA_ARGS__)
#define LOGD(...) ZD_PICK(__VA_ARGS__, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_N, LOGD_1)(__VA_ARGS__)

#define LOGV_1(msg) _LOG("VERBOSE", "%s", (msg))
#define LOGV_N(fmt, ...) _LOG("VERBOSE", (fmt), __VA_ARGS__)
#define LOGV(...) ZD_PICK(__VA_ARGS__, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_N, LOGV_1)(__VA_ARGS__)
#endif

#endif //ZOMDROID_LOGGER_H
