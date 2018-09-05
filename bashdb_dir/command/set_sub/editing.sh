# -*- shell-script -*-
# "set editing" debugger command
#
#   Copyright (C) 2010-2011, 2016 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add_sub set editing \
'**set editing** [**on**|**off**|**emacs**|**vi**]

Readline editing of command lines

See also:
---------

**show editing**
'

_Dbg_next_complete[set editing]='_Dbg_complete_edit'

_Dbg_complete_edit() {
    COMPREPLY=(on off vi emacs)
}

_Dbg_do_set_editing() {
    typeset onoff=${1:-'on'}
    case $onoff in
	e | em | ema | emac | emacs )
	    _Dbg_edit='-e'
	    _Dbg_edit_style='emacs'
	    ;;
	on | 1 )
	    _Dbg_edit='-e'
	    _Dbg_edit_style='emacs'
	    ;;
	off | 0 )
	    _Dbg_edit=''
	    return 0
	    ;;
	v | vi )
	    _Dbg_edit='-e'
	    _Dbg_edit_style='vi'
	    ;;
	* )
	    _Dbg_errmsg '"on", "off", "vi", or "emacs" expected.'
	    return 1
    esac
    set -o $_Dbg_edit_style
    _Dbg_do_show_editing
    return 0
}
