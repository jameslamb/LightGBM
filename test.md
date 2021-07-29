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

## References

* https://developer.r-project.org/Blog/public/2018/03/23/maximum-number-of-dlls/index.html
