
exitCode <- system(
    paste0(
        "cmake -G"
        , shQuote("Visual Studio 15 2017")
        , " -A x64 .."
    )
)
