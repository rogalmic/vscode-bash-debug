# -*- shell-script -*-
# help.sh - gdb-like "help" debugger command
#
#   Copyright (C) 2002-2006, 2008, 2010-2011, 2015
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

if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    dirname=${BASH_SOURCE[0]%/*}
    [[ $dirname == $0 ]] && top_dir='..' || top_dir=${dirname}/..
    for file in help alias ; do source $top_dir/lib/${file}.sh; done
fi

_Dbg_help_add help \
'**help** [*command* [*subcommand* ..]]

If no arguments are given, print a list of command names.
With a command name give help for that command. For many commands
you can get further detailed help by listing the subcommand name.

Examples:
---------

  help
  help up
  help set
  help set args' 1 _Dbg_complete_help

_Dbg_complete_help() {
    typeset -a words;
    IFS=' ' words=( $COMP_LINE )
    typeset subcmds
    subcmds="${!_Dbg_command_help[@]}"
    if (( ${#words[@]} == 1 )); then
	COMPREPLY=( $subcmds )
    elif (( ${#words[@]} == 2 )) ; then
	typeset commands="${!_Dbg_command_help[@]}"
	COMPREPLY=( $(compgen -W  "$subcmds" "${words[1]}") )
    else
	COMPREPLY=()
    fi
}

# print help command
function _Dbg_do_help {

    # We have to use be careful to make sure globbing, e.g. * isn't
    # done.

    # Treat "help *" the same as help
    [[ "$_Dbg_args" == '*' ]] && _Dbg_args=''

    if [[ '' == $_Dbg_args ]] ; then
      _Dbg_help_sort_command_names
      _Dbg_section 'Available commands:'
      typeset -a list=("${_Dbg_sorted_command_names[@]}")
      _Dbg_list_columns
      _Dbg_msg ''
      _Dbg_msg 'Readline command line editing (emacs/vi mode) is available.'
      _Dbg_msg 'Type "help" followed by command name for full documentation.'
      return 0
    else
	typeset dbg_cmd="$1"
	if [[ -n ${_Dbg_command_help[$dbg_cmd]} ]] ; then
 	    _Dbg_msg_rst "${_Dbg_command_help[$dbg_cmd]}"
	else
	    _Dbg_alias_expand $dbg_cmd
	    dbg_cmd="$expanded_alias"
	    if [[ -n ${_Dbg_command_help[$dbg_cmd]} ]] ; then
 		_Dbg_msg_rst "${_Dbg_command_help[$dbg_cmd]}"
	    else
		case $dbg_cmd in
		    i | in | inf | info )
			_Dbg_info_help $2
			return
			;;
		    sh | sho | show )
			_Dbg_help_show $2
			;;
		    se | set )
			_Dbg_help_set $2
			;;
		    * )
			# Look for a unique abbreviation
			typeset -i count=0
			typeset found_cmd
			typeset list; list="${!_Dbg_command_help[@]}"
			for try in $list ; do
			    if [[ $try =~ ^$dbg_cmd ]] ; then
				found_cmd=$try
				((count++))
			    fi
			done
			((found=(count==1)))
			if ((found)); then
 			    _Dbg_msg "${_Dbg_command_help[$found_cmd]}"
			else
  			    _Dbg_errmsg "Undefined command: \"$dbg_cmd\".  Try \"help\"."
  			    return 1
			fi
			;;
		esac
	    fi
	fi
	aliases_found=''
	_Dbg_alias_find_aliased "$dbg_cmd"
	if [[ -n $aliases_found ]] ; then
	    _Dbg_msg ''
	    _Dbg_msg "Aliases for $dbg_cmd: $aliases_found"
	fi
	return 2
    fi
}

_Dbg_alias_add 'h' help
_Dbg_alias_add '?' help

# Demo it.
if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    for file in sort columnize list msg ; do
	source $top_dir/lib/${file}.sh;
    done
    # source /usr/local/share/bashdb/bashdb-trace
    # _Dbg_debugger
    _Dbg_do_help
    echo '---'
    _Dbg_args='help'
    _Dbg_do_help help
fi
