# -*- shell-script -*-
#   Copyright (C) 2008, 2010 Rocky Bernstein <rocky@gnu.org>
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

# Name we refer to ourselves by
typeset _Dbg_debugger_name='bashdb'

# The shell we are configured to run under.
typeset _Dbg_shell='/bin/bash'

# The release name we are configured to run under.
typeset _Dbg_release='4.4-0.94'

# Wrapper for debugger called from within bash via bash --debugger
typeset _Dbg_bashdb_main='/usr/share/bashdb/bashdb-main.inc'

# The short shell name. Helps keep code common in bash, zsh, and ksh debuggers.
typeset _Dbg_shell_name=${_Dbg_shell##*/}  # Equivalent to basename(_Dbg_shell)

# Original $0. Note we can't set this in an include.
typeset _Dbg_orig_0=$0

# Equivalent to basename $0; the short program name
typeset _Dbg_pname=${0##*/}

## Stuff set by autoconf/configure ###
typeset  prefix=/usr  # ${prefix}/share/bashdb often uses $prefix
typeset _Dbg_libdir=${prefix}/share/bashdb
###

# We agonize a bit over _Dbg_libdir: the root directory for where
# debugger code is stored.
[[ -d $_Dbg_libdir ]] || _Dbg_libdir=${_Dbg_bashdb_main%/*}  # dirname(_Dbg_bashdb_main)
[[ -d $_Dbg_libdir ]] || _Dbg_libdir='.'

typeset _Dbg_main="$_Dbg_libdir/dbg-main.sh"
if [[ ! -r $_Dbg_main ]] ; then
  echo "${_Dbg_pname}: Can't read debugger library file '${_Dbg_main}'."
  echo "${_Dbg_pname}: Perhaps bashdb is installed wrong (if its installed)." >&2
  echo "${_Dbg_pname}: Try running bashdb using -L (with a different directory)." >&2
  echo "${_Dbg_pname}: Run bashdb --help for a list and explanation of options." >&2
  exit 1
fi

# Pull in the rest of the debugger code.
. $_Dbg_main

trap '_Dbg_debug_trap_handler 0 "$BASH_COMMAND" "$@"' DEBUG
