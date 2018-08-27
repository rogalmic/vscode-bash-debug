# -*- shell-script -*-
# gdb-like "backtrace" debugger command
#
#   Copyright (C) 2002, 2003, 2004, 2005, 2006, 2008, 2010, 2011
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

# Print a stack backtrace.
# $1 is an additional offset correction - this routine is called from two
# different places and one routine has one more additional call on top.
# $2 is the maximum number of entries to include.
# $3 is which entry we start from; the "up", "down" and the "frame"
# commands may shift this.

# This code assumes the version of bash where FUNCNAME is an array,
# not a variable.

_Dbg_help_add backtrace \
"**backtrace** [*n*]

Print a backtrace of calling functions and sourced files.

files. If *n* is given, list only *n* calls.

Examples:
---------

   backtrace    # Print a full stack trace
   backtrace 2  # Print only the top two entries
" 1 _Dbg_complete_backtrace

# Command completion for a frame command
_Dbg_complete_backtrace() {
    typeset -i start=0
    typeset -i end;   ((end=_Dbg_stack_size-1))
    _Dbg_complete_num_range $start $end
}

# FIXME: $1 is a hidden parameter not shown in help. $2 is COUNT.
# $3 is FRAME-INDEX.
function _Dbg_do_backtrace {

    _Dbg_not_running && return 3

    typeset -i count=${1:-$_Dbg_stack_size}
    $(_Dbg_is_int $count) || {
	_Dbg_errmsg "Bad integer COUNT parameter: $count"
	return 1
    }

    typeset -i frame_start=${2:-0}

    $(_Dbg_is_int $frame_start) || {
	_Dbg_errmsg "Bad integer parameter: $ignore_count"
	return 1
    }

    # i is the logical frame value - 0 most recent frame.
    typeset -i i=frame_start
    typeset -li adjusted_pos

    ## DEBUG
    ## typeset -p pos
    ## typeset -p BASH_LINENO
    ## typeset -p BASH_SOURCE
    ## typeset -p FUNCNAME

    typeset    filename
    typeset -i adjusted_pos
    # Position 0 is special in that get the line number not from the
    # stack but ultimately from LINENO which was saved in the hook call.
    if (( frame_start == 0 )) ; then
	((count--)) ;
	adjusted_pos=$(_Dbg_frame_adjusted_pos 0)
	filename=$(_Dbg_file_canonic "${BASH_SOURCE[$adjusted_pos]}")
	_Dbg_frame_print $(_Dbg_frame_prefix 0) '0' '' "$filename" "$_Dbg_frame_last_lineno" ''
    fi

    typeset -i skip_fns
    ((skip_fns=${#FUNCNAME[@]} - _Dbg_stack_size + 1))
    _Dbg_frame_set_fn_param $skip_fns

    # Loop which dumps out stack trace.
    ## DEBUG
    ## typeset -p BASH_ARGC
    ## typeset -p BASH_ARGV
    ## typeset -p FUNCNAME
    ## typeset -p _Dbg_next_argc
    ## typeset -p _Dbg_next_argv
    ## echo "Adjusted pos $(_Dbg_frame_adjusted_pos 0)"

    for ((  i=frame_start+1 ;
	    i <= _Dbg_stack_size && count > 0 ;
	    i++ )) ; do
	typeset -i arg_count=${BASH_ARGC[$_Dbg_next_argc]}
	adjusted_pos=$(_Dbg_frame_adjusted_pos $i)
	_Dbg_msg_nocr $(_Dbg_frame_prefix $i)$i ${FUNCNAME[$adjusted_pos-1]}

	typeset parms=''

	# Print out parameter list.
	if (( 0 != ${#BASH_ARGC[@]} )) ; then
	    _Dbg_frame_fn_param_str
	    if [[ ${FUNCNAME[$adjusted_pos-1]} == "source" ]] ; then
		_Dbg_parm_str=\"$(_Dbg_file_canonic "${BASH_ARGV[$_Dbg_next_argv-1]}")\"
	    fi
	fi

	typeset -l lineno
	if (( adjusted_pos == ${#BASH_SOURCE[@]} )) ; then
	    lineno=0
	    ((adjusted_pos--))
	else
	    lineno=${BASH_LINENO[$adjusted_pos-1]}
	fi
	filename=$(_Dbg_file_canonic "${BASH_SOURCE[$adjusted_pos]}")
	_Dbg_msg "($_Dbg_parm_str) called from file \`$filename'" "at line $lineno"

	((count--))
    done
    return 0
}

_Dbg_alias_add bt backtrace
_Dbg_alias_add T backtrace
_Dbg_alias_add where backtrace
