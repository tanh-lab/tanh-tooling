cmake_minimum_required(VERSION 3.18)
# The module is meant to run before project(); do exactly that.
include(${CMAKE_CURRENT_LIST_DIR}/../../git-version.cmake)
find_program(GIT git REQUIRED)

# A scratch repository: one commit, then a tag, then a dirty tree.
set(_repo "${CMAKE_BINARY_DIR}/scratch-repo")
file(REMOVE_RECURSE "${_repo}")
file(MAKE_DIRECTORY "${_repo}")
file(WRITE "${_repo}/a.txt" "a\n")
set(_git "${GIT}" -c user.name=t -c user.email=t@t -c commit.gpgsign=false)
execute_process(COMMAND ${_git} init -q "${_repo}" COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND ${_git} -C "${_repo}" add a.txt COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND ${_git} -C "${_repo}" commit -q -m one COMMAND_ERROR_IS_FATAL ANY)

function(expect var regex)
    if(NOT "${${var}}" MATCHES "${regex}")
        message(FATAL_ERROR "${var} = '${${var}}' does not match '${regex}'")
    endif()
endfunction()

tanh_git_version("${_repo}")               # no tag: hash fallback
expect(TANH_VERSION_SHORT "^0\\.0\\.0$")
expect(TANH_VERSION_FULL "^0\\.0\\.0\\+g[0-9a-f]+$")

execute_process(COMMAND ${_git} -C "${_repo}" tag v1.2.3 COMMAND_ERROR_IS_FATAL ANY)
tanh_git_version("${_repo}")               # exactly on a tag
expect(TANH_VERSION_SHORT "^1\\.2\\.3$")
expect(TANH_VERSION_FULL "^1\\.2\\.3$")

file(APPEND "${_repo}/a.txt" "b\n")
tanh_git_version("${_repo}")               # dirty tree
expect(TANH_VERSION_FULL "^1\\.2\\.3-dirty$")

tanh_git_version("${CMAKE_BINARY_DIR}")     # not a checkout (build dir): stays 0.0.0
expect(TANH_VERSION_SHORT "^0\\.0\\.0$")

project(tanh_git_version_test VERSION ${TANH_VERSION_SHORT} LANGUAGES NONE)
enable_testing()
add_test(NAME git-version-configured COMMAND ${CMAKE_COMMAND} -E true)
