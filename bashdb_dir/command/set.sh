# -*- shell-script -*-
# set.sh - debugger settings
#
#   Copyright (C) 2002,2003,2006,2007,2008,2010,2011 Rocky Bernstein 
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

# Sets whether or not to display command to be executed in debugger prompt.
# If yes, always show. If auto, show only if the same line is to be run
# but the command is different.

typeset -A _Dbg_debugger_set_commands
typeset -A _Dbg_command_help_set

typeset -i _Dbg_set_autoeval=0     # Evaluate unrecognized commands?

# Help routine is elsewhere which is why we have '' below.
_Dbg_help_add set '' 1 _Dbg_complete_set 

# Load in "set" subcommands
for _Dbg_file in ${_Dbg_libdir}/command/set_sub/*.sh ; do 
    source $_Dbg_file
done

# Command completion for a condition command
_Dbg_complete_set() {
    _Dbg_complete_subcmd set
}

_Dbg_do_set() {

    if (($# == 0)) ; then
	_Dbg_errmsg "Argument required (expression to compute)."
	return 1;
    fi
    typeset subcmd=$1
    typeset rc
    shift
    
    if [[ -n ${_Dbg_debugger_set_commands[$subcmd]} ]] ; then
	${_Dbg_debugger_set_commands[$subcmd]} $label "$@"
	return $?
    fi
  
    case $subcmd in 
	force )
	    _Dbg_set_onoff "$1" 'different'
	    return $?
	    ;;
	lo | log | logg | loggi | loggin | logging )
	    _Dbg_cmd_set_logging $@
	    ;;
	t|tr|tra|trac|trace|trace-|trace-c|trace-co|trace-com|trace-comm|trace-comma|trace-comman|trace-command|trace-commands )
	    _Dbg_do_set_trace_commands $@
	    ;;
	*)
	    _Dbg_undefined_cmd "set" "$subcmd"
	    return 1
    esac
    return $?
}
