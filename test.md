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
