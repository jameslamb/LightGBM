
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

# install.packages('sys', repos = 'http://cran.rstudio.com')
# exitCode <- sys::exec_wait(
#     cmd="cmake"
#     , args = c(
#         "--verbose"
#         , paste0("-G\"Visual Studio 15 2017\"")
#         , "-A"
#         , "x64"
#         , " .."
#     )
# )

print('----- sys.which -----')
print(Sys.which("cmake"))
install.packages('processx', repos = 'http://cran.rstudio.com')

print('----- processx PATH -----')
print(processx::run("echo", args = "$PATH"))

print('----- Sys.getenv() PATH -----')
print(Sys.getenv()[["PATH"]])

# print('----- system2() -----')
# exitCode <- system2(
#     command="cmake"
#     , args = c(
#         paste0("-G", shQuote("Visual Studio 15 2017"))
#         , "-A"
#         , "x64"
#         , ".."
#     )
# )
# print(exitCode)

# print('---- processx -----')
# processx::run(
#     command = "where"
#     , args = "cmake"
# )
print("cmake version processx")
processx::run(
    command = Sys.which("cmake")
    , args = "--version"
)
print("cmake version system2")
system2(
    command = Sys.which("cmake")
    , args = "--version"
)
processx::run(
    command = Sys.which("cmake")
    , args = c(
        "-G\'Visual Studio 15 2017\'"
        , "-A"
        , "x64"
        , ".."
    )
)

print(exitCode)
