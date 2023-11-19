library(lightgbm)

lightgbm::setLGBMthreads(3L)

X <- matrix(rnorm(1e6), ncol=1e2)
y <- rnorm(nrow(X))

tic <- proc.time()
print(tic)


# LGBM_DatasetCreateFromMat_R()
# LGBM_DatasetCreateFromMat()
# LGBM_DatasetCreateFromMats()
# RowFunctionFromDenseMatric()
# |____ RowFunctionFromDenseMatric_helper()
# CreateSampleIndices()
# ConstructFromSampleData()
# FinishLoad()
dtrain <- lightgbm::lgb.Dataset(
    data = X
    , label = y
    , params = list(
        min_data_in_bin = 5L
        , max_bins = 128L
        , num_threads = -1L
    )
)
dtrain$construct()
toc <- proc.time() - tic
print(toc)

print(sprintf("ratio: %f", toc[[1]] / toc[[3]]))
print("max threads: ")
print(lightgbm::getLGBMthreads())
