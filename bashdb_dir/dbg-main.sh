# -*- shell-script -*-
# dbg-main.sh - debugger main include

#   Copyright (C) 2002, 2003, 2004, 2005, 2006, 2008, 2009, 2010,
#   2011 Rocky Bernstein <rocky@gnu.org>
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

# Are we using a debugger-enabled bash? If not let's stop right here.
if [[ -z "${BASH_SOURCE[0]}" ]] ; then 
    echo "Sorry, you need to use a debugger-enabled version of bash." 2>&1
    exit 2
fi

# Code that specifically has to come first.
# Note: "init" comes first and "cmds" has to come after "io".
for _Dbg_file in require pre vars io ; do 
    source ${_Dbg_libdir}/init/${_Dbg_file}.sh
done

for _Dbg_file in ${_Dbg_libdir}/lib/*.sh ${_Dbg_libdir}/command/*.sh ; do 
    source $_Dbg_file
done

if [[ -r /dev/stdin ]] ; then
    _Dbg_do_source /dev/stdin
elif [[ $(tty) != 'not a tty' ]] ; then
    _Dbg_do_source $(tty)
fi

# List of command files to process
typeset -a _Dbg_input

# Have we already specified where to read debugger input from?  
#
# Note: index 0 is only set by the debugger. It is not used otherwise for
# I/O like those indices >= _Dbg_INPUT_START_DESC are.
if [[ -n "$DBG_INPUT" ]] ; then 
    _Dbg_input=("$DBG_INPUT")
    _Dbg_do_source "${_Dbg_input[0]}"
    _Dbg_no_nx=1
fi

typeset _Dbg_startup_cmdfile=${HOME:-~}/.${_Dbg_debugger_name}rc
if (( 0 == _Dbg_o_nx)) && [[ -r "$_Dbg_startup_cmdfile" ]] ; then
    _Dbg_do_source "$_Dbg_startup_cmdfile"
fi

# _Dbg_DEBUGGER_LEVEL is the number of times we are nested inside a debugger
# by virtue of running "debug" for example.
if [[ -z "${_Dbg_DEBUGGER_LEVEL}" ]] ; then
    typeset -xi _Dbg_DEBUGGER_LEVEL=1
fi

# This is put at the so we have something at the end to stop at 
# when we debug this. By stopping at the end all of the above functions
# and variables can be tested.

if [[ ${_Dbg_libdir:0:1} == '.' ]] ; then
    # Relative file name
    _Dbg_libdir=$(_Dbg_expand_filename ${_Dbg_init_cwd}/${_Dbg_libdir})
fi

for source_file in ${_Dbg_o_init_files[@]} "$DBG_RESTART_FILE";  do
    if [[ -n "$source_file" ]] ; then
	if [[ -r "$source_file" ]] && [[ -f "$source_file" ]] ; then
	    source $source_file
	else
	    _Dbg_errmsg "Unable to read shell script: ${source_file}"
	fi
    fi
done
