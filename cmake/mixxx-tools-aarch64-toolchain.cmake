set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)

set(CMAKE_FIND_ROOT_PATH
  /usr/aarch64-linux-gnu
  /usr/lib/aarch64-linux-gnu
)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(PKG_CONFIG_EXECUTABLE /usr/bin/pkg-config CACHE FILEPATH "")
set(CMAKE_LIBRARY_PATH /usr/lib/aarch64-linux-gnu)
set(CMAKE_INCLUDE_PATH
  /usr/include
  /usr/include/aarch64-linux-gnu
)

if(MPI_ARM64_OVERLAY_ROOT)
  list(PREPEND CMAKE_FIND_ROOT_PATH "${MPI_ARM64_OVERLAY_ROOT}")
  list(PREPEND CMAKE_LIBRARY_PATH
    "${MPI_ARM64_OVERLAY_ROOT}/usr/lib/aarch64-linux-gnu")
  set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-L${MPI_ARM64_OVERLAY_ROOT}/usr/lib/aarch64-linux-gnu")
endif()
