if(NOT TARGET taglib_harmony::taglib_harmony)
    add_library(taglib_harmony::taglib_harmony SHARED IMPORTED)
    set_target_properties(taglib_harmony::taglib_harmony PROPERTIES
        IMPORTED_LOCATION "C:/Users/Administrator/Desktop/RzdProject/RzdMusic/oh_modules/.ohpm/@dabing+taglib_harmony@1.0.1/oh_modules/@dabing/taglib_harmony/libs/arm64-v8a/libtaglib_harmony.so")
endif()
