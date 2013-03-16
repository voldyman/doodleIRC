# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

set (NAME doodleIRC)

project (${NAME})
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

#
# Base bits
#

enable_testing ()

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/${NAME}")
set (GETTEXT_PACKAGE "${NAME}")
set (RELEASE_NAME "Simple and non functional.")
set (VERSION "0.1")
set (VERSION_INFO "Developing")
set (CMAKE_C_FLAGS "-ggdb")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gio-2.0 gee-1.0 gtk+-3.0)

add_definitions(${DEPS_CFLAGS})

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.0" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
    src/${NAME}.vala
    src/demo.vala
    ${CMAKE_BINARY_DIR}/src/Config.vala
PACKAGES
    gee-1.0
    gio-2.0
    gtk+-3.0
OPTIONS
    -g
    --target-glib=2.32
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
    )

add_executable(${NAME} ${VALA_C})

install(TARGETS ${NAME} RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/${NAME}.desktop DESTINATION share/applications)
#install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/${NAME}.svg DESTINATION share/icons/hicolor/48x48/apps)
