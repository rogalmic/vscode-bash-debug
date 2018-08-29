# -*- shell-script -*-
# pre.sh - Code common to bashdb and bashdb-trace that has to run first
#
#   Copyright (C) 2002-2004, 2008-2012
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

# We put definitions common to both the script debugger and
# dbg-trace.sh. In contrast to other routines, this code is sourced
# early -- before most of the debugger script is run.

# Note: initializations which are mostly used in only one sub-part
# (e.g. variables for break/watch/actions) are in the corresponding
# file: either in lib or (less good) command.

# This function is overwritten by when lib/fns.sh gets loaded
_Dbg_msg()
{
  echo >&2 "$@"
}

# This function is overwritten by when lib/fns.sh gets loaded
_Dbg_errmsg()
{
  echo >&2 "${_Dbg_pname}: $@"
}

# Used by "show version" as well as --version
_Dbg_do_show_version()
{
    [[ -n $1 ]] && label=$(_Dbg_printf_nocr "%-12s: " version)
    _Dbg_msg "${label}$_Dbg_debugger_name, release $_Dbg_release"
}

# Expand filename given as $1.
# we echo the expanded name or return $1 unchanged if a bad filename.
# Return is 0 if good or 1 if bad.
# File globbing is handled.
# Note we don't check that the file exists, just that the format is
# valid; we do check that we can "search" the directory implied in the
# filename.

function _Dbg_expand_filename {
  typeset -r filename="$1"

  # Break out basename and dirname
  typeset basename="${filename##*/}"
  typeset -x dirname="${filename%/*}"

  # No slash given in filename? Then use . for dirname
  [[ $dirname == $basename ]] && [[ $filename != '/' ]] && dirname='.'

  # Dirname is ''? Then use / for dirname
  dirname=${dirname:-/}

  # Handle tilde expansion in dirname
  dirname=$(echo $dirname)

  typeset long_path

  [[ $basename == '.' ]] && basename=''
  if long_path=$( (cd "$dirname" ; pwd) 2>/dev/null ) ; then
    if [[ "$long_path" == '/' ]] ; then
      echo "/$basename"
    else
      echo "$long_path/$basename"
    fi
    return 0
  else
    echo "$filename"
    return 1
  fi
}

# Create temporary file based on $1
# file $1
_Dbg_tempname() {
  echo "$_Dbg_tmpdir/${_Dbg_debugger_name}_$1_$$"
}

# Process command-line options
. "${_Dbg_libdir}/init/opts.sh"
OPTLIND=1
_Dbg_parse_options "$@"

if [[ ! -d "$_Dbg_tmpdir" ]] && [[ ! -w "$_Dbg_tmpdir" ]] ; then
  echo "${_Dbg_pname}: cannot write to temp directory $_Dbg_tmpdir." >&2
  echo "${_Dbg_pname}: Use -T try directory location." >&2
  exit 1
fi

# Save the initial working directory so we can reset it on a restart.
typeset -x _Dbg_init_cwd=$PWD

typeset -i _Dbg_running=1      # True we are not finished running the program

typeset -i _Dbg_brkpt_num=0    # If nonzero, the breakpoint number that we
                               # are currently stopped at.

# Sets whether or not to display command before executing it.
typeset _Dbg_set_trace_commands='off'

# Known normal IFS consisting of a space, tab and newline
typeset -x _Dbg_space_IFS=$' \t\r\n'

# Number of statements to run before entering the debugger.  Is used
# intially to get out of sourced dbg-main.inc script and in top-level
# debugger script to not stop in remaining debugger statements before
# the sourcing the script to be debugged.
typeset -i _Dbg_step_ignore=1
