# Download a file and retry upon failure. This looks like
# an infinite loop but CI-level timeouts will kill it
function Download-File-With-Retries {
  param(
    [string]$url,
    [string]$destfile
  )
  do {
    Write-Output "Downloading ${url}"
    sleep 5;
    (New-Object System.Net.WebClient).DownloadFile($url, $destfile)
  } while(!$?);
}

# mirrors that host miktexsetup.zip do so only with explicitly-named
# files like miktexsetup-2.4.5.zip, so hard-coding a link to an archive as a
# way to peg to one mirror does not work
#
# this function will find the specific version of miktexsetup.zip at a given
# mirror and download it
function Download-Miktex-Setup {
    param(
        [string]$archive,
        [string]$destfile
    )
    $PageContent = Invoke-WebRequest -Uri $archive -Method Get
    $SetupExeFile = $PageContent.Links.href | Select-String -Pattern 'miktexsetup.*'
    $FileToDownload = "${archive}/${SetupExeFile}"
    Download-File-With-Retries $FileToDownload $destfile
}

# External utilities like R.exe / Rscript.exe writing to stderr (even for harmless
# status information) can cause failures in GitHub Actions PowerShell jobs.
# See https://github.community/t/powershell-steps-fail-nondeterministically/115496
#
# Using standard Powershell redirection does not work to avoid these errors.
# This function uses R's built-in redirection mechanism, sink(). Any place where
# this function is used is a command that writes harmless messages to stderr
function Run-R-Code-Redirect-Stderr {
  param(
    [string]$rcode
  )
  $decorated_code = "out_file <- file(tempfile(), open = 'wt'); sink(out_file, type = 'message'); $rcode; sink()"
  Rscript --vanilla -e $decorated_code
}

$env:R_LIB_PATH = "$env:BUILD_SOURCESDIRECTORY/RLibrary" -replace '[\\]', '/'
$env:R_LIBS = "$env:R_LIB_PATH"
$env:PATH = "$env:R_LIB_PATH/Rtools/bin;" + "$env:R_LIB_PATH/Rtools/usr/bin;" + "$env:R_LIB_PATH/R/bin/x64;" + "$env:R_LIB_PATH/miktex/texmfs/install/miktex/bin/x64;" + $env:PATH
$env:CRAN_MIRROR = "https://cloud.r-project.org/"
$env:CTAN_MIRROR = "https://ctan.math.illinois.edu/systems/win32/miktex"
$env:CTAN_MIKTEX_ARCHIVE = "$env:CTAN_MIRROR/setup/windows-x64/"
$env:CTAN_PACKAGE_ARCHIVE = "$env:CTAN_MIRROR/tm/packages/"

# Get details needed for installing R components
#
# NOTES:
#    * some paths and file names are different on R4.0
$env:R_MAJOR_VERSION = $env:R_VERSION.split('.')[0]
if ($env:R_MAJOR_VERSION -eq "3") {
  $env:RTOOLS_MINGW_BIN = "$env:R_LIB_PATH/Rtools/mingw_64/bin"
  $env:RTOOLS_EXE_FILE = "Rtools35.exe"
  $env:R_WINDOWS_VERSION = "3.6.3"
} elseif ($env:R_MAJOR_VERSION -eq "4") {
  $env:RTOOLS_MINGW_BIN = "$env:R_LIB_PATH/Rtools/mingw64/bin"
  $env:RTOOLS_EXE_FILE = "rtools40-x86_64.exe"
  $env:R_WINDOWS_VERSION = "4.0.0"
} else {
  Write-Output "[ERROR] Unrecognized R version: $env:R_VERSION"
  Check-Output $false
}

if ($env:COMPILER -eq "MINGW") {
  $env:CXX = "$env:RTOOLS_MINGW_BIN/g++.exe"
  $env:CC = "$env:RTOOLS_MINGW_BIN/gcc.exe"
}

cd $env:BUILD_SOURCESDIRECTORY
tzutil /s "GMT Standard Time"
[Void][System.IO.Directory]::CreateDirectory($env:R_LIB_PATH)

if ($env:TOOLCHAIN -eq "MINGW") {
  Write-Output "Telling R to use MinGW"
  $install_libs = "$env:BUILD_SOURCESDIRECTORY/R-package/src/install.libs.R"
  ((Get-Content -Path $install_libs -Raw) -Replace 'use_mingw <- FALSE','use_mingw <- TRUE') | Set-Content -Path $install_libs
} elseif ($env:TOOLCHAIN -eq "MSYS") {
  Write-Output "Telling R to use MSYS"
  $install_libs = "$env:BUILD_SOURCESDIRECTORY/R-package/src/install.libs.R"
  ((Get-Content -Path $install_libs -Raw) -Replace 'use_msys2 <- FALSE','use_msys2 <- TRUE') | Set-Content -Path $install_libs
} elseif ($env:TOOLCHAIN -eq "MSVC") {
  # no customization for MSVC
} else {
  Write-Output "[ERROR] Unrecognized compiler: $env:TOOLCHAIN"
  Check-Output $false
}

# download R and RTools
Write-Output "Downloading R and Rtools"
Download-File-With-Retries -url "https://cloud.r-project.org/bin/windows/base/old/$env:R_WINDOWS_VERSION/R-$env:R_WINDOWS_VERSION-win.exe" -destfile "R-win.exe"
Download-File-With-Retries -url "https://cloud.r-project.org/bin/windows/Rtools/$env:RTOOLS_EXE_FILE" -destfile "Rtools.exe"

# Install R
Write-Output "Installing R"
Start-Process -FilePath R-win.exe -NoNewWindow -Wait -ArgumentList "/VERYSILENT /DIR=$env:R_LIB_PATH/R /COMPONENTS=main,x64" ; Check-Output $?
Write-Output "Done installing R"

Write-Output "Installing Rtools"
Start-Process -FilePath Rtools.exe -NoNewWindow -Wait -ArgumentList "/VERYSILENT /DIR=$env:R_LIB_PATH/Rtools" ; Check-Output $?
Write-Output "Done installing Rtools"

Write-Output "Installing dependencies"
$packages = "c('data.table', 'jsonlite', 'Matrix', 'processx', 'R6', 'testthat'), dependencies = c('Imports', 'Depends', 'LinkingTo')"
Run-R-Code-Redirect-Stderr "options(install.packages.check.source = 'no'); install.packages($packages, repos = '$env:CRAN_MIRROR', type = 'binary', lib = '$env:R_LIB_PATH')" ; Check-Output $?

# MiKTeX and pandoc can be skipped on MSVC builds, since we don't
# build the package documentation for those
if ($env:COMPILER -ne "MSVC") {
    Download-Miktex-Setup "$env:CTAN_MIKTEX_ARCHIVE" "miktexsetup-x64.zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory("miktexsetup-x64.zip", "miktex")
    Write-Output "Setting up MiKTeX"
    .\miktex\miktexsetup.exe --remote-package-repository="$env:CTAN_PACKAGE_ARCHIVE" --local-package-repository=./miktex/download --package-set=essential --quiet download ; Check-Output $?
    Write-Output "Installing MiKTeX"
    .\miktex\download\miktexsetup.exe --remote-package-repository="$env:CTAN_PACKAGE_ARCHIVE" --portable="$env:R_LIB_PATH/miktex" --quiet install ; Check-Output $?
    Write-Output "Done installing MiKTeX"

    #initexmf --set-config-value [MPM]AutoInstall=1
    # this was missing a quote before!
    Run-R-Code-Redirect-Stderr "processx::run(command = 'initexmf', args = c('--set-config-value', '[MPM]AutoInstall=1'), windows_verbatim_args = TRUE, echo = TRUE)" ; Check-Output $?

    conda install -q -y --no-deps pandoc
}

# Add redirection to testthat.R so it doesn't write to stderr
# and trigger failures on some Powershell versions.
#
# See description of Run-R-Code-Redirect-Stderr for more information
Write-Output "Adding redirection to testthat.R"
$testthat_file = "$env:BUILD_SOURCESDIRECTORY\R-package\tests\testthat.R"
$testthat_content = Get-Content -Path "$testthat_file"
Remove-Item -Path "$testthat_file"
Add-Content -Path "$testthat_file" -Value "out_file <- file(tempfile(), open = 'wt')"
Add-Content -Path "$testthat_file" -Value "sink(out_file, type = 'message')"
Add-Content -Path "$testthat_file" -Value $testthat_content
Add-Content -Path "$testthat_file" -Value "sink()"

Write-Output "Building R package"

# R CMD check is not used for MSVC builds
if ($env:COMPILER -ne "MSVC") {
  Run-R-Code-Redirect-Stderr "commandArgs <- function(...){'--skip-install'}; source('build_r.R')"; Check-Output $?

  $PKG_FILE_NAME = Get-Item *.tar.gz
  $PKG_FILE_NAME = $PKG_FILE_NAME -replace '[\\]', '/'
  $LOG_FILE_NAME = "lightgbm.Rcheck/00check.log"

  $env:_R_CHECK_FORCE_SUGGESTS_ = 0
  Write-Output "Running R CMD check as CRAN"
  Run-R-Code-Redirect-Stderr "processx::run(command = 'R.exe', args = c('CMD', 'check', '--no-multiarch', '--as-cran', '$PKG_FILE_NAME'), windows_verbatim_args = FALSE, echo = TRUE)" ; Check-Output $?

  Write-Output "R CMD check build logs:"
  $INSTALL_LOG_FILE_NAME = "$env:BUILD_SOURCESDIRECTORY\lightgbm.Rcheck\00install.out"
  Get-Content -Path "$INSTALL_LOG_FILE_NAME"

  Check-Output $check_succeeded

  Write-Output "Looking for issues with R CMD check results"
  if (Get-Content "$LOG_FILE_NAME" | Select-String -Pattern "WARNING" -Quiet) {
      echo "WARNINGS have been found by R CMD check!"
      Check-Output $False
  }

  $note_str = Get-Content "${LOG_FILE_NAME}" | Select-String -Pattern ' NOTE' | Out-String ; Check-Output $?
  $relevant_line = $note_str -match '.*Status: (\d+) NOTE.*'
  $NUM_CHECK_NOTES = $matches[1]
  $ALLOWED_CHECK_NOTES = 4
  if ([int]$NUM_CHECK_NOTES -gt $ALLOWED_CHECK_NOTES) {
      Write-Output "Found ${NUM_CHECK_NOTES} NOTEs from R CMD check. Only ${ALLOWED_CHECK_NOTES} are allowed"
      Check-Output $False
  }
} else {
  $env:TMPDIR = $env:USERPROFILE  # to avoid warnings about incremental builds inside a temp directory
  $INSTALL_LOG_FILE_NAME = "$env:BUILD_SOURCESDIRECTORY\00install_out.txt"
  Run-R-Code-Redirect-Stderr "source('build_r.R')" *> $INSTALL_LOG_FILE_NAME ; $install_succeeded = $?

  Write-Output "----- build and install logs -----"
  Get-Content -Path "$INSTALL_LOG_FILE_NAME"
  Write-Output "----- end of build and install logs -----"
  Check-Output $install_succeeded
}

# Checking that we actually got the expected compiler. The R package has some logic
# to fail back to MinGW if MSVC fails, but for CI builds we need to check that the correct
# compiler was used.
$checks = Select-String -Path "${INSTALL_LOG_FILE_NAME}" -Pattern "Check for working CXX compiler.*$env:COMPILER"
if ($checks.Matches.length -eq 0) {
  Write-Output "The wrong compiler was used. Check the build logs."
  Check-Output $False
}

# Checking that we got the right toolchain for MinGW. If using MinGW, both
# MinGW and MSYS toolchains are supported
if ($env:COMPILER -eq "MINGW") {
  $checks = Select-String -Path "${INSTALL_LOG_FILE_NAME}" -Pattern "Trying to build with.*$env:TOOLCHAIN"
  if ($checks.Matches.length -eq 0) {
    Write-Output "The wrong toolchain was used. Check the build logs."
    Check-Output $False
  }
}

if ($env:COMPILER -eq "MSVC") {
  Write-Output "Running tests with testthat.R"
  cd R-package/tests
  Run-R-Code-Redirect-Stderr "source('testthat.R')" ; Check-Output $?
}

Write-Output "No issues were found checking the R package"
