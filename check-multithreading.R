library(lightgbm)

lightgbm::setLGBMthreads(3L)

X <- matrix(rnorm(1e6), ncol=1e2)
y <- rnorm(nrow(X))

tic <- proc.time()
print(tic)
dtrain <- lightgbm::lgb.Dataset(
    data = X
    , label = y
    , params = list(
        min_data_in_bin = 5L
        , max_bins = 128L
        , num_threads = 5L
    )
)
dtrain$construct()
print(proc.time() - tic)

print("max threads: ")
print(lightgbm::getLGBMthreads())
