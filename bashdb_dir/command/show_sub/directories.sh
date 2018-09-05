# -*- shell-script -*-
# "show directories" debugger command
#
#   Copyright (C) 2010, 2011 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add_sub show directories \
'show directories

Show list of drectories used to search for not fully qualified file names.' 1
# FIXME add dir and then See also dir.

_Dbg_do_show_directories() {
    # Don't do anything if called as part of "show" (all)
    [[ -n $1 ]] && return  

    typeset list=${_Dbg_dir[0]}
    typeset -i n=${#_Dbg_dir[@]}
    typeset -i i
    for (( i=1 ; i < n; i++ )) ; do
	list="${list}:${_Dbg_dir[i]}"
    done
    
    _Dbg_msg "Source directories searched: $list"
    return 0
}
