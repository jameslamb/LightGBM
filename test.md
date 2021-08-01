# Testing R crashes with other libraries

```shell
git clone --recursive git@github.com:microsoft/LightGBM.git
cd LightGBM
Rscript --vanilla -e "remove.packages('lightgbm')"
Rscript --vanilla -e "install.packages(c('R6', 'data.table', 'jsonlite'), repos = 'https://cran.r-project.org')"
sh build-cran-package.sh
R CMD INSTALL lightgbm_3.2.1.99.tar.gz
```

```shell
Rscript -e "install.packages('fansi', repos='https://cran.r-project.org')"
```

## dumpbin stuff

```shell
"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:\Users\James\Documents\R\win-library\4.1\lightgbm\libs\x64\lightgbm.dll" > lightgbm-dumpbin.txt

"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:\Users\James\Documents\R\win-library\4.1\fansi\libs\x64\fansi.dll" > fansi-dumpbin.txt

"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:\Users\James\Documents\R\win-library\4.1\xgboost\libs\x64\xgboost.dll" > xgboost-dumpbin.txt

"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:/Users/James/Documents/R/win-library/4.1/data.table/libs/x64/datatable.dll"

"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /ALL "C:\\Program Files\\R\\R-4.1.0\\modules\\x64\\internet.dll"
```

From https://cran.r-project.org/doc/manuals/R-exts.html#useDynLib

> Loading of registered object(s) occurs after the package code has been loaded and before running the load hook function

I noticed that `-shared` is being passed. This flag should be suppressed, as it says "export everything".

https://caiorss.github.io/C-Cpp-Notes/compiler-flags-options.html

"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:\Users\James\Documents\R\win-library\4.1\lightgbm\libs\x64\lightgbm.dll" > lightgbm-dumpbin.txt

* https://stackoverflow.com/questions/2170843/va-virtual-address-rva-relative-virtual-address

## ListDLLS

You can use `listdlls` to check which DLLs are loaded into a running process.

https://docs.microsoft.com/en-us/sysinternals/downloads/listdlls

I tried running `Rscript test.R` in one terminal, then run `listdlls` against it in another. Added `Sys.sleep()` to keep the process alive.

```shell
# with a Sys.sleep() added before any library() calls
"C:\Users\James\Downloads\ListDlls\ListDlls.exe" Rscript.exe | sort > no-libraries.txt

# with a Sys.sleep() added after library(fansi)
"C:\Users\James\Downloads\ListDlls\ListDlls.exe" Rscript.exe | sort > after-fansi.txt

# with a Sys.sleep() added after library(fansi) and library(lightgbm)
"C:\Users\James\Downloads\ListDlls\ListDlls.exe" Rscript.exe | sort > after-fansi-and-lightgbm.txt
```

This revealed that loading `{fansi}` also attaches the DLL `C:/Program Files/R/R-4.1.0/bin/x64/Rlapack.dll`.

```shell
"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:/Program Files/R/R-4.1.0/bin/x64/Rlapack.dll" > Rlapack-dumpbin.txt
```

And `{lightgbm}` loads these DLLs not just loaded by `{fansi}`.

```shell
0x00000000199f0000  0xf000    C:\Program Files\R\R-4.1.0\library\lattice\libs\x64\lattice.dll
0x0000000021d60000  0x3c3000  C:\Users\James\Documents\R\win-library\4.1\lightgbm\libs\x64\lightgbm.dll
0x00000000640c0000  0x22000   C:\Program Files\R\R-4.1.0\library\jsonlite\libs\x64\jsonlite.dll
0x0000000065800000  0xc0000   C:\Program Files\R\R-4.1.0\library\Matrix\libs\x64\Matrix.dll
0x0000000069300000  0xb5000   C:\Program Files\R\R-4.1.0\library\data.table\libs\x64\datatable.dll
0x000000006ea80000  0x2c000   C:\Program Files\R\R-4.1.0\library\grid\libs\x64\grid.dll
0x00000000e49b0000  0x3d000   C:\WINDOWS\SYSTEM32\IPHLPAPI.DLL
0x00000000e7d40000  0x6d000   C:\WINDOWS\System32\WS2_32.dll
```

Since I saw some issues in the `Network::` calls, I looked for conflicts in `IPHLPAPI.DLL` and `WS2_32.dll`.

```shell
"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:\WINDOWS\System32\WS2_32.dll" > ws2-32-dumpbin.txt

"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.24.28314\bin\Hostx64\x64\dumpbin.exe" /EXPORTS "C:\WINDOWS\SYSTEM32\IPHLPAPI.DLL" > iphlpapi-dumpbin.txt
```

I have a theory that some of these DLLs have conflicting exported symbols, so I wrote some R code to take the `dumpbin` results and compare them.

```r
.get_symbol_names_from_dumpbin <- function(dumpbin_file) {
    dumpbin_content <- readLines(dumpbin_file)

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
}

fansi_symbols <- gsub("FANSI_", "", .get_symbol_names_from_dumpbin("fansi-dumpbin.txt"))
iphlpapi_symbols <- .get_symbol_names_from_dumpbin("iphlpapi-dumpbin.txt")
rlapack_symbols <- .get_symbol_names_from_dumpbin("Rlapack-dumpbin.txt")
ws2_symbols     <- .get_symbol_names_from_dumpbin("ws2-32-dumpbin.txt")
lightgbm_symbols <- .get_symbol_names_from_dumpbin("lightgbm-dumpbin.txt")

intersect(iphlpapi_symbols, rlapack_symbols)
intersect(iphlpapi_symbols, fansi_symbols)

intersect(ws2_symbols, rlapack_symbols)
intersect(ws2_symbols, fansi_symbols)

intersect(iphlpapi_symbols, lightgbm_symbols)
intersect(ws2_symbols, lightgbm_symbols)
intersect(rlapack_symbols, lightgbm_symbols)
intersect(fansi_symbols, lightgbm_symbols)
```

And here's the complete list of loaded DLLs.

```text
Listdlls v3.2 - Listdlls
Copyright (C) 1997-2016 Mark Russinovich
Sysinternals

------------------------------------------------------------------------------
Rscript.exe pid: 14312
Command line: Rscript  test.R

Base                Size      Path
0x0000000000400000  0x1f000   C:\Program Files\R\R-4.1.0\bin\x64\Rscript.exe
0x0000000031c60000  0x1ed000  C:\WINDOWS\SYSTEM32\ntdll.dll
0x000000002f4d0000  0xb3000   C:\WINDOWS\System32\KERNEL32.DLL
0x000000002e710000  0x295000  C:\WINDOWS\System32\KERNELBASE.dll
0x000000002f590000  0x9e000   C:\WINDOWS\System32\msvcrt.dll
0x000000002ee80000  0x52000   C:\WINDOWS\System32\SHLWAPI.dll
0x00000000311c0000  0x32d000  C:\WINDOWS\System32\combase.dll
0x000000002e610000  0xfa000   C:\WINDOWS\System32\ucrtbase.dll
0x000000002f7a0000  0x122000  C:\WINDOWS\System32\RPCRT4.dll
0x000000002dd10000  0x7e000   C:\WINDOWS\System32\bcryptPrimitives.dll
0x000000002f360000  0x29000   C:\WINDOWS\System32\GDI32.dll
0x000000002eb00000  0x19c000  C:\WINDOWS\System32\gdi32full.dll
0x000000002e9b0000  0xa0000   C:\WINDOWS\System32\msvcp_win.dll
0x0000000031020000  0x197000  C:\WINDOWS\System32\USER32.dll
0x000000002e5a0000  0x20000   C:\WINDOWS\System32\win32u.dll
0x0000000063540000  0xaf000   C:\Program Files\R\R-4.1.0\bin\x64\Rgraphapp.dll
0x000000006c700000  0x1f6f000  C:\Program Files\R\R-4.1.0\bin\x64\R.dll
0x00000000319a0000  0x127000  C:\WINDOWS\System32\comdlg32.dll
0x0000000030f70000  0xa3000   C:\WINDOWS\System32\ADVAPI32.dll
0x00000000314f0000  0x9e000   C:\WINDOWS\System32\sechost.dll
0x0000000031ad0000  0xa8000   C:\WINDOWS\System32\shcore.dll
0x000000002f8d0000  0x14f9000  C:\WINDOWS\System32\SHELL32.dll
0x0000000030ed0000  0x2e000   C:\WINDOWS\System32\IMM32.dll
0x0000000064e80000  0x82000   C:\Program Files\R\R-4.1.0\bin\x64\Rblas.dll
0x000000002e5c0000  0x4a000   C:\WINDOWS\System32\cfgmgr32.dll
0x000000002dd90000  0x753000  C:\WINDOWS\System32\windows.storage.dll
0x000000002dce0000  0x24000   C:\WINDOWS\System32\profapi.dll
0x000000002dc80000  0x5d000   C:\WINDOWS\System32\powrprof.dll
0x00000000234b0000  0x279000  C:\WINDOWS\WinSxS\amd64_microsoft.windows.common-controls_6595b64144ccf1df_6.0.17763.1577_none_de7444545348a3d0\COMCTL32.dll
0x000000002dc40000  0x11000   C:\WINDOWS\System32\kernel.appcore.dll
0x000000002eae0000  0x17000   C:\WINDOWS\System32\cryptsp.dll
0x00000000292b0000  0x7000    C:\WINDOWS\SYSTEM32\MSIMG32.dll
0x00000000641c0000  0x60000   C:\Program Files\R\R-4.1.0\bin\x64\Riconv.dll
0x00000000263b0000  0xa000    C:\WINDOWS\SYSTEM32\VERSION.dll
0x0000000026380000  0x24000   C:\WINDOWS\SYSTEM32\WINMM.dll
0x0000000026350000  0x2d000   C:\WINDOWS\SYSTEM32\winmmbase.dll
0x000000002be10000  0x9c000   C:\WINDOWS\system32\uxtheme.dll
0x0000000031840000  0x156000  C:\WINDOWS\System32\ole32.dll
0x0000000031760000  0xc4000   C:\WINDOWS\System32\OLEAUT32.dll
0x0000000031b80000  0xa2000   C:\WINDOWS\System32\clbcatq.dll
0x000000002a0d0000  0x1a9000  C:\WINDOWS\SYSTEM32\PROPSYS.dll
0x0000000064a40000  0x14000   C:\Program Files\R\R-4.1.0\library\methods\libs\x64\methods.dll
0x00000000187b0000  0x2d000   C:\Program Files\R\R-4.1.0\library\utils\libs\x64\utils.dll
0x000000006fc80000  0x189000  C:\Program Files\R\R-4.1.0\library\grDevices\libs\x64\grDevices.dll
0x0000000063740000  0x52000   C:\Program Files\R\R-4.1.0\library\graphics\libs\x64\graphics.dll
0x0000000071100000  0xa9000   C:\Program Files\R\R-4.1.0\library\stats\libs\x64\stats.dll
0x0000000018ab0000  0x28e000  C:\Program Files\R\R-4.1.0\bin\x64\Rlapack.dll
0x00000000625c0000  0x1e000   C:\Users\James\Documents\R\win-library\4.1\fansi\libs\x64\fansi.dll
0x000000006ea80000  0x2c000   C:\Program Files\R\R-4.1.0\library\grid\libs\x64\grid.dll
0x0000000019ba0000  0xf000    C:\Program Files\R\R-4.1.0\library\lattice\libs\x64\lattice.dll
0x0000000065800000  0xc0000   C:\Program Files\R\R-4.1.0\library\Matrix\libs\x64\Matrix.dll
0x0000000069300000  0xb5000   C:\Users\James\Documents\R\win-library\4.1\data.table\libs\x64\datatable.dll
0x00000000640c0000  0x22000   C:\Program Files\R\R-4.1.0\library\jsonlite\libs\x64\jsonlite.dll
0x00000000219f0000  0x354000  C:\Users\James\Documents\R\win-library\4.1\lightgbm\libs\x64\lightgbm.dll
0x0000000030f00000  0x6d000   C:\WINDOWS\System32\WS2_32.dll
0x000000002d170000  0x3d000   C:\WINDOWS\SYSTEM32\IPHLPAPI.DLL
```

## Possibly-relevant notes in Writing R Extensions

> Linkers have a lot of freedom in how to resolve entry points in dynamically-loaded code, so the results may differ by platform. One area that has caused grief is packages including copies of standard system software such as libz (especially those already linked into R). In the case in point, entry point gzgets was sometimes resolved against the old version compiled into the package, sometimes against the copy compiled into R and sometimes against the system dynamic library. The only safe solution is to rename the entry points in the copy in the package. We have even seen problems with entry point name myprintf, which is a system entry point on some Linux systems.

> Conflicts between symbols in DLLs are handled in very platform-specific ways. Good ways to avoid trouble are to make as many symbols as possible static (check with nm -pg), and to use names which are clearly tied to your package (which also helps users if anything does go wrong). Note that symbol names starting with R_ are regarded as part of R's namespace and should not be used in packages.

> It is good practice for DLLs to register their symbols (see Registering native routines), restrict visibility (see Controlling visibility) and not allow symbol search (see Registering native routines). It should be possible for a DLL to have only one visible symbol, R_init_pkgname, on suitable platforms, which would completely avoid symbol conflicts.

> Be careful with the order of entries in macros such as PKG_LIBS. Some linkers will re-order the entries, and behaviour can differ between dynamic and static libraries. Generally -L options should precede the libraries (typically specified by -l options) to be found from those directories, and libraries are searched once in the order they are specified. Not all linkers allow a space after -L .

> The command-line tool objdump in the appropriate toolchain will also reveal what DLLs are imported from

> Whether Windows toolchains implement pthreads is up to the toolchain provider. A make variable SHLIB_PTHREAD_FLAGS is available for use in src/Makevars.win: this should be included in both PKG_CPPFLAGS (or the Fortran compiler flags) and PKG_LIBS.

> Finally, if R_init_mypkg also calls R_forceSymbols(dll, TRUE), only .Call(C_reg) will work (and not .Call("reg")). This is usually what we want: it ensures that all of our own .Call calls go directly to the intended code in our package and that no one else accidentally finds our entry points. (Should someone need to call our code from outside the package, for example for debugging, they can use .Call(mypkg:::C_reg).)

## Theory: it's about RLapack

https://github.com/search?q=org%3Acran+filename%3AMakevars.win+LAPACK_LIBS&type=code

> A macro containing the LAPACK libraries (and paths where appropriate) used when building R. This may need to be included in PKG_LIBS. It may point to a dynamic library libRlapack which contains the main double-precision LAPACK routines as well as those double-complex LAPACK routines needed to build R, or it may point to an external LAPACK library, or may be empty if an external BLAS library also contains LAPACK.

## Checking imports

Can use `dependencies.exe` to check what LightGBM needs to import.

```shell
Set dependencies="C:\Users\James\Downloads\Dependencies_x64_Release\Dependencies.exe"

%dependencies% -imports "C:\Users\James\Documents\R\win-library\4.1\lightgbm\libs\x64\lightgbm.dll"
```

Or add `-chain` to see all the DLLs loaded (recursively).

```shell
%dependencies% -imports -chain "C:\Users\James\Documents\R\win-library\4.1\fansi\libs\x64\fansi.dll"
```

## Following the ws2_32 advice

This is the linker command we got

```shell
C:/rtools40/mingw64/bin/g++ \
    -shared \
    -s \
    -static-libgcc \
    -o lightgbm.dll \
    lightgbm-win.def \
        boosting/boosting.o \
        boosting/gbdt.o \
        boosting/gbdt_model_text.o \
        boosting/gbdt_prediction.o \
        boosting/prediction_early_stop.o \
        io/bin.o \
        io/config.o \
        io/config_auto.o \
        io/dataset.o io/dataset_loader.o io/file_io.o io/json11.o io/metadata.o io/parser.o io/train_share_states.o io/tree.o metric/dcg_calculator.o metric/metric.o objective/objective_function.o network/ifaddrs_patch.o network/linker_topo.o network/linkers_mpi.o network/linkers_socket.o network/network.o treelearner/data_parallel_tree_learner.o treelearner/feature_parallel_tree_learner.o treelearner/gpu_tree_learner.o treelearner/linear_tree_learner.o treelearner/serial_tree_learner.o treelearner/tree_learner.o treelearner/voting_parallel_tree_learner.o c_api.o lightgbm_R.o \
    -fopenmp \
    -pthread \
    -lws2_32 \
    -lIphlpapi \
    -LC:/PROGRA~1/R/R-41~1.0/bin/x64 \
    -lR
```

## References

* https://developer.r-project.org/Blog/public/2018/03/23/maximum-number-of-dlls/index.html
* https://stat.ethz.ch/pipermail/r-help/2012-December/342542.html
* http://mingw.5.n7.nabble.com/Finding-dependent-dll-files-with-objdump-td4035.html
* https://docs.microsoft.com/en-us/troubleshoot/windows-client/deployment/dynamic-link-library
* https://www.jimhester.com/post/2020-08-20-best-os-for-r/
* https://stackoverflow.com/questions/57831867/do-i-actually-have-to-link-ws2-32-lib
* `{ps}` also links to `iphlpapi` and `ws2_32`! https://github.com/cran/ps/blob/31e82ffa43afb5edfe00200cab80e99ee2c43785/configure
* this thing says you need to add a new define before pulling in winsock2.h, to avoid some conflicts with an old version of `<windows.h>`!! - https://stackoverflow.com/a/11040230
    - discovered in the source of `{ps}`: https://github.com/cran/ps/blob/31e82ffa43afb5edfe00200cab80e99ee2c43785/src/api-windows-conn.c#L2-L3
    - and more on this: https://docs.microsoft.com/en-us/windows/win32/winsock/creating-a-basic-winsock-application
    - "The Iphlpapi.h header file is required if an application is using the IP Helper APIs. When the Iphlpapi.h header file is required, the #include line for the Winsock2.h header file should be placed before the #include line for the Iphlpapi.h header file."
* you also might need this pragma, see the ClickHouse source (https://github.com/cran/RClickhouse/blob/ce495690e90cbcb874ec9c48ef7e6629cbe6db06/src/vendor/clickhouse-cpp/clickhouse/base/socket.h#L10)
    - this is mentioned in https://docs.microsoft.com/en-us/windows/win32/winsock/creating-a-basic-winsock-application
* https://r-pkgs.org/src.html
* read about DLL search order at https://syedhasan010.medium.com/what-are-dlls-8027048051fc
* something about num_machines needing to be initialized?
    - https://stackoverflow.com/a/22794969
    - aha! this is uninitialized, somehow: https://stackoverflow.com/a/1226497
