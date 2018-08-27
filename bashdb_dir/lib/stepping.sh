# -*- shell-script -*-
# stepping routines
#
#   Copyright (C) 2010 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_next_skip_common() {

    _Dbg_inside_skip=$1
    _Dbg_last_next_step_cmd="$_Dbg_cmd"
    _Dbg_last_next_step_args=$2
    _Dbg_not_running && return 3

    typeset count=${2:-1}
    
    if [[ $count == [0-9]* ]] ; then
	let _Dbg_step_ignore=${count:-1}
    else
	_Dbg_errmsg "Argument ($count) should be a number or nothing."
	_Dbg_step_ignore=1
	return 1
    fi
    # Do we step debug into functions called or not?
    if (( _Dbg_inside_skip == 0 )) ; then
	_Dbg_old_set_opts="$_Dbg_old_set_opts +o functrace"
    else
	_Dbg_old_set_opts="$_Dbg_old_set_opts -o functrace"
    fi
    _Dbg_write_journal_eval "_Dbg_old_set_opts='$_Dbg_old_set_opts'"

    _Dbg_write_journal "_Dbg_step_ignore=$_Dbg_step_ignore"
    # set -x
    _Dbg_continue_rc=$_Dbg_inside_skip
    return 0
}
