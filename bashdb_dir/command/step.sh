# -*- shell-script -*-
# step.sh - Debugger step ("step into") commmand.
#
#   Copyright (C) 2006, 2008, 2009, 2010, 2015 Rocky Bernstein rocky@gnu.org
#
#   bashdb is free software; you can redistribute it and/or modify it under
#   the terms of the GNU General Public License as published by the Free
#   Software Foundation; either version 2, or (at your option) any later
#   version.
#
#   bashdb is distributed in the hope that it will be useful, but WITHOUT ANY
#   WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#   for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with bashdb; see the file COPYING.  If not, write to the Free Software
#   Foundation, 59 Temple Place, Suite 330, Boston, MA 02111 USA.

# Sets whether or not to display command to be executed in debugger prompt.
# If yes, always show. If auto, show only if the same line is to be run
# but the command is different.

# The default behavior of step_force.
typeset -i _Dbg_set_different=0

_Dbg_help_add step \
"step [COUNT]

Single step an statement. This is sometimes called 'step into'.


If COUNT is given, stepping occurs that many times before
stopping. Otherwise COUNT is one. COUNT an be an arithmetic
expression.

In contrast to \"next\", functions and source'd files are stepped
into. See also \"skip\"."

_Dbg_help_add 'step+' \
"step+ -- Single step a statement ensuring a different line after the step.

In contrast to \"step\", we ensure that the file and line position is
different from the last one just stopped at.

See also \"step-\" and \"set force\"."

_Dbg_help_add 'step-' \
"step- -- Single step a statement without the \`step force' setting.

Set step force may have been set on. step- ensures we turn that off for
this command.

See also \"step\" and \"set force\"."

# Step command
# $1 is command step+, step-, or step
# $2 is an optional additional count.
_Dbg_do_step() {

  _Dbg_not_running && return 3

  _Dbg_last_cmd="$_Dbg_cmd"
  _Dbg_last_next_step_cmd="$_Dbg_cmd"
  _Dbg_last_next_step_args="$@"

  typeset count=${1:-1}
  typeset suffix
  suffix=${_Dbg_last_next_step_cmd:${#_Dbg_last_step_next_cmd}-1:1}

  case "suffix" in
      '+' ) _Dbg_step_force=1 ;;
      '-' ) _Dbg_step_force=0 ;;
      *   ) _Dbg_step_force=$_Dbg_set_different ;;
  esac

  if [[ $count == [0-9]* ]] ; then
      _Dbg_step_ignore=${count:-1}
  else
      _Dbg_errmsg "Argument ($count) should be a number or nothing."
      _Dbg_step_ignore=-1
      return 2
  fi
  _Dbg_old_set_opts="$_Dbg_old_set_opts -o functrace"

  _Dbg_write_journal "_Dbg_step_ignore=$_Dbg_step_ignore"
  _Dbg_write_journal "_Dbg_step_force=$_Dbg_step_force"
  _Dbg_write_journal "_Dbg_old_set_opts='$_Dbg_old_set_opts'"
  _Dbg_inside_skip=0
  _Dbg_continue_rc=0
  return 0
}

_Dbg_alias_add 's'  'step'
_Dbg_alias_add 's+' 'step+'
_Dbg_alias_add 's-' 'step-'
