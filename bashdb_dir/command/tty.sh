# -*- shell-script -*-
# tty command.
#
#   Copyright (C) 2002, 2003, 2004, 2006, 2008, 2012 Rocky Bernstein 
#   rocky@gnu.org
#
#   bashdb is free software; you can redistribute it and/or modify it under
#   the terms of the GNU General Public License as published by the Free
#   Software Foundation; either version 2, or (at your option) any later
#   version.
#
#   bashdb is distributed in the hope that it will be useful, but WITHOUT ANY
#   WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#   for more details.
#   
#   You should have received a copy of the GNU General Public License along
#   with bashdb; see the file COPYING.  If not, write to the Free Software
#   Foundation, 59 Temple Place, Suite 330, Boston, MA 02111 USA.

_Dbg_help_add tty \
'tty

Set the output device for debugger output. Use "&1" if you want debugger
output to go to STDOUT.
'

# Set output tty
_Dbg_do_tty() {
    typeset -i rc=0
    if (( $# < 1 )) ; then
        _Dbg_errmsg "Argument required (terminal name for running target process)."
        return 1
    fi
    typeset tty=$1
    if _Dbg_check_tty $tty ; then 
        _Dbg_tty=$tty
        _Dbg_prompt_output=$_Dbg_tty
        _Dbg_msg "Debugger output set to go to $_Dbg_tty"
    fi
    return 0
}
