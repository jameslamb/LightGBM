
#library(fansi)

dyn.load(file.path(R.home(), "bin", "x64", "Rlapack.dll"))
library(lightgbm)

# .Call .Call.numParameters
# 1            has_csi                   3
# 2          strip_csi                   3
# 3        strwrap_csi                  15
# 4   state_at_pos_ext                   8
# 5            process                   1
# 6  check_assumptions                   0
# 7      digits_in_int                   1
# 8     tabs_as_spaces                   5
# 9      color_to_html                   1
# 10       esc_to_html                   4
# 11     unhandled_esc                   2
# 12        unique_chr                   1
# 13        nzchar_esc                   5
# 14           add_int                   2
# 15          strsplit                   3
# 16            cleave                   1
# 17             order                   1
# 18          sort_int                   1
# 19          sort_chr                   1
# 20       set_int_max                   1
# 21       get_int_max                   0
# 22         check_enc                   2
# 23        ctl_as_int                   1
# 24          esc_html                   1

dll_info <- getLoadedDLLs()[c("fansi", "lightgbm", "internet")]
getDLLRegisteredRoutines(getLoadedDLLs()$fansi[["path"]])

getNativeSymbolInfo("has_csi")
getNativeSymbolInfo("strip_csi")
getNativeSymbolInfo("strwrap_csi")
getNativeSymbolInfo("state_at_pos_ext")
getNativeSymbolInfo("process")
getNativeSymbolInfo("check_assumptions")
getNativeSymbolInfo("digits_in_int")
getNativeSymbolInfo("tabs_as_spaces")
getNativeSymbolInfo("color_to_html")
getNativeSymbolInfo("esc_to_html")
getNativeSymbolInfo("unhandled_esc")
getNativeSymbolInfo("unique_chr")
getNativeSymbolInfo("nzchr_esc")
getNativeSymbolInfo("add_int")
getNativeSymbolInfo("strsplit")
getNativeSymbolInfo("cleave")
getNativeSymbolInfo("order")
getNativeSymbolInfo("sort_int")
getNativeSymbolInfo("sort_chr")
getNativeSymbolInfo("set_int_max")
getNativeSymbolInfo("get_int_max")
getNativeSymbolInfo("check_enc")
getNativeSymbolInfo("ctl_as_int")
getNativeSymbolInfo("esc_html")
