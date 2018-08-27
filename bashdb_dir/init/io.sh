# -*- shell-script -*-
# io.sh - Bourne Again Shell Debugger Input/Output routines
#
#   Copyright (C) 2002, 2003, 2004, 2006, 2008, 2009, 2011 Rocky Bernstein 
#   <rocky@gnu.org>
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
#   You should have received a copy of the GNU General Public License along
#   with bashdb; see the file COPYING.  If not, write to the Free Software
#   Foundation, 59 Temple Place, Suite 330, Boston, MA 02111 USA.

# ==================== VARIABLES =======================================

# _Dbg_source_mungedfilename is an array which contains source_lines for
#  filename
# _Dbg_read_mungedfilename is array which contains the value '1' if the
#  filename has been read in.

typeset -a _Dbg_override_filenames # name translations given via the debugger
                                   # "file" command.

# ===================== FUNCTIONS =======================================

# _Dbg_progess_show --- print the progress bar
# $1: prefix string
# $2: max value
# $3: current value
function _Dbg_progess_show {
    typeset title=$1
    typeset -i max_value=$2
    typeset -i current_value=$3
    typeset -i max_length=40
    typeset -i current_length

    
    if (( max_value == 0 )) ; then
	# Avoid dividing by 0.
	current_length=${max_length}
    else
	current_length=$(( ${max_length} * ${current_value} / ${max_value} ))
    fi
    
    _Dbg_progess_show_internal "$1" ${max_length} ${current_length}
    _Dbg_printf_nocr ' %3d%%' "$(( 100 * ${current_value} / ${max_value} ))"
}
# _Dbg_progess_show_internal --- internal function for _Dbg_progess_show
# $1: prefix string
# $2: max length
# $3: current length
function _Dbg_progess_show_internal {
    typeset -i i=0

    # Erase line
    if [[ t == $EMACS ]]; then
	_Dbg_msg_nocr "\r\b\n"	
    else
	_Dbg_msg_nocr "\r\b"
    fi
    
    _Dbg_msg_nocr "$1: ["
    for (( i=0; i < $3 ; i++ )); do
	_Dbg_msg_nocr "="
    done
    _Dbg_msg_nocr '>'

    for (( i=0; i < $2 - $3 ; i++ )); do
	_Dbg_msg_nocr ' '
    done
    _Dbg_msg_nocr ']'
}

# clean up progress bar
function _Dbg_progess_done {
    # Erase line
    if test "x$EMACS" = xt; then
	_Dbg_msg_nocr "\r\b\n"	
    else
	_Dbg_msg_nocr "\r\b"
    fi
    _Dbg_msg $1
}
