# -*- shell-script -*-
# "set tty" debugger command
#
#   Copyright (C) 2012 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add_sub set tty \
'set tty {pseudo-device|&1}

Set the output device for debugger output. Use "\&1" if you want debugger
output to go to STDOUT.
' 1

# Set output tty
_Dbg_do_set_tty() {
    _Dbg_do_tty $@
    return $?
}

_Dbg_do_set_help_tty() {
    typeset label

    [[ -n $1 ]] && label=$(builtin printf '%-16s-- ' 'set tty') || label=''
    _Dbg_msg_nocr \
        "${label}Debugger output goes to "
    if [[ -n $_Dbg_tty ]] ; then
        _Dbg_msg $(tty)
    else
        _Dbg_msg $_Dbg_tty
    fi
    return 0
}
