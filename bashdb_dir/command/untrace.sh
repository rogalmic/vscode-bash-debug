# -*- shell-script -*-
#
#   Copyright (C) 2008, 2010, 2011 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add untrace \
'untrace FUNCTION

Untrace previously-traced function FUNCTION. See also "trace".'

# Undo wrapping fn
# $? is 0 if successful.
function _Dbg_do_untrace {
    typeset fn=$1
    if [[ -z $fn ]] ; then
	_Dbg_errmsg "untrace: missing or invalid function name."
	return 2
    fi
    _Dbg_is_function "$fn" $_Dbg_set_debug || {
	_Dbg_errmsg "untrace: function \"$fn\" is not a function."
	return 3
    }
    _Dbg_is_function "old_$fn" || {
	_Dbg_errmsg "untrace: old function old_$fn not seen - nothing done."
	return 4
    }
    if cmd=$(declare -f -- "old_$fn") ; then 
	if [[ $cmd =~ '^function old_' ]] ; then
	    cmd="function ${cmd:13}"
	else
	    cmd=${cmd#old_}
	fi
	((_Dbg_debug_debugger)) && echo $cmd 
	eval "$cmd" || return 6
	_Dbg_msg "\"$fn\" restored from \"old_${fn}\"."
	return 0
    else
	_Dbg_errmsg "Can't find function definition for \"$fn\"."
	return 5
    fi
}
