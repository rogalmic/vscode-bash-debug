# -*- shell-script -*-
# info.sh - info help Routines

#   Copyright (C) 2002, 2003, 2004, 2005, 2006, 2008, 2011
#   Rocky Bernstein <rocky@gnu.org>
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

typeset -r _Dbg_info_cmds='args breakpoints display files functions line program signals source stack variables warranty'

_Dbg_info_help() {


    if (( $# == 0 )) ; then
        typeset -a list
	_Dbg_section 'List of info subcommands:'

	for thing in $_Dbg_info_cmds ; do
	    _Dbg_info_help $thing 1
	done
        return 0
    fi

  typeset subcmd="$1"
  typeset label="$2"

  if [[ -n "${_Dbg_command_help_info[$subcmd]}" ]] ; then
      if [[ -z $label ]] ; then
          _Dbg_msg_rst "${_Dbg_command_help_info[$subcmd]}"
          return 0
      else
          label=$(builtin printf "info %-12s-- " $subcmd)
      fi
  fi


  case $subcmd in
    ar | arg | args )
      _Dbg_msg \
"info args -- Argument variables (e.g. \$1, \$2, ...) of the current stack frame."
      return 0
      ;;
    b | br | bre | brea | 'break' | breakp | breakpo | breakpoints | \
    w | wa | wat | watc | 'watch' | watchp | watchpo | watchpoints )
      _Dbg_msg \
'info breakpoints -- Status of user-settable breakpoints'
      return 0
      ;;
    disp | displ | displa | display )
      _Dbg_msg \
'info display -- Show all display expressions'
      return 0
      ;;
    fi | file| files | sources )
      _Dbg_msg \
'info files -- Source files in the program'
      return 0
      ;;
    fu | fun| func | funct | functi | functio | function | functions )
      _Dbg_msg \
'info functions -- All function names'
      return 0
      ;;
    l | li| lin | line )
      _Dbg_msg \
'info line -- list current line number and and file name'
      return 0
      ;;
    p | pr | pro | prog | progr | progra | program )
      _Dbg_msg \
'info program -- Execution status of the program.'
      return 0
      ;;
    h | ha | han | hand | handl | handle | \
    si | sig | sign | signa | signal | signals )
      _Dbg_msg \
'info signals -- What debugger does when program gets various signals'
      return 0
      ;;
    so | sou | sourc | source )
      _Dbg_msg \
'info source -- Information about the current source file'
      return 0
      ;;
    st | sta | stac | stack )
      _Dbg_msg \
'info stack -- Backtrace of the stack'
      return 0
      ;;
    tr|tra|trac|trace|tracep | tracepo | tracepoi | tracepoint | tracepoints )
      _Dbg_msg \
'info tracepoints -- Status of tracepoints'
      return 0
      ;;
    v | va | var | vari | varia | variab | variabl | variable | variables )
      _Dbg_msg \
'info variables -- All global and static variable names'
      return 0
      ;;
    w | wa | war | warr | warra | warran | warrant | warranty )
      _Dbg_msg \
'info warranty -- Various kinds of warranty you do not have'
      return 0
      ;;
    * )
      _Dbg_errmsg \
    "Undefined info command: \"$subcmd\".  Try \"help info\"."
  esac
}
