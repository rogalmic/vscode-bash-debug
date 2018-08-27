#   Copyright (C) 2008-2011, 2016
#   Rocky Bernstein <rocky@gnu.org>
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

# bashdb-part2.sh - bashdb specific code that doesn't need preprocessor
# substitution. We put code here rather than bashdb.in for two reasons.
# First it helps separate code that undergoes m4 substitution and second
# it keeps line number the same more often in integration tests because
# this code changes more often making code bashdb.in code change less.
# It is the line numbers in that code that appear in tracebacks.
# FIXME: should implement "set hidelevel"?

# Pull in the rest of the debugger code.
. $_Dbg_main

# I don't know why when this is done in dbg-opts.sh it doesn't have
# an effect.
((OPTLIND > 0)) && shift "$((OPTLIND - 1))"

if (($# == 0)) && [[ -z $_Dbg_EXECUTION_STRING ]] ; then
    echo >&2 "${_Dbg_pname}: need to give a script to debug or use the -c option."
    exit 1
fi

_Dbg_script_file="$1"
shift

[[ $1 == '--' ]] && shift

if [[ ! -d $_Dbg_tmpdir ]] && [[ ! -w $_Dbg_tmpdir ]] ; then
  echo "${_Dbg_pname}: cannot write to temp directory $_Dbg_tmpdir." >&2
  echo "${_Dbg_pname}: Use -T try directory location." >&2
  exit 1
fi

# Note that this is called via bashdb rather than "bash --debugger"
_Dbg_script=1

if [[ -n $_Dbg_EXECUTION_STRING ]] ; then
    _Dbg_script_file=$(_Dbg_tempname cmd)
    echo "$_Dbg_EXECUTION_STRING" >$_Dbg_script_file
fi

if [[ ! -r "$_Dbg_script_file" ]] ; then
    echo "${_Dbg_pname}: cannot read program to debug: ${_Dbg_script_file}." >&2
    exit 1
fi

typeset -r _Dbg_Dbg_script_file=$(_Dbg_expand_filename $_Dbg_script_file)

if ((_Dbg_set_linetrace)) ; then
  # No stepping.
    _Dbg_write_journal_eval "_Dbg_step_ignore=-1"
    _Dbg_QUIT_ON_QUIT=1
else
  # Set to skip over statements up to ". $_Dbg_script_file"
    _Dbg_write_journal_eval "_Dbg_step_ignore=3"
fi

# The set0 can be loaded via commadn/set_sub/dollar0 or perhaps
# it as done prior to running bashdb. But if we have set0, use it
# to change $0 to the debugged script name rather than "@PACKAGE@".
if enable -a set0 2>/dev/null ; then
    set0 "$_Dbg_script_file"
fi

((_Dbg_set_read_completion)) && _Dbg_complete_level_0_init

_Dbg_init_default_traps
