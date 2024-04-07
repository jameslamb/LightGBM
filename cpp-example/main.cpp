#include <string>

#include <LightGBM/c_api.h>
#include <LightGBM/dataset.h>

int main(int argc, char *argv[])
{
    const char* config = "boosting=gbdt	objective=regression num_iterations=5 verbose=1";
    std::string train_data_file("examples/regression/regression.train");
    BoosterHandle booster_handle = nullptr;
    DatasetHandle dataset_handle = nullptr;

    LGBM_DatasetCreateFromFile(
        train_data_file.c_str(),
        config,
        nullptr,
        &dataset_handle
    );

    LGBM_BoosterCreate(
        dataset_handle,
        config,
        &booster_handle
    );

    // train for 5 iterations
    int is_finished = 0;
    for(int iter=1;iter<5;iter++){
        LGBM_BoosterUpdateOneIter(
            booster_handle,
            &is_finished
        );
    }

    // write model file
    std::string model_file("model_exmple.txt");
    LGBM_BoosterSaveModel(
        booster_handle,
        0, // start_iteration
        -1, // num_iteration
        C_API_FEATURE_IMPORTANCE_SPLIT,
        model_file.c_str()
    );
}
