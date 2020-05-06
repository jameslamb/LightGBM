
exitCode <- system2(
    command="cmake"
    , args = c(
        paste0("-G", shQuote("Visual Studio 15 2017"))
        , "-A"
        , "x64"
        , ".."
    )
    , stdout = ""
    , stderr = ""
)
print(exitCode)
