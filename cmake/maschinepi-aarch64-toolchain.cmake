set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

set(CMAKE_FIND_ROOT_PATH
  /usr/aarch64-linux-gnu
  /usr/lib/aarch64-linux-gnu
)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(PKG_CONFIG_EXECUTABLE /usr/bin/pkg-config CACHE FILEPATH "")
set(CMAKE_LIBRARY_PATH /usr/lib/aarch64-linux-gnu)
set(CMAKE_INCLUDE_PATH /usr/include/aarch64-linux-gnu)

# Tracktion's crill dependency calls __wfe(), which GCC does not expose as a
# builtin. Reuse the pinned application's compatibility header without
# modifying the application submodule.
get_filename_component(MPI_STATION_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(MASCHINEPI_ARM64_COMPAT
  "${MPI_STATION_ROOT}/external/maschinepi-te/pi-tools/arm64-compat.h")
set(MASCHINEPI_ARM64_FLAGS "-include ${MASCHINEPI_ARM64_COMPAT}")

if(MPI_ARM64_OVERLAY_ROOT)
  list(PREPEND CMAKE_FIND_ROOT_PATH "${MPI_ARM64_OVERLAY_ROOT}")
  string(APPEND MASCHINEPI_ARM64_FLAGS
    " -isystem ${MPI_ARM64_OVERLAY_ROOT}/usr/include/aarch64-linux-gnu")
  set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-L${MPI_ARM64_OVERLAY_ROOT}/usr/lib/aarch64-linux-gnu")
endif()

set(CMAKE_C_FLAGS_INIT "${MASCHINEPI_ARM64_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${MASCHINEPI_ARM64_FLAGS}")
