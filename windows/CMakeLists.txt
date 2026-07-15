# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(bookreader LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "bookreader")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# === ONNX Runtime (flutter_onnxruntime) local vendoring ===
# Point the plugin at the locally-vendored onnxruntime BEFORE any subdirectory is
# processed, so both the app (runner) and the plugin's find_library/find_path see
# the correct path and no GitHub download occurs.
set(ONNXRUNTIME_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/onnxruntime"
    CACHE PATH "ONNX Runtime root directory" FORCE)

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.

# === ONNX Runtime (flutter_onnxruntime) local vendoring ===
# flutter_onnxruntime's Windows CMake defaults to DOWNLOADING ONNX Runtime from
# GitHub at configure time. ONNXRUNTIME_ROOT_DIR is set earlier (before
# add_subdirectory("runner")) so the plugin's find_library/find_path hit the
# local copy and no network download occurs.
include(flutter/generated_plugins.cmake)

# Defensive: flutter_onnxruntime compiles with /WX (warnings-as-errors) because
# apply_standard_settings() enables it. On a toolchain newer than the plugin
# author's, a benign warning can become a hard error and break the ENTIRE Windows
# build (no exe, no window). Relax it for this plugin only — it does not change
# runtime behavior, it just stops a warning from failing the build.
if(TARGET flutter_onnxruntime_plugin)
  target_compile_options(flutter_onnxruntime_plugin PRIVATE /WX-)
endif()

# Compute the list of ONNX Runtime runtime DLLs to bundle into the install
# (packaged) build. The POST_BUILD copy that places them next to the exe is done
# in runner/CMakeLists.txt, because add_custom_command(TARGET bookreader ...) must
# live in the same CMakeLists.txt that defines the bookreader target.
set(ONNXRUNTIME_DLL_DIR "${ONNXRUNTIME_ROOT_DIR}/lib")
if(EXISTS "${ONNXRUNTIME_DLL_DIR}")
  file(GLOB ONNXRUNTIME_RUNTIME_DLLS "${ONNXRUNTIME_DLL_DIR}/*.dll")
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# Also bundle ONNX Runtime DLLs into the packaged/installed build (the plugin's
# "system" branch does not bundle them). Mirrors the POST_BUILD copy above.
if(ONNXRUNTIME_RUNTIME_DLLS)
  install(FILES ${ONNXRUNTIME_RUNTIME_DLLS}
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()
