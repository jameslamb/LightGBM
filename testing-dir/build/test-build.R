
# exitCode <- system2(
#     command="cmake"
#     , args = c(
#         paste0("-G", shQuote("Visual Studio 15 2017"))
#         , "-A"
#         , "x64"
#         , " .."
#     )
# )

exitCode <- shell(
    cmd = paste0(
        "cmake "
        paste0("-G", shQuote("Visual Studio 15 2017"))
        , "-A"
        , "x64"
        , " .."
    )
    , intern = FALSE
)
print(exitCode)
