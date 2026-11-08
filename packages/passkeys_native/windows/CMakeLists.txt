cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "passkeys_native")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "passkeys_native_plugin")

add_library(${PLUGIN_NAME} SHARED
  "passkeys_native_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
# webauthn.dll is NOT linked: it is loaded at runtime (LoadLibraryExW), so
# the app still launches on Windows releases that lack it (before 10 1903).
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(passkeys_native_bundled_libraries
  ""
  PARENT_SCOPE
)
