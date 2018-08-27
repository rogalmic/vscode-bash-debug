# -*- shell-script -*-
#   Copyright (C) 2008-2011, 2015-2016 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_help_add break \
'**break** [*loc-spec*]

Set a breakpoint at *loc-spec*.

If no location specification is given, use the current line.

Multiple breakpoints at one place are permitted, and useful if conditional.

See also:
---------

"tbreak" and "continue"'

_Dbg_help_add tbreak \
'**tbreak* [*loc-spec*]

Set a one-time breakpoint at *loc-spec*.

Like "break" except the breakpoint is only temporary,
so it will be deleted when hit.  Equivalent to "break" followed
by using "delete" on the breakpoint number.

If no location specification is given, use the current line.'

_Dbg_do_tbreak() {
    _Dbg_do_break_common 1 $@
    return $?
}

_Dbg_do_break() {
    _Dbg_do_break_common 0 $@
    return $?
}

# Add breakpoint(s) at given line number of the current file.  $1 is
# the line number or _Dbg_frame_lineno if omitted.  $2 is a condition
# to test for whether to stop.
_Dbg_do_break_common() {

    typeset -i is_temp=$1
    shift

    typeset linespec
    if (( $# > 0 )) ; then
	linespec="$1"
    else
	linespec="$_Dbg_frame_last_lineno"
    fi
    shift

    typeset condition=${1:-''}
    if [[ "$linespec" == 'if' ]]; then
	linespec=$_Dbg_frame_last_lineno
    elif [[ -z $condition ]] ; then
	condition=1
    elif [[ $condition == 'if' ]] ; then
	shift
    fi
    if [[ -z $condition ]] ; then
	condition=1
    else
	condition="$*"
    fi

    typeset filename
    typeset -i line_number
    typeset full_filename

    _Dbg_linespec_setup "$linespec"

    if [[ -n "$full_filename" ]]  ; then
	if (( line_number ==  0 )) ; then
	    _Dbg_errmsg 'There is no line 0 to break at.'
	    return 1
	else
	    _Dbg_check_line $line_number "$full_filename"
	    (( $? == 0 )) && \
		_Dbg_set_brkpt "$full_filename" "$line_number" $is_temp "$condition"
	fi
    else
	_Dbg_file_not_read_in "$full_filename"
	return 2
    fi
    return 0
}

# delete brkpt(s) at given file:line numbers. If no file is given
# use the current file.
_Dbg_do_clear_brkpt() {
    typeset -r n=${1:-$_Dbg_frame_lineno}

    typeset filename
    typeset -i line_number
    typeset full_filename

    _Dbg_linespec_setup $n

    if [[ -n $full_filename ]] ; then
	if (( line_number ==  0 )) ; then
	    _Dbg_msg "There is no line 0 to clear."
	    return 0
	else
	    _Dbg_check_line $line_number "$full_filename"
	    if (( $? == 0 )) ; then
		_Dbg_unset_brkpt "$full_filename" "$line_number"
		typeset -r found=$?
		if [[ $found != 0 ]] ; then
		    _Dbg_msg "Removed $found breakpoint(s)."
		    return $found
		fi
	    fi
	fi
    else
	_Dbg_file_not_read_in "$full_filename"
	return 0
  fi
}

# list breakpoints and break condition.
# If $1 is given just list those associated for that line.
_Dbg_do_list_brkpt() {

    eval "$_seteglob"
    if (( $# != 0  )) ; then
	typeset brkpt_num="$1"
	if [[ $brkpt_num != $int_pat ]]; then
	    _Dbg_errmsg "Bad breakpoint number $brkpt_num."
	elif [[ -z ${_Dbg_brkpt_file[$brkpt_num]} ]] ; then
	    _Dbg_errmsg "Breakpoint entry $brkpt_num is not set."
	else
	    typeset -r -i i=$brkpt_num
	    typeset source_file=${_Dbg_brkpt_file[$i]}
	    source_file=$(_Dbg_adjust_filename "$source_file")
	    _Dbg_section "Num Type       Disp Enb What"
	    _Dbg_printf "%-3d breakpoint %-4s %-3s %s:%s" $i \
		${_Dbg_keep[${_Dbg_brkpt_onetime[$i]}]} \
		${_Dbg_yn[${_Dbg_brkpt_enable[$i]}]} \
		"$source_file" ${_Dbg_brkpt_line[$i]}
	    if [[ ${_Dbg_brkpt_cond[$i]} != '1' ]] ; then
		_Dbg_printf "\tstop only if %s" "${_Dbg_brkpt_cond[$i]}"
	    fi
	    _Dbg_print_brkpt_count ${_Dbg_brkpt_count[$i]}
	fi
	eval "$_resteglob"
	return 0
    elif (( ${#_Dbg_brkpt_line[@]} != 0 )); then
	typeset -i i

	_Dbg_section "Num Type       Disp Enb What"
	for (( i=1; i <= _Dbg_brkpt_max; i++ )) ; do
	    typeset source_file=${_Dbg_brkpt_file[$i]}
	    if [[ -n ${_Dbg_brkpt_line[$i]} ]] ; then
		source_file=$(_Dbg_adjust_filename "$source_file")
		_Dbg_printf "%-3d breakpoint %-4s %-3s %s:%s" $i \
		    ${_Dbg_keep[${_Dbg_brkpt_onetime[$i]}]} \
		    ${_Dbg_yn[${_Dbg_brkpt_enable[$i]}]} \
		    "$source_file" ${_Dbg_brkpt_line[$i]}
		if [[ ${_Dbg_brkpt_cond[$i]} != '1' ]] ; then
		    _Dbg_printf "\tstop only if %s" "${_Dbg_brkpt_cond[$i]}"
		fi
		if (( _Dbg_brkpt_counts[$i] != 0 )) ; then
		    _Dbg_print_brkpt_count ${_Dbg_brkpt_counts[$i]}
		fi
	    fi
	done
	return 0
    else
	_Dbg_msg 'No breakpoints have been set.'
	return 1
    fi
}

_Dbg_alias_add b break
