# -*- shell-script -*-
# list.sh - Some listing commands
#
#   Copyright (C) 2002-2006, 2008-2011, 2016
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

_Dbg_help_add list \
'**list**[**>**] [*location*|**.**|**-**] [*count*]

List source code.

Without arguments, print lines centered around the current line. If
*location* is given, that number of lines is shown.

*location* can be a read-in function name or a filename and line
number separated by a colon, e.g /etc/profile:5

If *count* is omitted, use the value in the **set listize** setting as
a count. Use **set listsize** to change this setting. If *count* is
given and is less than the starting line, then it is treated as a
count. Otherwise it is treated as an ending line number.

more generally when the alias ends in ">", rather than center lines
around *location* that will be used as the starting point.

Examples:
---------

    list              # List from current program position or where we last left off
    list 5            # List starting from line 5
    list 5 2          # List two lines starting from line 5
    list .            # List lines centered from where we currently are stopped
    list -            # List lines previous to those just shown

See also:
---------

**set listsize** or **show listsize** to see or set the value;
**set autolist**.
'

# l [start|.] [cnt] List cnt lines from line start.
# l sub       List source code fn

_Dbg_do_list() {
    typeset -i center_line
    if [[ ${_Dbg_orig_cmd:${#_Dbg_orig_cmd}-1:1} == '>' ]] ; then
	center_line=0
    else
	center_line=1
    fi

    typeset first_arg
    if (( $# > 0 )) ; then
	first_arg="$1"
	shift
    else
	first_arg="$_Dbg_listline"
    fi

    if [[ $first_arg == '.' ]] || [[ $first_arg == '-' ]] ; then
	_Dbg_list $center_line "$_Dbg_frame_last_filename" $first_arg "$*"
	_Dbg_last_cmd="$_Dbg_cmd"
	return 0
    fi

    typeset filename
    typeset -i line_number
    typeset full_filename

    _Dbg_linespec_setup "$first_arg"

    if [[ -n $full_filename ]] ; then
	(( line_number ==  0 )) && line_number=1
	_Dbg_check_line $line_number "$full_filename"
	(( $? == 0 )) && \
	    _Dbg_list $center_line "$full_filename" "$line_number" $*
	_Dbg_last_cmd="$_Dbg_cmd"
	return 0
    else
	_Dbg_file_not_read_in "$filename"
	return 3
    fi
}

_Dbg_alias_add l list
_Dbg_alias_add "l>" list
_Dbg_alias_add "list>" list
