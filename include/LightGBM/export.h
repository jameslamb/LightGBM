/*!
 * Copyright (c) 2017 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#ifndef LIGHTGBM_EXPORT_H_
#define LIGHTGBM_EXPORT_H_

/** Macros for exporting symbols in MSVC/GCC/CLANG **/

#ifdef __cplusplus
#define LIGHTGBM_EXTERN_C extern "C"
#else
#define LIGHTGBM_EXTERN_C
#endif


#ifdef _MSC_VER
#define LIGHTGBM_EXPORT __declspec(dllexport)
#define LIGHTGBM_C_EXPORT LIGHTGBM_EXTERN_C __declspec(dllexport)
#else
#define LIGHTGBM_EXPORT
#define LIGHTGBM_C_EXPORT LIGHTGBM_EXTERN_C
#endif

#if !defined(__cplusplus) && (!defined(__STDC__) || (__STDC_VERSION__ < 201112L))
/*! \brief Thread local specifier no-op in C using standards before C11. */
#define THREAD_LOCAL
#elif !defined(__cplusplus)
/*! \brief Thread local specifier. */
#define THREAD_LOCAL _Thread_local
#elif defined(_MSC_VER)
/*! \brief Thread local specifier. */
#define THREAD_LOCAL __declspec(thread)
#else
/*! \brief Thread local specifier. */
#define THREAD_LOCAL thread_local
#endif

#endif /** LIGHTGBM_EXPORT_H_ **/
