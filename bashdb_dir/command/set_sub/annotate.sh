# -*- shell-script -*-
# "set annotate" debugger command
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

_Dbg_help_add_sub set annotate \
'**set annotate** {**0**|**1**}

Set annotation level.

  0 - normal
  1 - fullname (for use when running under emacs).

See also:
---------

**show annotate**
''Set annotation level [N]
' 1

_Dbg_do_set_annotate() {
    eval "$_seteglob"
    if (( $# != 1 )) ; then
	_Dbg_msg "A single argument is required (got $# arguments)."
    elif [[ $1 == $int_pat ]] ; then
	if (( $1 > 3 )) ; then
	    _Dbg_msg "Annotation level must be between 0 and 3. Got: ${1}."
	else
	    _Dbg_write_journal_eval "_Dbg_set_annotate=$1"
	fi
    else
	eval "$_resteglob"
	_Dbg_msg "Integer argument expected; got: $1"
	return 1
    fi
    eval "$_resteglob"
    return 0
}
