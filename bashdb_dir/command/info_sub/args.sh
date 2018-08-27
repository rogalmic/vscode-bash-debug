# -*- shell-script -*-
# gdb-like "info args" debugger command
#
#   Copyright (C) 2010-2011, 2016 Rocky Bernstein <rocky@gnu.org>
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

# Print info args. Like GDB's "info args"
# $1 is an additional offset correction - this routine is called from two
# different places and one routine has one more additional call on top.
# This code assumes the's debugger version of
# bash where FUNCNAME is an array, not a variable.

if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    dirname=${BASH_SOURCE[0]%/*}
    [[ $dirname == $0 ]] && top_dir='../..' || top_dir=${dirname}/../..
    source ${top_dir}/lib/help.sh
fi

_Dbg_help_add_sub info args \
"**info args** [*frame-num*]

Show argument variables of the current stack frame.

The default value is 0, the most recent frame.

See also:
---------

**backtrace**." 1

_Dbg_do_info_args() {

    typeset -r frame_start=${1:-0}

    eval "$_seteglob"
    if [[ $frame_start != $int_pat ]] ; then
	_Dbg_errmsg "Bad integer parameter: $frame_start"
	eval "$_resteglob"
	return 1
    fi

    # source /usr/local/share/bashdb/bashdb-trace
    # _Dbg_debugger

    typeset -i i=$frame_start

    (( i >= _Dbg_stack_size )) && return 1

    # Figure out which index in BASH_ARGV is position "i" (the place where
    # we start our stack trace from). variable "r" will be that place.

    typeset -i adjusted_pos
    adjusted_pos=$(_Dbg_frame_adjusted_pos $frame_start)
    typeset -i arg_count=${BASH_ARGC[$adjusted_pos]}
    # echo "arg count is " $arg_count
    # echo "adjusted_pos is" $adjusted_pos
    # typeset -p BASH_ARGC

    # Print out parameter list.
    if (( 0 != ${#BASH_ARGC[@]} )) ; then
	typeset -i q
	typeset -i r=0
	for (( q=0 ; q<=adjusted_pos ; q++ )) ; do
	    (( r = r + ${BASH_ARGC[$q]} ))
	done
	((r--))
	# typeset -p r
	# typeset -p BASH_ARGV
	typeset -i s
	if ((arg_count == 0)) ; then
	    _Dbg_msg "Argument count is 0 for this call."
	else
	    for (( s=1; s <= arg_count ; s++ )) ; do
		_Dbg_printf "$%d = %s" $s "${BASH_ARGV[$r]}"
		((r--))
	    done
	fi
    fi
    return 0
}

# Demo it
if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    # FIXME: put some of this into a mock
    _Dbg_libdir=${top_dir}
    for _Dbg_file in pre vars ; do
	source ${top_dir}/init/${_Dbg_file}.sh
    done
    for _Dbg_file in frame msg file journal save-restore alias ; do
	source ${top_dir}/lib/${_Dbg_file}.sh
    done
    source ${top_dir}/command/help.sh
    _Dbg_set_debugger_entry
    _Dbg_frame_adjusted_pos() {
	typeset -i i=${1:-0}
	echo -n $i
    }
    # _Dbg_args='info'
    # _Dbg_do_help info args
    # _Dbg_do_info_args
fi
