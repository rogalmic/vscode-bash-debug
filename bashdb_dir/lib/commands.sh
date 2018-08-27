# -*- shell-script -*-
#
#   Copyright (C) 2006, 2008, 2010, 2016 Rocky Bernstein <rocky@gnu.org>
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

# Code adapted from my pydb code to do the same thing.
#================ VARIABLE INITIALIZATIONS ====================#

# associates a command list to breakpoint numbers
typeset -ai _Dbg_brkpt_commands_start=()
typeset -ai _Dbg_brkpt_commands_end=()

# The text strings for the *all* breakpoints. To get breakpoints for
# breakpoint i, this goies from _Dbg_brkpt_commands_start[i] to
# _Dbg_brkpt_commands_end[i]
#
typeset -a _Dbg_brkpt_commands=()

# For each breakpoint number, tells if the prompt must be displayed after
# execing the command list

typeset -ai _Dbg_brkpt_commands_doprompt=()

# For each breakpoint number, tells if the stack trace must be
# displayed after execing the cmd list

typeset -ai _Dbg_brkpt_commands_silent=()

typeset -i _Dbg_brkpt_commands_current=-1

# True while in the process of defining a command list
_Dbg_brkpt_commands_defining=0

# The breakpoint number for which we are defining a list
_Dbg_brkpt_commands_bnum=0

# Call every command that was set for the current active breakpoint
# (if there is one) Returns True if the normal interaction function
# must be called, False otherwise

_Dbg_bp_commands() {
    local currentbp=$1
    local lastcmd_back=$_Dbg_brkpt_lastcmd
    ## _Dbg_brkpt_setup(frame, None) ??? FIXME Probably not needed
    local -i i
    local -i start=${_Dbg_brkpt_commands_start[$currentbp]}
    local -i end=${_Dbg_brkpt_commands_end[$currentbp]}
    for (( i=start ; (( i < end )) ; i++ )) ; do
      local -a line=(${_Dbg_brkpt_commands[$i]})
      _Dbg_onecmd ${line[*]}
      _Dbg_brkpt_lastcmd=$lastcmd_back
      if (( _Dbg_brkpt_commands_doprompt[$currentbp] )) ; then
	  ###??? What's this
	  _Dbg_process_commands
	  return 0
      fi
    done
    return 1
}
