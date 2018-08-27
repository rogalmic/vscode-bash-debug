# -*- shell-script -*-
# "info functions" debugger command
#
#   Copyright (C) 2010, 2011 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add_sub info functions \
'**info functions** [*pattern*]

Show functions matching regular expression PATTERN.
If pattern is empty, list all functions.

Examples:
---------

  info functions       \# list of all functions
  info functions s     \# functions containing an \"s\"
  info function  \^s    \# functions starting with an \"s\"

See also:
---------

**info variables**.' 1

# list functions and break condition.
# If $1 is given just list those associated for that line.
_Dbg_do_info_functions() {
    typeset pat=$1

    typeset -a fns_a
    fns_a=($(_Dbg_get_functions 0 "$pat"))
    typeset -i i
    for (( i=0; i < ${#fns_a[@]}; i++ )) ; do
	_Dbg_msg ${fns_a[$i]}
    done
    return 0
}
