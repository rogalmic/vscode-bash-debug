# -*- shell-script -*-
# gdb-like "info program" debugger command
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

_Dbg_help_add_sub info program '
**info program**

Information about debugged program stopping point.

See also:
---------

\"info line\".' 1

_Dbg_do_info_program() {
    if (( _Dbg_running )) ; then
	_Dbg_msg "Program stopped."
	if [[ -n $_Dbg_stop_reason ]] ; then
	    _Dbg_msg "It stopped ${_Dbg_stop_reason}."
	fi
	if [[ -n $_Dbg_bash_command ]] ; then
	    _Dbg_msg "Next statement to be run is:\n\t${_Dbg_bash_command}"
	fi
    else
	_Dbg_errmsg "The program being debugged is not being run."
    fi
    return $?
}
