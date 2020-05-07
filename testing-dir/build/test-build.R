
# exitCode <- system2(
#     command="cmake"
#     , args = c(
#         paste0("-G", shQuote("Visual Studio 15 2017"))
#         , " -A"
#         , " x64"
#         , " .."
#     )
# )

# exitCode <- shell(
#     cmd = paste0(
#         "cmake "
#         , paste0("-G", shQuote("Visual Studio 15 2017"))
#         , " -A"
#         , " x64"
#         , " .."
#     )
#     , intern = FALSE
# )


# exitCode <- system2("try-command.bat")

install.packages('sys', repos = 'http://cran.rstudio.com')
exitCode <- sys::exec_wait(
    cmd="cmake"
    , args = c(
        "--verbose"
        , paste0("-G\"Visual Studio 15 2017\"")
        , "-A"
        , "x64"
        , " .."
    )
)
print(exitCode)
