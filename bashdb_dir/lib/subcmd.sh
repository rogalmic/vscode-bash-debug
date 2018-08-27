# -*- shell-script -*-
# subcmd.sh - Debugger Help Routines
#
#   Copyright (C) 2011 Rocky Bernstein <rocky@gnu.org>
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
# Command completion for a subcommand
typeset -A _Dbg_next_complete

_Dbg_complete_subcmd() {
    # echo "level 0 called with comp_line: $COMP_LINE , comp_point: $COMP_POINT"
    typeset -a words; 
    typeset subcmds
    IFS=' ' words=( $COMP_LINE )
    if (( ${#words[@]} == 1 )); then 
	eval "subcmds=\${!_Dbg_debugger_$1_commands[@]}"
	COMPREPLY=( $subcmds )
    elif (( ${#words[@]} == 2 )) ; then 
	eval "subcmds=\${!_Dbg_debugger_$1_commands[@]}"
	typeset commands="${!_Dbg_command_help[@]}"
	COMPREPLY=( $(compgen -W  "$subcmds" "${words[1]}" ) )
	if (( ${#COMPREPLY[@]} == 1 )) && [[ ${COMPREPLY[0]} == ${words[1]} ]]
	then 
	    IFS=' ' typeset canon_line; canon_line="${words[@]}"
	    if [[ -n ${_Dbg_next_complete[$canon_line]} && \
		$COMP_LINE =~ ' '$ ]] ; then
		${_Dbg_next_complete[$canon_line]}
	    fi
	fi
    elif [[ -n ${_Dbg_next_complete[$COMP_LINE]} ]] ; then
	${_Dbg_next_complete[$COMP_LINE]}
    else
	COMPREPLY=()
    fi
}

_Dbg_complete_onoff() {
    COMPREPLY=(on off)
}
