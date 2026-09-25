# The application-config template check, run with cmake -P:
#   cmake -P devops/verify/verify-app-config.cmake
#
# The application config is a plain-text KEY=value file settings.cpp reads
# at runtime: the value is the rest of the line, trimmed, and a line with
# no "=" is ignored (so a header comment must never contain one). It is
# produced by configure_file at install time from fragments at
# config/<tier>/app/<unit>.cfg, using the same three tiers as the deploy
# manifests (config/common/app/, config/<platform>/common/app/,
# config/<platform>/<arch>/app/) - so fragment values are @CMAKE_VAR@
# only, never the deploy manifest's {{ }} driver-template placeholders,
# which nothing resolves once configure_file has run.
#
# At install time every enabled unit's fragment is concatenated into the
# one settings file the runtime reads from etc/AdaptiveCpp beside itself,
# so this asserts, per platform/arch, over every unit's fragments at once:
#   (a) no fragment contains "{{";
#   (b) every non-comment line matches ^ACPP_[A-Z0-9_]+=@[A-Z0-9_]+@$;
#   (c) after concatenating every unit's fragments across the three tiers,
#       no key appears twice - proven by calling acpp_merge_all("app", ...)
#       from the shared cmake/acpp-config-merge.cmake, which FATAL_ERRORs
#       on exactly that; this harness no longer tracks keys itself.
#
# NOT done here: resolving every @VAR@ a fragment uses against the
# options files with the standard stand-ins the other harnesses use, and
# asserting non-empty. Several are legitimately empty under those
# stand-ins (e.g. ACPP_APP_SLEEF_INSTALL_ROOT when SLEEF is not
# discovered - see verify-core.cmake), so "every @VAR@ is non-empty" does
# not hold in general; left for a follow-up that can tell a legitimately-
# empty value apart from an unset one.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/acpp-config-merge.cmake)

set(_platforms_archs
  linux    x86_64
  linux    aarch64
  windows  x86_64
  windows  aarch64
  macos    arm64)

list(LENGTH _platforms_archs _pa_len)
math(EXPR _pa_last "${_pa_len} - 2")

foreach(_i RANGE 0 ${_pa_last} 2)
  math(EXPR _j "${_i} + 1")
  list(GET _platforms_archs ${_i} _platform)
  list(GET _platforms_archs ${_j} _arch)

  # The set of units for this platform/arch: the union of whatever exists
  # at the platform/common and platform/arch app/ tiers.
  set(_rels "")
  file(GLOB _common_frags "${ACPP_REPO_ROOT}/config/${_platform}/common/app/*.cfg")
  foreach(_f ${_common_frags})
    get_filename_component(_n "${_f}" NAME)
    list(APPEND _rels "app/${_n}")
  endforeach()
  file(GLOB _arch_frags "${ACPP_REPO_ROOT}/config/${_platform}/${_arch}/app/*.cfg")
  foreach(_f ${_arch_frags})
    get_filename_component(_n "${_f}" NAME)
    list(APPEND _rels "app/${_n}")
  endforeach()
  list(REMOVE_DUPLICATES _rels)

  set(_nfrags_total 0)

  foreach(_R ${_rels})
    foreach(_tier
        "config/common/${_R}"
        "config/${_platform}/common/${_R}"
        "config/${_platform}/${_arch}/${_R}")
      if(EXISTS "${ACPP_REPO_ROOT}/${_tier}")
        math(EXPR _nfrags_total "${_nfrags_total} + 1")
        file(READ "${ACPP_REPO_ROOT}/${_tier}" _text)

        # (a) no {{ }} driver-template token in an app-config fragment.
        if("${_text}" MATCHES "{{")
          message(FATAL_ERROR
            "${_tier}: contains a {{ }} driver-template token - "
            "app-config values must be @CMAKE_VAR@ only")
        endif()

        # REGEX MATCHALL builds a proper CMake list (auto-escaping any
        # literal ";" inside a match), unlike a plain string(REPLACE "\n"
        # ";" ...) + foreach, which would misread an embedded semicolon
        # (e.g. one in a comment sentence) as its own list separator and
        # silently split a single line in two.
        string(REGEX REPLACE "\r\n" "\n" _norm "${_text}")
        string(REGEX MATCHALL "[^\n]+" _lines "${_norm}")

        set(_saw_header FALSE)
        foreach(_line ${_lines})
          string(STRIP "${_line}" _line)
          if(_line STREQUAL "")
            continue()
          endif()
          if(_line MATCHES "^#")
            if(_line MATCHES "=")
              message(FATAL_ERROR
                "${_tier}: header comment contains '=' - settings.cpp "
                "would read it as a key: '${_line}'")
            endif()
            set(_saw_header TRUE)
            continue()
          endif()

          # (b) every non-comment line is ACPP_<NAME>=@CMAKE_VAR@.
          if(NOT _line MATCHES "^ACPP_[A-Z0-9_]+=@[A-Z0-9_]+@$")
            message(FATAL_ERROR
              "${_tier}: line does not match ACPP_<NAME>=@CMAKE_VAR@: '${_line}'")
          endif()
        endforeach()

        if(NOT _saw_header)
          message(FATAL_ERROR "${_tier}: missing a '#' header comment line")
        endif()
      endif()
    endforeach()
  endforeach()

  # (c) No key appears twice across every unit's fragments, across every
  # tier, for this platform/arch - at install time they all land in one
  # file. acpp_merge_all FATAL_ERRORs on exactly that; its return value
  # (the concatenated text) is not otherwise needed here, since there is
  # no app-config golden to compare it against.
  acpp_merge_all("app" "${_platform}" "${_arch}" _acpp_merged_app_text)

  message(STATUS
    "${_platform}/${_arch}: ${_nfrags_total} app-config fragment(s), no "
    "{{ }}, ACPP_<NAME>=@VAR@ shape, no duplicate keys")
endforeach()

message(STATUS "verify-app-config: (a)-(c) passed for every platform/arch")
