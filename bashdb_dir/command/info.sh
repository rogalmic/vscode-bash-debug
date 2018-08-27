# -*- shell-script -*-
# info.sh - gdb-like "info" debugger commands
#
#   Copyright (C) 2002-2011 2016 Rocky Bernstein <rocky@gnu.org>
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

typeset -A _Dbg_debugger_info_commands
typeset -A _Dbg_command_help_info

_Dbg_help_add info '' 1 _Dbg_complete_info

# Load in "info" subcommands
for _Dbg_file in ${_Dbg_libdir}/command/info_sub/*.sh ; do
    source $_Dbg_file
done

# Command completion
_Dbg_complete_info() {
    _Dbg_complete_subcmd info
}

_Dbg_do_info() {

  if (($# > 0)) ; then
      typeset subcmd=$1
      shift

      if [[ -n ${_Dbg_debugger_info_commands[$subcmd]} ]] ; then
          ${_Dbg_debugger_info_commands[$subcmd]} "$@"
          return $?
      else
          # Look for a unique abbreviation
          typeset -i count=0
          typeset list; list="${!_Dbg_debugger_info_commands[@]}"
          for try in $list ; do
              if [[ $try =~ ^$subcmd ]] ; then
                  subcmd=$try
                  ((count++))
              fi
          done
          ((found=(count==1)))
      fi
      if ((found)); then
          ${_Dbg_debugger_info_commands[$subcmd]} "$@"
          return $?
      fi

      _Dbg_errmsg "Unknown info subcommand: $subcmd"
      msg=_Dbg_errmsg
  else
      msg=_Dbg_msg
  fi
  typeset -a list
  list=(${!_Dbg_debugger_info_commands[@]})
  sort_list 0 ${#list[@]}-1
  typeset columnized=''
  typeset -i width; ((width=_Dbg_set_linewidth-5))
  typeset -a columnized; columnize $width
  typeset -i i
  $msg "Info subcommands are:"
  for ((i=0; i<${#columnized[@]}; i++)) ; do
      $msg "  ${columnized[i]}"
  done
  return 1
}

_Dbg_alias_add i info
