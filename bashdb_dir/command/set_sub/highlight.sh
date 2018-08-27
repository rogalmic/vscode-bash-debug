# -*- shell-script -*-
# "set highlight" debugger command
#
#   Copyright (C) 2011, 2014-2016 Rocky Bernstein <rocky@gnu.org>
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

# If run standalone, pull in other files we need
if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    dirname=${BASH_SOURCE[0]%/*}
    [[ $dirname == $0 ]] && top_dir='../..' || top_dir=${dirname}/../..
    [[ -z $_Dbg_libdir ]] && _Dbg_libdir=$top_dir
    for file in help alias ; do source $top_dir/lib/${file}.sh; done
fi

_Dbg_help_add_sub set highlight \
'**set** **highlight** [**dark**|**light**|**off**|**reset**]

Set using terminal highlight.

Use **reset** to set highlighting on and force a redo of syntax
highlighting of already cached files. This may be needed if the
debugger was started without syntax highlighting initially.

**dark** sets sets for highlighting for a terminal with a dark background and
**light** set for highlighting for a terminal with a light background.

See also:
---------

**show highlight**.
'

_Dbg_next_complete[set highlight]='_Dbg_complete_highlight'

_Dbg_complete_highlight() {
    COMPREPLY=(dark light off reset)
}

_Dbg_do_set_highlight() {
    if (( ! _Dbg_working_term_highlight )) ; then
	_Dbg_errmsg "Can't run term-highlight. Setting forced off"
	return 1
    fi
    typeset onoff=${1:-'light'}
    case $onoff in
	on | light )
	    _Dbg_set_highlight='light'
	    _Dbg_filecache_reset
	    _Dbg_readin $_Dbg_frame_last_filename
	    ;;
	dark )
	    _Dbg_set_highlight='dark'
	    _Dbg_filecache_reset
	    _Dbg_readin $_Dbg_frame_last_filename
	    ;;
	off | 0 )
	    _Dbg_set_highlight=''
	    _Dbg_filecache_reset
	    _Dbg_readin $_Dbg_frame_last_filename
	    ;;
	reset )
	    [[ -z $_Dbg_set_highlight ]] && _Dbg_set_highlight='light'
	    _Dbg_filecache_reset
	    _Dbg_readin $_Dbg_frame_last_filename
	    ;;
	* )
	    _Dbg_errmsg '"dark", "light", "off", or "reset" expected.'
	    return 1
    esac
    _Dbg_do_show highlight
    return 0
}
