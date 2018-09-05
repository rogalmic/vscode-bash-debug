# -*- shell-script -*-
# log.sh - Debugger set/show logging
#
#   Copyright (C) 2006, 2010, 2011 Rocky Bernstein <rocky@gnu.org>
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

# 1 if we are logging output. 
typeset -i _Dbg_logging=0

# Location of logging file *when* we are set logging is on.
typeset _Dbg_logging_file="bashdb.txt"

# If 1 overwrite existing logging file? 
typeset _Dbg_logging_overwrite=0

# If 1, log file is sufficient, don't also print to stdout. 
typeset _Dbg_logging_redirect=0

_Dbg_do_set_logging()
{
    typeset -a args=($@)
    if (( ${#args[@]} > 0 )) ; then
	case ${args[0]} in 
	    off )
		if (( _Dbg_logging != 0 )) ; then
		    # Lose logfile
		    _Dbg_logging=0
		fi
		;;
	    on )
		if (( _Dbg_logging == 0 )) ; then
		    _Dbg_logging=1
		    if (( _Dbg_logging_overwrite )) ; then
			cat /dev/null >$_Dbg_logging_file
		    fi
		fi
		;;
	    overwrite )
		local onoff=${2:-'on'}
		case $onoff in 
		    on | 1 ) 
			_Dbg_write_journal_eval "_Dbg_logging_overwrite=1"
			;;
		    off | 0 )
			_Dbg_write_journal_eval "_Dbg_logging_overwrite=0"
			;;
		    * )
			_Dbg_msg "\"on\" or \"off\" expected."
		esac
		;;
	    redirect )
		local onoff=${2:-'on'}
		case $onoff in 
		    on | 1 ) 
			_Dbg_write_journal_eval "_Dbg_logging_redirect=1"
			;;
		    off | 0 )
			_Dbg_write_journal_eval "_Dbg_logging_redirect=0"
			;;
		    * )
			_Dbg_msg "\"on\" or \"off\" expected."
		esac
		;;
	    file )
		if (( ${#args[@]} == 2 )) ; then
		    _Dbg_write_journal_eval "_Dbg_logging_file=${args[1]}"
		else 
		    _Dbg_msg "Expecting a single file argument in 'set logging file'."
		fi
		;;
	    * )
		_Dbg_msg "Usage: set logging on"
		_Dbg_msg "set logging off"
		_Dbg_msg "set logging file FILENAME"
		_Dbg_msg "set logging overwrite [on|off]"
		_Dbg_msg "set logging redirect [on|off]"
		;;
	esac
    fi
    return 0
}

_Dbg_do_show_logging()
{
    typeset -a args=($*)
    if (( ${#args[@]} == 0 )) ; then
	_Dbg_msg "Future logs will be written to $_Dbg_logging_file"
	if (( _Dbg_logging_overwrite )) ; then
	    _Dbg_msg 'Logs will overwrite the log file.'
	else
	    _Dbg_msg 'Logs will be appended to the log file.'
	    if (( _Dbg_logging_redirect )) ; then
		_Dbg_msg "Output will be sent only to the log file."
	    else
		_Dbg_msg "Output will be logged and displayed."
	    fi
	fi
    else
	case ${args[0]} in 
	    overwrite )
		local onoff="off."
		(( _Dbg_logging_overwrite != 0 )) && onoff='on.'
		_Dbg_msg \
		    "Whether logging overwrites or appends to the log file is ${onoff}"
		;;
	    redirect )
		local onoff="off."
		(( _Dbg_logging_redirect != 0 )) && onoff='on.'
		_Dbg_msg "The logging output mode is ${onoff}."
		;;
	    file )
	_Dbg_msg "The current logfile is ${_Dbg_logging_file}"
	;;
	    * )
		_Dbg_undefined_cmd "show logging" "${args[0]}"
		;;
	esac
    fi
}
