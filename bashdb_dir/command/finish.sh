# -*- shell-script -*-
# finsh.sh - Debugger "finish" (step out) commmand.
#
#   Copyright (C) 2010 Rocky Bernstein rocky@gnu.org
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

_Dbg_help_add finish \
"finish 

Continue execution until leaving the current function. 
Sometimes this is called 'step out'."

_Dbg_do_finish() {
    _Dbg_not_running && return 3

    (( _Dbg_return_level=${#FUNCNAME[@]}-5 ))
    _Dbg_last_cmd='finish'
    _Dbg_inside_skip=0
    _Dbg_continue_rc=0
    return 0
}

_Dbg_alias_add fin finish
