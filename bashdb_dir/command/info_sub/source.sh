# -*- shell-script -*-
# "info source" debugger command
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

_Dbg_help_add_sub info source \
'**info source**

Information about the current source file.

See also:
---------

 \"info program\", \"info file\" and \"info line\".' 1

# list source and break condition.
# If $1 is given just list those associated for that line.
_Dbg_do_info_source() {
    _Dbg_msg "Current script file is $_Dbg_frame_last_filename"
    _Dbg_msg "Located in ${_Dbg_file2canonic[$_Dbg_frame_last_filename]}"
    typeset -i max_line
    max_line=$(_Dbg_get_maxline $_Dbg_frame_last_filename)
    _Dbg_msg "Contains $max_line lines."
    _Dbg_do_list_brkpt $*
    return 0
}
