# -*- shell-script -*-
# "set basename" debugger command
#
#   Copyright (C) 2011, 2016 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add_sub set basename \
'**set basename** [**on**|**off**]


Set short filenames (the basename) in debug output

See also:
---------

**show basename**
'

_Dbg_next_complete[set basename]='_Dbg_complete_onoff'

_Dbg_do_set_basename() {
    _Dbg_set_onoff "$1" 'basename'
    return $?
}
