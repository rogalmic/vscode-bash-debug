# -*- shell-script -*-
# save-restore.sh - saves, sets and restores debugger vars on hook entry
#
#   Copyright (C) 2002-2005, 2007-2011,
#   2014, 2017 Rocky Bernstein <rocky@gnu.org>
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation; either version 2, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; see the file COPYING.  If not, write to
#   the Free Software Foundation, 59 Temple Place, Suite 330, Boston,
#   MA 02111 USA.

# Does things to after on entry of after an eval to set some debugger
# internal settings
function _Dbg_set_debugger_internal {
  IFS="$_Dbg_space_IFS";
  PS4='+ dbg (${BASH_SOURCE}:${LINENO}[$BASH_SUBSHELL]): ${FUNCNAME[0]}\n'
}

function _Dbg_restore_user_vars {
  IFS="$_Dbg_space_IFS";
  (( _Dbg_old_set_nullglob == 0 )) && shopt -s nullglob
  set -$_Dbg_old_set_opts
  IFS="$_Dbg_old_IFS";
  PS4="$_Dbg_old_PS4"
}

_Dbg_save_args() {

    # Save values of $1 $2 $3 when debugged program was stopped
    # We use the loop below rather than _Dbg_set_args="(@)" because
    # we want to preserve embedded blanks in the arguments.
    typeset -i _Dbg_n=${#@}
    typeset -i _Dbg_i
    typeset -i _Dbg_arg_max=${#_Dbg_arg[@]}

    # If there has been a shift since the last time we entered,
    # it is possible that _Dbg_arg will contain too many values.
    # So remove those that have disappeared.
    for (( _Dbg_i=_Dbg_arg_max; _Dbg_i > _Dbg_n ; _Dbg_i-- )) ; do
	unset _Dbg_arg[$_Dbg_i]
    done

    # Populate _Dbg_arg with $1, $2, etc.
    for (( _Dbg_i=1 ; _Dbg_n > 0; _Dbg_n-- )) ; do
	_Dbg_arg[$_Dbg_i]="$1"
	((_Dbg_i++))
	shift
    done
    unset _Dbg_arg[0]       # Get rid of line number; makes array count
                            # correct; also listing all _Dbg_arg works
                            # like $*.
}

# Do things for debugger entry. Set some global debugger variables
# Remove trapping ourselves.
# We assume that we are nested two calls deep from the point of debug
# or signal fault. If this isn't the constant 2, then consider adding
# a parameter to this routine.

function _Dbg_set_debugger_entry {
  # Nuke DEBUG trap
  trap '' DEBUG

  # How many function are on the stack that are part of the debugger?
  # Normally this gets called from the trace hook. so this routine plus
  # the trace hook should are on the FUNCNAME stack and should be ignored
  typeset -li discard_top_fn_count=${1:-2}

  _Dbg_cur_fn=${FUNCNAME[$discard_top_fn_count]}
  _Dbg_frame_last_lineno=${BASH_LINENO[1]}
  ((_Dbg_frame_last_lineno < 1)) && let _Dbg_frame_last_lineno=1

  _Dbg_old_IFS="$IFS"
  _Dbg_old_PS4="$PS4"
  ((_Dbg_stack_size = ${#FUNCNAME[@]} + 1 - discard_top_fn_count))
  _Dbg_stack_pos=_0
  _Dbg_listline=_Dbg_frame_last_lineno
  _Dbg_set_debugger_internal
  _Dbg_frame_last_filename=${BASH_SOURCE[$discard_top_fn_count]:-$_Dbg_bogus_file}
  _Dbg_frame_last_filename=$(_Dbg_resolve_expand_filename "$_Dbg_frame_last_filename")

  # Read in the journal to pick up variable settings that might have
  # been left from a subshell.
  _Dbg_source_journal

  if (( _Dbg_QUIT_LEVELS > 0 )) ; then
    _Dbg_do_quit $_Dbg_debugged_exit_code
  fi
}

function _Dbg_set_to_return_from_debugger {

  _Dbg_stop_reason=''
  _Dbg_listline=0
  # FIXME: put in a frame setup routine and remove from set_entry
  _Dbg_last_lineno=${_Dbg_frame_last_lineno}
  if (( $1 != 0 )) ; then
      _Dbg_last_bash_command="$_Dbg_bash_command"
      _Dbg_last_source_file="$_Dbg_frame_last_filename"
  else
      _Dbg_last_lineno=${BASH_LINENO[1]}
      _Dbg_last_source_file=${BASH_SOURCE[2]:-$_Dbg_bogus_file}
      _Dbg_last_bash_command="**unsaved _bashdb command**"
  fi

  if (( _Dbg_restore_debug_trap )) ; then
    trap '_Dbg_debug_trap_handler 0 "$BASH_COMMAND" "$@"' DEBUG
  else
    trap - DEBUG
  fi

  _Dbg_restore_user_vars
}

_Dbg_save_state() {
  _Dbg_statefile=$(_Dbg_tempname statefile)
  echo '' > $_Dbg_statefile
  _Dbg_save_breakpoints
  _Dbg_save_actions
  _Dbg_save_watchpoints
  _Dbg_save_display
  _Dbg_save_Dbg_set
  echo "unset DBG_RESTART_FILE" >> $_Dbg_statefile
  echo "rm $_Dbg_statefile" >> $_Dbg_statefile
  export DBG_RESTART_FILE="$_Dbg_statefile"
  _Dbg_write_journal "export DBG_RESTART_FILE=\"$_Dbg_statefile\""
}

_Dbg_save_Dbg_set() {
  declare -p _Dbg_set_basename     >> $_Dbg_statefile
  declare -p _Dbg_set_debug        >> $_Dbg_statefile
  declare -p _Dbg_edit             >> $_Dbg_statefile
  declare -p _Dbg_set_listsize     >> $_Dbg_statefile
  declare -p _Dbg_prompt_str       >> $_Dbg_statefile
  declare -p _Dbg_set_show_command >> $_Dbg_statefile
}

_Dbg_restore_state() {
  typeset statefile=$1
  . $1
}

# Things we do when coming back from a nested shell.
# "shell", and "debug" create nested shells.
_Dbg_restore_from_nested_shell() {
    rm -f $_Dbg_shell_temp_profile 2>&1 >/dev/null
    if [[ -r $_Dbg_restore_info ]] ; then
	. $_Dbg_restore_info
	rm $_Dbg_restore_info
    fi
}
