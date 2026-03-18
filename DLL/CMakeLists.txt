cmake_minimum_required(VERSION 3.20)
project(NexusConfluence VERSION 3.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Force 64-bit build (MT5 is 64-bit)
if(NOT CMAKE_GENERATOR_PLATFORM)
    set(CMAKE_GENERATOR_PLATFORM x64)
endif()

# DLL output
add_library(NexusConfluence SHARED
    # API
    src/nexus_api.cpp

    # Indicators
    src/indicators/gg_trendbar.cpp
    src/indicators/trend_magic.cpp
    src/indicators/obv_macd.cpp
    src/indicators/rsi_oma.cpp
    src/indicators/currency_strength.cpp

    # Gates
    src/gates/gate_system.cpp
)

target_include_directories(NexusConfluence PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_definitions(NexusConfluence PRIVATE
    NEXUS_DLL_EXPORTS
    _CRT_SECURE_NO_WARNINGS
)

# License mode: NEXUS_OPEN disables license checks (creator build)
# Usage: cmake -DNEXUS_OPEN=ON ..   (for your personal use)
#        cmake ..                     (for commercial build, license required)
option(NEXUS_OPEN "Build without license checks (creator/developer)" ON)
if(NEXUS_OPEN)
    target_compile_definitions(NexusConfluence PRIVATE NEXUS_OPEN)
    message(STATUS ">>> OPEN BUILD: License checks DISABLED <<<")
else()
    message(STATUS ">>> COMMERCIAL BUILD: License checks ENABLED <<<")
endif()

# Compiler-specific settings
if(MSVC)
    target_compile_options(NexusConfluence PRIVATE
        /W4             # Warning level 4
        /O2             # Optimize for speed
        /GL             # Whole program optimization
        /Gy             # Function-level linking
    )
    target_link_options(NexusConfluence PRIVATE
        /LTCG           # Link-time code generation
    )
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    target_compile_options(NexusConfluence PRIVATE
        -Wall -Wextra   # Warnings
        -O2             # Optimize for speed
        -Wno-unused-parameter
    )
    # Ensure proper DLL exports with MinGW
    target_link_options(NexusConfluence PRIVATE
        -static-libgcc -static-libstdc++  # Static link runtime (no extra DLLs needed)
    )
endif()

# Export .def file for clean exports (optional, __declspec handles it)
# set_target_properties(NexusConfluence PROPERTIES
#     LINK_FLAGS "/DEF:${CMAKE_CURRENT_SOURCE_DIR}/NexusConfluence.def"
# )

# Output directory
set_target_properties(NexusConfluence PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    OUTPUT_NAME "NexusConfluence"
    PREFIX ""
)

# Install target (copies to MQL5/Libraries)
set(MT5_MQL5_DIR "C:/Users/santospaulo/AppData/Roaming/MetaQuotes/Terminal/FEC98F1D078C037902D797DB372EA18E/MQL5")

install(TARGETS NexusConfluence
    RUNTIME DESTINATION "${MT5_MQL5_DIR}/Libraries"
)

# Tests (Phase 6)
# option(BUILD_TESTS "Build unit tests" ON)
# if(BUILD_TESTS)
#     enable_testing()
#     add_executable(nexus_tests
#         tests/test_indicators.cpp
#         tests/test_gates.cpp
#         tests/test_risk.cpp
#         tests/test_integration.cpp
#     )
#     target_include_directories(nexus_tests PRIVATE include)
#     target_link_libraries(nexus_tests PRIVATE NexusConfluence)
#     add_test(NAME NexusTests COMMAND nexus_tests)
# endif()
