# reproducible example for https://github.com/microsoft/LightGBM/issues/4464

library(fansi)
library(lightgbm)

# create a dataset from a regular R matrix
# dtrain <- lgb.Dataset(
#     data = matrix(rnorm(1000), nrow = 100)
#     , label = rnorm(100)
# )
# print("constructing")
# dtrain$construct()
# 
# print("done")


data(agaricus.train, package='lightgbm')
train <- agaricus.train
dtrain <- lgb.Dataset(train$data, label = train$label)
model <- lgb.cv(
    params = list(
        objective = "regression"
        , metric = "l2"
    )
    , data = dtrain
)
print("done")
