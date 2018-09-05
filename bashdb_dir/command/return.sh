# -*- shell-script -*-
# gdb-like "return" (return from fn immediately) debugger command
#
#   Copyright (C) 2010, 2016 Rocky Bernstein
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

# Move default values up $1 or one in the stack.
_Dbg_help_add return \
'**return**

Force an immediate return from a function.

The remainder of function will not be executed.

See also:
---------

**finish**, **quit**, and **run**.'

function _Dbg_do_return {
    _Dbg_step_ignore=1
    _Dbg_write_journal "_Dbg_step_ignore=$_Dbg_step_ignore"
    IFS="$_Dbg_old_IFS";
    _Dbg_last_cmd='return'
    _Dbg_inside_skip=0
    _Dbg_continue_rc=2
    return 0
}
