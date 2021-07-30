# get all exported symbols for all loaded DLLs

library(processx)

.dumpbin <- function(dll_path) {
    print(paste0("working on path ", dll_path))
    dumpbin_path <- "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.24.28314/bin/Hostx64/x64/dumpbin.exe"
    out_file = tempfile()
    result <- processx::run(
        command = dumpbin_path
        , args = c(
            "/EXPORTS"
            , dll_path
        )
        , stdout = out_file
        , error_on_status = FALSE
        , windows_verbatim_args = FALSE
    )
    contents <- readLines(out_file)
    return(contents)
}

.get_symbol_names_from_dumpbin <- function(dumpbin_content) {

    exports_start <- grep(pattern = "ordinal.*hint.*RVA", dumpbin_content) + 1
    exports_end <- grep(pattern = " Summary$", dumpbin_content) -1
    
    field_content <- trimws(dumpbin_content[exports_start:exports_end])
    field_content <- gsub("  ", " ", field_content)
    field_content <- gsub("\t", " ", field_content)
    field_content <- field_content[field_content != ""]
    
    symbol_names <- sapply(
        X = field_content
        , FUN = function(field_data) {
            splits <- strsplit(field_data, " ")[[1]]
            return(splits[[length(splits)]])
        }
        , USE.NAMES = FALSE
    )
    return(symbol_names)
}

library(data.table)
library(fansi)
library(lightgbm)
dyn.load("C:/WINDOWS/System32/WS2_32.dll")
dyn.load("C:/WINDOWS/SYSTEM32/IPHLPAPI.DLL")
dyn.load("C:/Program Files/R/R-4.1.0/bin/x64/Rlapack.dll")

dyn.load("C:/WINDOWS/SYSTEM32/ntdll.dll")
dyn.load("C:/WINDOWS/System32/KERNEL32.DLL")
dyn.load("C:/WINDOWS/System32/KERNELBASE.dll")
dyn.load("C:/WINDOWS/System32/msvcrt.dll")
dyn.load("C:/WINDOWS/System32/SHLWAPI.dll")
dyn.load("C:/WINDOWS/System32/combase.dll")
dyn.load("C:/WINDOWS/System32/ucrtbase.dll")
dyn.load("C:/WINDOWS/System32/RPCRT4.dll")
dyn.load("C:/WINDOWS/System32/bcryptPrimitives.dll")
dyn.load("C:/WINDOWS/System32/GDI32.dll")
dyn.load("C:/WINDOWS/System32/gdi32full.dll")
dyn.load("C:/WINDOWS/System32/msvcp_win.dll")
dyn.load("C:/WINDOWS/System32/USER32.dll")
dyn.load("C:/WINDOWS/System32/win32u.dll")
dyn.load("C:/Program Files/R/R-4.1.0/bin/x64/Rgraphapp.dll")
dyn.load("C:/Program Files/R/R-4.1.0/bin/x64/R.dll")
dyn.load("C:/WINDOWS/System32/comdlg32.dll")
dyn.load("C:/WINDOWS/System32/ADVAPI32.dll")
dyn.load("C:/WINDOWS/System32/sechost.dll")
dyn.load("C:/WINDOWS/System32/shcore.dll")
dyn.load("C:/WINDOWS/System32/SHELL32.dll")
dyn.load("C:/WINDOWS/System32/IMM32.dll")
dyn.load("C:/Program Files/R/R-4.1.0/bin/x64/Rblas.dll")
dyn.load("C:/WINDOWS/System32/cfgmgr32.dll")
dyn.load("C:/WINDOWS/System32/windows.storage.dll")
dyn.load("C:/WINDOWS/System32/profapi.dll")
dyn.load("C:/WINDOWS/System32/powrprof.dll")
dyn.load("C:/WINDOWS/WinSxS/amd64_microsoft.windows.common-controls_6595b64144ccf1df_6.0.17763.1577_none_de7444545348a3d0/COMCTL32.dll")
dyn.load("C:/WINDOWS/System32/kernel.appcore.dll")
dyn.load("C:/WINDOWS/System32/cryptsp.dll")
dyn.load("C:/WINDOWS/SYSTEM32/MSIMG32.dll")
dyn.load("C:/Program Files/R/R-4.1.0/bin/x64/Riconv.dll")
dyn.load("C:/WINDOWS/SYSTEM32/VERSION.dll")
dyn.load("C:/WINDOWS/SYSTEM32/WINMM.dll")
dyn.load("C:/WINDOWS/SYSTEM32/winmmbase.dll")
dyn.load("C:/WINDOWS/system32/uxtheme.dll")
dyn.load("C:/WINDOWS/System32/ole32.dll")
dyn.load("C:/WINDOWS/System32/OLEAUT32.dll")
dyn.load("C:/WINDOWS/System32/clbcatq.dll")
dyn.load("C:/WINDOWS/SYSTEM32/PROPSYS.dll")

dllDT <- data.table::rbindlist(
    l = lapply(
        X = getLoadedDLLs()
        , FUN = function(dll_info) {
            dll_path <- dll_info[["path"]]
            if (dll_path %in% c("(embedding)", "base")) {
                return(NULL)
            }
            if (any(grepl("internet", dll_path))) {
                return(NULL)
            }
            if (any(grepl("Rgraphapp", dll_path))) {
                return(NULL)
            }
            if (any(grepl("Rblas", dll_path))) {
                return(NULL)
            }
            if (any(grepl("Riconv", dll_path))) {
                return(NULL)
            }
            print(dll_path)
            return(data.table::data.table(
                name = dll_info[["name"]]
                , symbol_name = .get_symbol_names_from_dumpbin(.dumpbin(normalizePath(dll_path)))
            ))
        }
    )
)

print(dllDT[, length(symbol_name)])
print(nrow(dllDT))

duplicate_symbols <- dllDT[, .N, by = symbol_name][N > 1, ][["symbol_name"]]
dllDT[symbol_name %in% duplicate_symbols, sort(unique(name))]
