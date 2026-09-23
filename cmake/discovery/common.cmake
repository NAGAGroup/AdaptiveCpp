# Shared discovery helper.
#
# acpp_common_ancestor(<out-var> <dir> [<dir>...])
#
# The longest directory every argument sits inside, inclusive - the
# ancestor of a single directory is itself. Discovery does not assert a
# vendor's root and then check that what it found lives inside it; a
# packaging layout that does not match anyone's convention would fail
# configure over nothing but a naming choice. Instead the root is derived
# from whatever pieces were actually found: their common ancestor, which
# degenerates to "/" when a layout scatters them with nothing in common
# but the filesystem root.
#
# Included from each cmake/discovery/<vendor>.cmake that needs it, not
# from cmake/discovery.cmake, because the harnesses include a vendor file
# directly without going through the parent first.

include_guard(GLOBAL)

function(acpp_common_ancestor out_var)
  set(_acpp_anc_dirs ${ARGN})
  list(LENGTH _acpp_anc_dirs _acpp_anc_n)
  if(_acpp_anc_n EQUAL 0)
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  list(GET _acpp_anc_dirs 0 _acpp_ancestor)
  list(REMOVE_AT _acpp_anc_dirs 0)

  foreach(_acpp_anc_d IN LISTS _acpp_anc_dirs)
    while(TRUE)
      file(RELATIVE_PATH _acpp_anc_rel "${_acpp_ancestor}" "${_acpp_anc_d}")
      if(NOT _acpp_anc_rel MATCHES "^\\.\\.")
        break()
      endif()
      get_filename_component(_acpp_anc_parent "${_acpp_ancestor}" DIRECTORY)
      if(_acpp_anc_parent STREQUAL _acpp_ancestor)
        # Filesystem root reached; nothing further up to try.
        break()
      endif()
      set(_acpp_ancestor "${_acpp_anc_parent}")
    endwhile()
  endforeach()

  set(${out_var} "${_acpp_ancestor}" PARENT_SCOPE)
endfunction()
