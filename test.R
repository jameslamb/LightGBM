# reproducible example for https://github.com/microsoft/LightGBM/issues/4464

original_options <- options()

library(fansi)
library(lightgbm)

new_options <- options()

getLoadedDLLs()

# create a dataset from a dcgMatrix
# data(agaricus.train, package='lightgbm')
# train <- agaricus.train
# dtrain <- lgb.Dataset(train$data, label = train$label)
# dtrain$construct()

# create a dataset from a regular R matrix
dtrain <- lgb.Dataset(matrix(rnorm(1000), nrow = 100), label = rnorm(100))
dtrain$construct()

print("done")

# investigating DLL

# dll_info <- getLoadedDLLs()[c("fansi", "lightgbm", "internet")]
# 
# getDLLRegisteredRoutines(dll_info$fansi[["path"]])
# getDLLRegisteredRoutines(dll_info$internet[["path"]])
# getDLLRegisteredRoutines(dll_info$lightgbm[["path"]])
# 
# getNativeSymbolInfo(
#     name = "LGBM_HandleIsNull_R"
#     , withRegistrationInfo = TRUE
#     , 
# )
# 
# dyn.unload(getLoadedDLLs()[["internet"]][["path"]])
