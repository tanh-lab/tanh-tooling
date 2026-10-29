cmake_minimum_required(VERSION 3.18)
project(tanh_compile_commands_test CXX)
enable_testing()
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(${CMAKE_CURRENT_LIST_DIR}/../../compile-commands.cmake)

file(WRITE "${CMAKE_BINARY_DIR}/t.cpp" "int main() { return 0; }\n")
add_executable(compile_commands_test "${CMAKE_BINARY_DIR}/t.cpp")

# Every case links into a scratch directory of its own (DIRECTORY), set up afresh on each
# configure; check.cmake asserts the outcome after the build, when the database exists.
set(_cases "${CMAKE_BINARY_DIR}/cases")
file(REMOVE_RECURSE "${_cases}")

if(CMAKE_GENERATOR MATCHES "Makefiles|Ninja")
    set(_writes_database ON)
    # fresh: the directory does not exist yet
    tanh_link_compile_commands(DIRECTORY "${_cases}/fresh")
    # stale: a link to another tree is re-pointed
    file(MAKE_DIRECTORY "${_cases}/stale")
    file(CREATE_LINK "other/compile_commands.json" "${_cases}/stale/compile_commands.json" SYMBOLIC)
    tanh_link_compile_commands(DIRECTORY "${_cases}/stale")
    # file: a tree configured into the directory owns the regular file there; it stays
    file(WRITE "${_cases}/file/compile_commands.json" "[]\n")
    tanh_link_compile_commands(DIRECTORY "${_cases}/file")
    # the build tree itself: the database is already there, nothing is linked
    tanh_link_compile_commands(DIRECTORY "${CMAKE_BINARY_DIR}")
    # export off: no database, nothing is linked (a function scope keeps the change local)
    function(_link_without_export)
        set(CMAKE_EXPORT_COMPILE_COMMANDS OFF)
        tanh_link_compile_commands(DIRECTORY "${_cases}/export-off")
    endfunction()
    _link_without_export()
    # a subproject's call does nothing
    add_subdirectory(sub)
else()
    # Visual Studio and Xcode write no database: the call warns and links nothing
    set(_writes_database OFF)
    tanh_link_compile_commands(DIRECTORY "${_cases}/fresh")
endif()

add_test(NAME compile_commands_link
    COMMAND "${CMAKE_COMMAND}" "-DTREE=${CMAKE_BINARY_DIR}" "-DWRITES_DATABASE=${_writes_database}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/check.cmake")
