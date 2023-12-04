library(data.table)
library(lightgbm)

LGBM_MAX_THREADS <- as.integer(
    commandArgs(trailingOnly = TRUE)
)
if (is.na(LGBM_MAX_THREADS)){
    stop("invoke this script with an integer, like 'Rscript check-multithread.R 6'")
}

# setting this to 1 means 0 multithreading should happen
data.table::setDTthreads(1L)
lightgbm::setLGBMthreads(LGBM_MAX_THREADS)

X <- matrix(rnorm(1e5), ncol=1e5)
y <- rnorm(nrow(X))

tic <- proc.time()
print(tic)


#                  | LGBM_DatasetCreateFromMat_R()
#                  | LGBM_DatasetCreateFromMat()
#                  | LGBM_DatasetCreateFromMats()
#                  | RowFunctionFromDenseMatric()
#                  | |____ RowFunctionFromDenseMatric_helper()
# [no parallelism] | CreateSampleIndices()
#                  | ConstructFromSampleData()
# [no parallelism] | |____ DatasetLoader::CheckSampleSize()
#                  |       DatasetLoader::GetForcedBins()
#                  |       |____ Json::parse()
#                  |       BinMapper::FindBin()
#                  |       |____ std::stable_sort()
# [no parallelism] |             Common::CheckDoubleEqualOrdered()
# [no parallelism] |             FindBinWithZeroAsOneBin()
# [no parallelism] |             |____ GreedyFindBin()
# [no parallelism] |                   |____ Common::GetDoubleUpperBound()
# [no parallelism] |                         Common::CheckDoubleEqualOrdered()
# [no parallelism] |             Common::SortForPair()
# [no parallelism] |             NeedFilter()
# [commmented-out] |       CheckCategoricalFeatureNumBin()
#                  |       Construct()
# [no parallelism] |       |____ BinMapper::is_trivial()
# [no parallelism] |             OneFeaturePerGroup()
# [no parallelism] |             FastFeatureBundling()
# [no parallelism] |             |____ FixSampleIndices()
# [no parallelism] |                   |____ GetDefaultBin()
# [no parallelism] |                         GetMostFreqBin()
# [no parallelism] |                         ValueToBin()
# [no parallelism] |                   FindGroups()
# [no parallelism] |                   |____ GetDefaultBin()
# [no parallelism] |                         GetConflictCount()
# [no parallelism] |                         MarkUsed()
# [no parallelism] |       Dataset->has_raw()
# [no parallelism] |       ResizeRaw()
# [no parallelism] |       set_feature_names()
# [no parallelism] |       |____ Common::CheckAllowedJSON()
#                  |       release()
#                  |       FinishLoad()
#-----------------------------------------------------------------------
#                  | LGBM_DatasetGetFeatureNames_R()
#-----------------------------------------------------------------------
#                  | LGBM_DatasetSetField_R("label")
#-----------------------------------------------------------------------
#                  | LGBM_DatasetGetFieldSize_R("label")
#-----------------------------------------------------------------------
#                  | LGBM_DatasetGetField_R("label")
# [no parallelism] | |____ LGBM_DatasetGetField()
# [no parallelism] |       |____ Dataset::GetDoubleField()
# [no parallelism] |             Dataset::GetFloatField()
# [no parallelism] |             Dataset::GetIntField()

dtrain <- lightgbm::lgb.Dataset(
    data = X
    , label = y
    , params = list(
        max_bins = 128L
        , min_data_in_bin = 5L
        , num_threads = -1L
        , verbosity = -1L
    )
)
dtrain$construct()
toc <- proc.time() - tic
print(toc)

ratio <- toc[[1]] / toc[[3]]
print(sprintf("ratio: %f", ratio))
print("max threads: ")
print(lightgbm::getLGBMthreads())

# append to file of traces
cat(
    paste0("  ", LGBM_MAX_THREADS, "  -  ", round(ratio, 4))
    , file = "traces.out"
    , append = TRUE
    , sep = "\n"
)
