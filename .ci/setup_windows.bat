activate
conda config --set always_yes yes --set changeps1 no
conda update -q -y conda
conda create -q -y -n %CONDA_ENV% python=%PYTHON_VERSION% joblib matplotlib numpy pandas psutil pytest python-graphviz "scikit-learn<=0.21.3" scipy wheel
