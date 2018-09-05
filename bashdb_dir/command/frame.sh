# -*- shell-script -*-
# gdb-like "frame" debugger command
#
#   Copyright (C) 2002-2006, 2008, 2010-2011, 2016
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

# Move default values down $1 or one in the stack.

_Dbg_help_add frame \
'**frame** [*frame-number*].

Change the current frame to frame *frame-numbrer* if specified, or the
most-recent frame, 0, if no frame number specified.

A negative number indicates the position from the other or
least-recently-entered end.  So **frame -1** moves to the oldest frame.

See also:
---------

**up**, **down**' 1 _Dbg_complete_frame

# Command completion for a debugger "frame" command.
_Dbg_complete_frame() {
    typeset -i start; ((start=-_Dbg_stack_size+1))
    typeset -i end;   ((end=_Dbg_stack_size-1))
    _Dbg_complete_num_range $start $end
}

_Dbg_do_frame() {
    _Dbg_not_running && return 3
    typeset count=${1:-1}
    _Dbg_is_signed_int $count
    if (( 0 == $? )) ; then
	_Dbg_frame_adjust $count 0
	typeset -i rc=$?
    else
	_Dbg_errmsg "Expecting an integer; got $count"
	typeset -i rc=2
    fi
    ((0 == rc)) && _Dbg_last_cmd='frame'
    return $rc
}
