# -*- shell-script -*-
# set dollar0 sets $0
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

# Load set0 if possible.
if [[ -f $_Dbg_libdir/builtin/set0 ]] ; then
    enable -f $_Dbg_libdir/builtin/set0 set0
fi

# If it was set0 loaded, then we can add a debugger command "set dollar0"
if enable -a set0 2>/dev/null ; then
    _Dbg_help_add_sub set dollar0 \
	'set dollar0 PROGRAM_NAME

Set $0 to PROGRAM_NAME.' 1
    
    _Dbg_do_set_dollar0() {
	# We use the loop below rather than _Dbg_set_args="(@)" because
	# we want to preserve embedded blanks in the arguments.
	if enable -a set0 2>/dev/null ; then
	    set0 "$1"
	else
	    _Dbg_errmsg "Can't do becasue set0 module is not loaded."
	fi
	return 0
    }
fi
