function Check-Output {
  param( [bool]$success )
  if (!$success) {
    $host.SetShouldExit(-1)
    Exit -1
  }
}

# unify environment variables for Azure devops and AppVeyor
if (Test-Path env:APPVEYOR) {
  $env:BUILD_SOURCESDIRECTORY = $env:APPVEYOR_BUILD_FOLDER
}

Write-Output "CONDA_ENV: '$env:CONDA_ENV'"
Write-Output "PYTHON_VERSION: '$env:PYTHON_VERSION'"

# setup for Python
activate
conda config --set always_yes yes --set changeps1 no
conda update -q -y conda
conda create -q -y -n $env:CONDA_ENV python=$env:PYTHON_VERSION joblib matplotlib numpy pandas psutil pytest python-graphviz "scikit-learn<=0.21.3" scipy wheel
activate $env:CONDA_ENV
Write-Output "Fixing path"
pytest
Write-Output "hey it works"
cd $env:BUILD_SOURCESDIRECTORY\python-package
Write-Output "Using compiler: '$env:COMPILER'"
if ($env:COMPILER -eq "MINGW") {
  python setup.py install --mingw
} else {
  python setup.py install
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

$tests = $env:BUILD_SOURCESDIRECTORY + $(If ($env:TASK -eq "sdist") {"/tests/python_package_test"} Else {"/tests"})  # cannot test C API with "sdist" task
pytest $tests ; Check-Output $?

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
