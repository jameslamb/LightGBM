#' @name setLGBMThreads
#' @title Set default number of threads used by LightGBM
#' @description LightGBM attempts to speed up many operations by using multi-threading.
#'              The number of threads used in those operations can be controlled via the
#'              \code{num_threads} parameter passed through \code{params} to functions like
#'              \link{lgb.train} and \link{lgb.Dataset}. However, some operations (like materializing
#'              a model from a text file) are done via code paths that don't explicitly accept thread-control
#'              configuration.
#'
#'              Use this function to set the default number of threads LightGBM will use for such operations.
#'
#'              NOTE: This function affects all LightGBM operations in the same process. So, for example,
#'                    it can alter that number of threads used by multiple concurrent calls to \link{lgb.train}.
#' @param num_threads maximum number of threads to be used by LightGBM in multi-threaded operations
#' @return NULL
#' @seealso \link{getLGBMthreads}
#' @export
setLGBMthreads <- function(num_threads){
    .Call(
        LGBM_SetMaxThreads_R,
        num_threads
    )
    return(invisible(NULL))
}

#' @name getLGBMThreads
#' @title Get default number of threads used by LightGBM
#' @description LightGBM attempts to speed up many operations by using multi-threading.
#'              The number of threads used in those operations can be controlled via the
#'              \code{num_threads} parameter passed through \code{params} to functions like
#'              \link{lgb.train} and \link{lgb.Dataset}. However, some operations (like materializing
#'              a model from a text file) are done via code paths that don't explicitly accept thread-control
#'              configuration.
#'
#'              Use this function to see the default number of threads LightGBM will use for such operations.
#' @return number of threads as an intger. \code{-1} means that in situations where parameter \code{num_threads} is
#'         not explicitly supplied, LightGBM will choose a number of threads to use automatically.
#' @seealso \link{setLGBMthreads}
#' @export
getLGBMthreads <- function(){
    out <- integer(0L)
    .Call(
        LGBM_GetMaxThreads_R,
        out
    )
    return(out)
}
