include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(category_theorie_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(category_theorie_setup_options)
  option(category_theorie_ENABLE_HARDENING "Enable hardening" ON)
  option(category_theorie_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    category_theorie_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    category_theorie_ENABLE_HARDENING
    OFF)

  category_theorie_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR category_theorie_PACKAGING_MAINTAINER_MODE)
    option(category_theorie_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(category_theorie_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(category_theorie_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(category_theorie_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(category_theorie_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(category_theorie_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(category_theorie_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(category_theorie_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(category_theorie_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(category_theorie_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(category_theorie_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(category_theorie_ENABLE_PCH "Enable precompiled headers" OFF)
    option(category_theorie_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(category_theorie_ENABLE_IPO "Enable IPO/LTO" ON)
    option(category_theorie_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(category_theorie_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(category_theorie_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(category_theorie_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(category_theorie_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(category_theorie_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(category_theorie_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(category_theorie_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(category_theorie_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(category_theorie_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(category_theorie_ENABLE_PCH "Enable precompiled headers" OFF)
    option(category_theorie_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      category_theorie_ENABLE_IPO
      category_theorie_WARNINGS_AS_ERRORS
      category_theorie_ENABLE_USER_LINKER
      category_theorie_ENABLE_SANITIZER_ADDRESS
      category_theorie_ENABLE_SANITIZER_LEAK
      category_theorie_ENABLE_SANITIZER_UNDEFINED
      category_theorie_ENABLE_SANITIZER_THREAD
      category_theorie_ENABLE_SANITIZER_MEMORY
      category_theorie_ENABLE_UNITY_BUILD
      category_theorie_ENABLE_CLANG_TIDY
      category_theorie_ENABLE_CPPCHECK
      category_theorie_ENABLE_COVERAGE
      category_theorie_ENABLE_PCH
      category_theorie_ENABLE_CACHE)
  endif()

  category_theorie_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (category_theorie_ENABLE_SANITIZER_ADDRESS OR category_theorie_ENABLE_SANITIZER_THREAD OR category_theorie_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(category_theorie_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(category_theorie_global_options)
  if(category_theorie_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    category_theorie_enable_ipo()
  endif()

  category_theorie_supports_sanitizers()

  if(category_theorie_ENABLE_HARDENING AND category_theorie_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR category_theorie_ENABLE_SANITIZER_UNDEFINED
       OR category_theorie_ENABLE_SANITIZER_ADDRESS
       OR category_theorie_ENABLE_SANITIZER_THREAD
       OR category_theorie_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${category_theorie_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${category_theorie_ENABLE_SANITIZER_UNDEFINED}")
    category_theorie_enable_hardening(category_theorie_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(category_theorie_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(category_theorie_warnings INTERFACE)
  add_library(category_theorie_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  category_theorie_set_project_warnings(
    category_theorie_warnings
    ${category_theorie_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(category_theorie_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(category_theorie_options)
  endif()

  include(cmake/Sanitizers.cmake)
  category_theorie_enable_sanitizers(
    category_theorie_options
    ${category_theorie_ENABLE_SANITIZER_ADDRESS}
    ${category_theorie_ENABLE_SANITIZER_LEAK}
    ${category_theorie_ENABLE_SANITIZER_UNDEFINED}
    ${category_theorie_ENABLE_SANITIZER_THREAD}
    ${category_theorie_ENABLE_SANITIZER_MEMORY})

  set_target_properties(category_theorie_options PROPERTIES UNITY_BUILD ${category_theorie_ENABLE_UNITY_BUILD})

  if(category_theorie_ENABLE_PCH)
    target_precompile_headers(
      category_theorie_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(category_theorie_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    category_theorie_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(category_theorie_ENABLE_CLANG_TIDY)
    category_theorie_enable_clang_tidy(category_theorie_options ${category_theorie_WARNINGS_AS_ERRORS})
  endif()

  if(category_theorie_ENABLE_CPPCHECK)
    category_theorie_enable_cppcheck(${category_theorie_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(category_theorie_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    category_theorie_enable_coverage(category_theorie_options)
  endif()

  if(category_theorie_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(category_theorie_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(category_theorie_ENABLE_HARDENING AND NOT category_theorie_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR category_theorie_ENABLE_SANITIZER_UNDEFINED
       OR category_theorie_ENABLE_SANITIZER_ADDRESS
       OR category_theorie_ENABLE_SANITIZER_THREAD
       OR category_theorie_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    category_theorie_enable_hardening(category_theorie_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
