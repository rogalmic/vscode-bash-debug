# gdb-like "commands" debugger command.
#
#   Copyright (C) 2002, 2003, 2004, 2005, 2006, 2008 Rocky Bernstein
#   <rocky@gnu.org>
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

_Dbg_help_add commands \
'commands [BKPT-NUM]

Set commands to be executed when a breakpoint is hit.

Without BKPT-NUM, the targeted breakpoint is the last one set.  The
commands themselves follow starting on the next line.  

Type a line containing "end" to indicate the end of them.  Give
"silent" as the first line to make the breakpoint silent; then no
output is printed when it is hit, except what the commands print.'

_Dbg_do_commands() {
  eval "$_seteglob"
  typeset num=$1
  typeset -i found=0
  case $num in
      $int_pat )
	  if [[ -z ${_Dbg_brkpt_file[$num]} ]] ; then
	      _Dbg_errmsg "No breakpoint number $num."
	      return 1
	  fi
	  ((found=1))
	;;
      * )
	_Dbg_errmsg "Invalid entry number skipped: $num"
  esac
  eval "$_resteglob"
  if (( found )) ; then 
      _Dbg_brkpt_commands_defining=1
      _Dbg_brkpt_commands_current=$num
      _Dbg_brkpt_commands_end[$num]=${#_Dbg_brkpt_commands[@]}
      _Dbg_brkpt_commands_start[$num]=${_Dbg_brkpt_commands_end[$num]}
      _Dbg_msg "Type commands for when breakpoint $found hit, one per line."
      _Dbg_prompt='>'
      return 0
  fi
}
