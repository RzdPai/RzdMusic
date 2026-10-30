if(NOT TARGET ijkplayer::swscale)
    add_library(ijkplayer::swscale SHARED IMPORTED)
    set_target_properties(ijkplayer::swscale PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libswscale.so")
endif()

if(NOT TARGET ijkplayer::swresample)
    add_library(ijkplayer::swresample SHARED IMPORTED)
    set_target_properties(ijkplayer::swresample PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libswresample.so")
endif()

if(NOT TARGET ijkplayer::ssl)
    add_library(ijkplayer::ssl SHARED IMPORTED)
    set_target_properties(ijkplayer::ssl PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libssl.so.3")
endif()

if(NOT TARGET ijkplayer::ijksdl)
    add_library(ijkplayer::ijksdl SHARED IMPORTED)
    set_target_properties(ijkplayer::ijksdl PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libijksdl.so")
endif()

if(NOT TARGET ijkplayer::ijkplayer_napi)
    add_library(ijkplayer::ijkplayer_napi SHARED IMPORTED)
    set_target_properties(ijkplayer::ijkplayer_napi PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libijkplayer_napi.so")
endif()

if(NOT TARGET ijkplayer::ijkplayer_audio_napi)
    add_library(ijkplayer::ijkplayer_audio_napi SHARED IMPORTED)
    set_target_properties(ijkplayer::ijkplayer_audio_napi PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libijkplayer_audio_napi.so")
endif()

if(NOT TARGET ijkplayer::ijkplayer)
    add_library(ijkplayer::ijkplayer SHARED IMPORTED)
    set_target_properties(ijkplayer::ijkplayer PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libijkplayer.so")
endif()

if(NOT TARGET ijkplayer::crypto)
    add_library(ijkplayer::crypto SHARED IMPORTED)
    set_target_properties(ijkplayer::crypto PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libcrypto.so.3")
endif()

if(NOT TARGET ijkplayer::avutil)
    add_library(ijkplayer::avutil SHARED IMPORTED)
    set_target_properties(ijkplayer::avutil PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libavutil.so")
endif()

if(NOT TARGET ijkplayer::avformat)
    add_library(ijkplayer::avformat SHARED IMPORTED)
    set_target_properties(ijkplayer::avformat PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libavformat.so")
endif()

if(NOT TARGET ijkplayer::avfilter)
    add_library(ijkplayer::avfilter SHARED IMPORTED)
    set_target_properties(ijkplayer::avfilter PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libavfilter.so")
endif()

if(NOT TARGET ijkplayer::avdevice)
    add_library(ijkplayer::avdevice SHARED IMPORTED)
    set_target_properties(ijkplayer::avdevice PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libavdevice.so")
endif()

if(NOT TARGET ijkplayer::avcodec)
    add_library(ijkplayer::avcodec SHARED IMPORTED)
    set_target_properties(ijkplayer::avcodec PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@ohos+ijkplayer@2.0.13/oh_modules/@ohos/ijkplayer/libs/arm64-v8a/libavcodec.so")
endif()
