# -*- shell-script -*-
# gdb-like "down" debugger command
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

if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    dirname=${BASH_SOURCE[0]%/*}
    [[ $dirname == $0 ]] && top_dir='..' || top_dir=${dirname}/..
    for lib_file in help alias ; do source $top_dir/lib/${lib_file}.sh; done
fi

# Move default values down $1 or one in the stack.
_Dbg_help_add down \
'**down** [*count*]

Move the current frame down in the stack trace (to an newer frame). 0 is
the most recent frame.

If *count* is omitted, use 1.

See also:
---------

**down** and **frame**.' 1 _Dbg_complete_down

# Command completion for a frame command
_Dbg_complete_down() {
    typeset -i start; ((start=-_Dbg_stack_size+2+_Dbg_stack_pos))
    typeset -i end;   ((end=_Dbg_stack_size-3-_Dbg_stack_pos))
    _Dbg_complete_num_range $start $end
}

function _Dbg_do_down {
    _Dbg_not_running && return 3
    typeset count=${1:-1}
    _Dbg_is_signed_int $count
    if (( 0 == $? )) ; then
        _Dbg_frame_adjust $count -1
        typeset -i rc=$?
    else
        _Dbg_errmsg "Expecting an integer; got $count"
        typeset -i rc=2
    fi
    ((0 == rc)) && _Dbg_last_cmd='down'
    return $rc
}

# Demo it
if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    for _Dbg_file in  help msg sort columnize ; do
        source ${top_dir}/lib/${_Dbg_file}.sh
    done
    source ${top_dir}/command/help.sh
    _Dbg_args='down'
    _Dbg_do_help down
fi
