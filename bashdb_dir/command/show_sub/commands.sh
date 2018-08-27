# -*- shell-script -*-
# "show commands" debugger command
#
#   Copyright (C) 2011 Rocky Bernstein <rocky@gnu.org>
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

if [[ $0 == ${BASH_SOURCE[0]} ]] ; then 
    source ${BASH_SOURCE[0]%/*}/../../lib/help.sh
fi

_Dbg_help_add_sub show commands \
'show commands [+NUM]

Show the history of commands you typed.
You can supply a command number to start with, or a "+" to start after
the previous command number shown.' 1

_Dbg_show_nolist[commands]=1

_Dbg_do_show_commands() {
    typeset -i default_hi_start=_Dbg_hi-1
    if ((default_hi_start < 0)) ; then default_hi_start=0 ; fi
    typeset hi_start=${2:-$default_hi_start}
    
    eval "$_seteglob"
    case $hi_start in
	"+" )
	    ((hi_start=_Dbg_hi_last_stop-1))
	    ;;
	$int_pat | -$int_pat)
            :
            ;;
	* )
	_Dbg_msg "Invalid parameter $hi_start. Need an integer or '+'"
    esac
    eval "$_resteglob"
    
    typeset -i hi_stop=hi_start-10
    _Dbg_do_history_list $hi_start $hi_stop
    _Dbg_hi_last_stop=$hi_stop
    }
