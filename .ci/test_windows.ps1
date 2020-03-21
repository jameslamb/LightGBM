function Check-Output {
  param( [bool]$success )
  if (!$success) {
    $host.SetShouldExit(-1)
    Exit -1
  }
}

if ($env:TASK -eq "regular") {
  mkdir $env:BUILD_SOURCESDIRECTORY/build; cd $env:BUILD_SOURCESDIRECTORY/build
  cmake -A x64 .. ; cmake --build . --target ALL_BUILD --config Release ; Check-Output $?
  cd $env:BUILD_SOURCESDIRECTORY/python-package
  python setup.py install --precompile ; Check-Output $?
  cp $env:BUILD_SOURCESDIRECTORY/Release/lib_lightgbm.dll $env:BUILD_ARTIFACTSTAGINGDIRECTORY
  cp $env:BUILD_SOURCESDIRECTORY/Release/lightgbm.exe $env:BUILD_ARTIFACTSTAGINGDIRECTORY
}
elseif ($env:TASK -eq "sdist") {
  cd $env:BUILD_SOURCESDIRECTORY/python-package
  python setup.py sdist --formats gztar ; Check-Output $?
  cd dist; pip install @(Get-ChildItem *.gz) -v ; Check-Output $?

  $env:JAVA_HOME = $env:JAVA_HOME_8_X64  # there is pre-installed Zulu OpenJDK-8 somewhere
  Invoke-WebRequest -Uri "https://sourceforge.net/projects/swig/files/swigwin/swigwin-3.0.12/swigwin-3.0.12.zip/download" -OutFile $env:BUILD_SOURCESDIRECTORY/swig/swigwin.zip -UserAgent "NativeHost"
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory("$env:BUILD_SOURCESDIRECTORY/swig/swigwin.zip", "$env:BUILD_SOURCESDIRECTORY/swig")
  $env:PATH += ";$env:BUILD_SOURCESDIRECTORY/swig/swigwin-3.0.12"
  mkdir $env:BUILD_SOURCESDIRECTORY/build; cd $env:BUILD_SOURCESDIRECTORY/build
  cmake -A x64 -DUSE_SWIG=ON .. ; cmake --build . --target ALL_BUILD --config Release ; Check-Output $?
  cp $env:BUILD_SOURCESDIRECTORY/build/lightgbmlib.jar $env:BUILD_ARTIFACTSTAGINGDIRECTORY/lightgbmlib_win.jar
}
elseif ($env:TASK -eq "bdist") {
  cd $env:BUILD_SOURCESDIRECTORY/python-package
  python setup.py bdist_wheel --plat-name=win-amd64 --universal ; Check-Output $?
  cd dist; pip install @(Get-ChildItem *.whl) ; Check-Output $?
  cp @(Get-ChildItem *.whl) $env:BUILD_ARTIFACTSTAGINGDIRECTORY
}

if ($env:TASK -ne "r-package") {
  $tests = $env:BUILD_SOURCESDIRECTORY + $(If ($env:TASK -eq "sdist") {"/tests/python_package_test"} Else {"/tests"})  # cannot test C API with "sdist" task
  pytest $tests ; Check-Output $?
}

if ($env:TASK -eq "regular") {
  cd $env:BUILD_SOURCESDIRECTORY/examples/python-guide
  @("import matplotlib", "matplotlib.use('Agg')") + (Get-Content "plot_example.py") | Set-Content "plot_example.py"
  (Get-Content "plot_example.py").replace('graph.render(view=True)', 'graph.render(view=False)') | Set-Content "plot_example.py"
  foreach ($file in @(Get-ChildItem *.py)) {
    @("import sys, warnings", "warnings.showwarning = lambda message, category, filename, lineno, file=None, line=None: sys.stdout.write(warnings.formatwarning(message, category, filename, lineno, line))") + (Get-Content $file) | Set-Content $file
    python $file ; Check-Output $?
  }  # run all examples
  cd $env:BUILD_SOURCESDIRECTORY/examples/python-guide/notebooks
  conda install -q -y -n $env:CONDA_ENV ipywidgets notebook
  jupyter nbconvert --ExecutePreprocessor.timeout=180 --to notebook --execute --inplace *.ipynb ; Check-Output $?  # run all notebooks
}

# test R package
# based on https://github.com/RGF-team/rgf/blob/master/R-package/.R.appveyor.ps1
if ($env:TASK -eq "r-package"){

  Import-CliXml .\env-vars.clixml | % { Set-Item "env:$($_.Name)" $_.Value }
  tzutil /s "GMT Standard Time"
  [Void][System.IO.Directory]::CreateDirectory($env:R_LIB_PATH)

  $env:PATH = "$env:R_LIB_PATH\Rtools\bin;" + "$env:R_LIB_PATH\R\bin\x64;" + "$env:R_LIB_PATH\miktex\texmfs\install\miktex\bin\x64;" + $env:PATH
  $env:BINPREF = "C:/mingw-w64/x86_64-8.1.0-posix-seh-rt_v6-rev0/mingw64/bin/"

  # set up R if it doesn't exist yet
  if (!(Get-Command R.exe -errorAction SilentlyContinue)) {

      # download R and RTools
      (New-Object System.Net.WebClient).DownloadFile("https://cloud.r-project.org/bin/windows/base/R-$env:R_WINDOWS_VERSION-win.exe", "R-win.exe")
      (New-Object System.Net.WebClient).DownloadFile("https://cloud.r-project.org/bin/windows/Rtools/Rtools35.exe", "Rtools.exe")

      # Install R
      Start-Process -FilePath .\R-win.exe -NoNewWindow -Wait -ArgumentList "/VERYSILENT /DIR=$env:R_LIB_PATH\R /COMPONENTS=main,x64"
      Start-Process -FilePath .\Rtools.exe -NoNewWindow -Wait -ArgumentList "/VERYSILENT /DIR=$env:R_LIB_PATH\Rtools"

      # download Miktex
      (New-Object System.Net.WebClient).DownloadFile("https://miktex.org/download/win/miktexsetup-x64.zip", "miktexsetup-x64.zip")
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [System.IO.Compression.ZipFile]::ExtractToDirectory("miktexsetup-x64.zip", "miktex")
      .\miktex\miktexsetup.exe --local-package-repository=.\miktex\download --package-set=essential --quiet download
      .\miktex\download\miktexsetup.exe --portable="$env:R_LIB_PATH\miktex" --quiet install
  }

  initexmf --set-config-value [MPM]AutoInstall=1
  conda install -y --no-deps pandoc

  Add-Content .Renviron "R_LIBS=$env:R_LIB_PATH"
  Add-Content .Rprofile "options(repos = 'https://cran.rstudio.com')"
  Add-Content .Rprofile "options(pkgType = 'binary')"
  Add-Content .Rprofile "options(install.packages.check.source = 'no')"

  Rscript -e "install.packes(c('data.table', 'jsonlite', 'Matrix', 'R6', 'testthat'), dependencies = c('Imports', 'Depends', 'LinkingTo'))" ; Check-Output $?

  Rscript build_r.R ; Check-Output $?

  $PKG_FILE_NAME = Get-Item *.tar.gz
  $PKG_NAME = $PKG_FILE_NAME.BaseName.split("_")[0]
  $LOG_FILE_NAME = "$PKG_NAME.Rcheck/00check.log"

  R.exe CMD check "${PKG_FILE_NAME}" --as-cran --no-multiarch; Check-Output $?

  if (Get-Content "$LOG_FILE_NAME" | Select-String -Pattern "WARNING" -Quiet) {
      echo "WARNINGS have been found by R CMD check!"
      Check-Output $False
  }
}
