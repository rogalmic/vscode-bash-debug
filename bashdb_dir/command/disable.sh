# -*- shell-script -*-
# disable.sh - gdb-like "disable" debugger command
#
#   Copyright (C) 2002-2006, 2008, 2011, 2016
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

_Dbg_help_add disable \
'**disable** *bpnumber* [*bpnumber* ...]

Disables the breakpoints given as a space separated list of breakpoint numbers.

See also:
---------

**enable** and **info break**.
' 1 _Dbg_complete_brkpt_range

# Disable breakpoint(s)/watchpoint(s) by entry number(s).
_Dbg_do_disable() {
    if (($# == 0)) ; then
	_Dbg_errmsg 'Expecting breakpoint/watchpoint numbers. Got none.'
	return 1
    fi
    _Dbg_enable_disable 0 'disabled' $@
    return $?
}

if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    require ./help.sh ../lib/msg.sh ../lib/sort.sh ../lib/columnize.sh \
	    ../lib/list.sh
    _Dbg_args='enable'
    _Dbg_do_help enable
fi
