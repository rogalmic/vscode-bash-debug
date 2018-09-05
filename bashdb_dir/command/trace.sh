# -*- shell-script -*-
#
#   Copyright (C) 2008, 2010-2011, 2016 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add trace \
'**trace** *function*

trace alias *alias*

Set "xtrace" (set -x) tracing when *function is called.

See also "untrace" and "debug".'

# Wrap "set -x .. set +x" around a call to function $1.
# Normally we also save and restrore any trap DEBUG functions. However
# If $2 is 0 we will won't.
# The wrapped function becomes the new function and the original
# function is called old_$1.
# $? is 0 if successful.
function _Dbg_do_trace {
    if (($# == 0)) ; then
	_Dbg_errmsg "trace: missing function name."
	return 2
    fi
    typeset -r fn=$1
    typeset -ri clear_debug_trap=${2:-1}
    _Dbg_is_function "$fn" $_Dbg_set_debug || {
	_Dbg_errmsg "trace: function \"$fn\" is not a function."
	return 3
    }
    cmd=$(typeset -f -- "$fn") || {
	_Dbg_errmsg "Can't find function definition for definition \"$fn\"."
	return 4
    }
    if [[ $cmd =~ '^function ' ]] ; then
	cmd="function old_${cmd:9}"
    else
	cmd="old_${cmd}"
    fi
    ((_Dbg_set_debug)) && echo "$cmd"
    typeset save_clear_debug_trap_cmd=''
    typeset restore_trap_cmd=''
    if (( clear_debug_trap )) ; then
	save_clear_trap_cmd='local old_handler=$(trap -p DEBUG); trap - DEBUG'
	restore_trap_cmd='eval $old_handler'
    fi
    eval "$cmd" || {
	_Dbg_errmsg "Error in renaming function \"$fn\" to \"old_${fn}\"."
	return 5
    }
    cmd="${fn}() {
    $save_clear_trap_cmd
    typeset -ri old_set_x=is_traced
    set -x
    old_$fn \"\$@\"
    typeset -ri rc=\$?
    (( old_set_x == 0 )) && set +x # still messes up of fn did: set -x
    $restore_trap_cmd
    return \$rc
    }
"
    ((_Dbg_set_debug)) && echo "$cmd"
    eval "$cmd" || return 6
    _Dbg_msg "\"$fn\" renamed \"old_${fn}\" and traced by \"${fn}\"."
    return 0
}
