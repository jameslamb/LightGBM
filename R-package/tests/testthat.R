library(testthat)
library(lightgbm)  # nolint: [unused_import]

.Call(
    lightgbm:::LGBM_SetMaxThreads_R,
    2L
)

test_check(
    package = "lightgbm"
    , stop_on_failure = TRUE
    , stop_on_warning = FALSE
    , reporter = testthat::SummaryReporter$new()
)
