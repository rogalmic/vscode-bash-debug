# -*- shell-script -*-
# "set linetrace" debugger command
#
#   Copyright (C) 2010, 2016 Rocky Bernstein rocky@gnu.org
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

_Dbg_help_add_sub set linetrace \
'set linetrace [on|off]

Set shell-like \"set -x\" line tracing' 1

typeset -i _Dbg_linetrace_expand=0 # expand variables in linetrace output
typeset -i _Dbg_linetrace_delay=0  # sleep after linetrace

_Dbg_help_add_sub set linetrace \
'**set linetrace** [**on**|**off**]

Set xtrace-style line tracing

See also:
---------

**show linetrace**
'

_Dbg_do_set_linetrace() {
    typeset onoff=${1:-'off'}
    case $onoff in
	on | 1 )
	    _Dbg_write_journal_eval "_Dbg_set_linetrace=1"
	    ;;
	off | 0 )
	    _Dbg_write_journal_eval "_Dbg_set_linetrace=0"
	    ;;
	d | de | del | dela | delay )
	    eval "$_seteglob"
	    if [[ $2 != $int_pat ]] ; then
		_Dbg_msg "Bad int parameter: $2"
		eval "$_resteglob"
		return 1
	    fi
	    eval "$_resteglob"
	    _Dbg_write_journal_eval "_Dbg_linetrace_delay=$2"
	    ;;
	e | ex | exp | expa | expan | expand )
	    typeset onoff=${2:-'on'}
	    case $onoff in
		on | 1 )
		    _Dbg_write_journal_eval "_Dbg_linetrace_expand=1"
		    ;;
		off | 0 )
		    _Dbg_write_journal_eval "_Dbg_linetrace_expand=0"
		    ;;
		* )
		    _Dbg_errmsg "\"expand\", \"on\" or \"off\" expected."
		    ;;
	    esac
	    ;;

	* )
	    _Dbg_errmsg "\"expand\", \"on\" or \"off\" expected."
	    return 1
    esac
    return 0
}
