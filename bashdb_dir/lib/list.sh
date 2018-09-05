# -*- shell-script -*-
# debugger source-code listing routines
#
#   Copyright (C) 2002-2004, 2006, 2008-2011, 2014
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

# List search commands/routines

# Last search pattern used.
typeset _Dbg_last_search_pat

# The current line to be listed. A 0 value indicates we should set
# from _Dbg_frame_last_lineno
typeset -i _Dbg_listline=0

typeset _Dbg_source_line

# Print source line in standard format for line $1 of filename $2.  If
# $2 is omitted, use _Dbg_frame_last_filename, if $1 is omitted use
# _Dbg_frame_last_lineno.
function _Dbg_print_location_and_command {
  typeset line_number=${1:-$_Dbg_frame_last_lineno}
  typeset filename=${2:-$_Dbg_frame_last_filename}
  _Dbg_get_source_line $line_number "$filename"
  filename=$(_Dbg_adjust_filename "$filename")
  _Dbg_msg "(${filename}:${line_number}):
${line_number}:\t${_Dbg_source_line}"

  # If we are at the same place in the file but the command has changed,
  # then we have multiple commands on the line. So print which one we are
  # currently at.
  if [[ $_Dbg_set_show_command == "on" ]] ; then
      _Dbg_msg "$_Dbg_bash_command"
  elif [[ $_Dbg_last_lineno == $_Dbg_frame_last_lineno ]] \
    && [[ $_Dbg_last_source_file == $_Dbg_frame_last_filename ]] \
    && [[ $_Dbg_last_bash_command != $_Dbg_bash_command \
    && $_Dbg_set_show_command == "auto" ]] ; then
      _Dbg_msg "$_Dbg_bash_command"
  fi
}

# Print Linetrace output. We also handle output if linetrace expand
# is in effect.
_Dbg_print_linetrace() {
  typeset line_number=${1:-$_Dbg_frame_last_lineno}
  typeset filename=${2:-"$_Dbg_frame_last_filename"}

  # Remove main + sig-handler  + print_lintrace FUNCNAMES.
  typeset -i depth=${#FUNCNAME[@]}-3

  # If called from bashdb script rather than via "bash --debugger",
  # we are artificially nested one deeper because of the bashdb call.
  if [[ -n $_Dbg_script ]] ; then
    ((depth--))
  fi

  (( depth < 0 )) && return

  _Dbg_get_source_line $line_number "$filename"
  filename=$(_Dbg_adjust_filename "$filename")
  _Dbg_msg "(${filename}:${line_number}):
level $_Dbg_DEBUGGER_LEVEL, subshell $BASH_SUBSHELL, depth $depth:\t${_Dbg_source_line}"
#   if (( _Dbg_linetrace_expand )) ; then
# #    typeset expanded_source_line
# #    # Replace all double quotes (") with and an escape (\")
# #    typeset esc_source_line="${_Dbg_source_line//\"/\\\"}"
#       _Dbg_do_eval "expanded_source_line=\"$esc_source_line\"" 2>/dev/null
#      _Dbg_do_eval "expanded_source_line=\"$_Dbg_bash_command\"" 2>/dev/null
#      _Dbg_msg "+ ${expanded_source_line}"
#   fi

  # If we are at the same place in the file but the command has changed,
  # then we have multiple commands on the line. So print which one we are
  # currently at.
  if [[ $_Dbg_set_show_command == "on" ]] ; then
      _Dbg_msg "$_Dbg_bash_command"
  elif (( _Dbg_last_lineno == _Dbg_frame_last_lineno )) \
    && [[ $_Dbg_last_source_file == $_Dbg_frame_last_filename ]] \
    && [[ $_Dbg_last_bash_command != $_Dbg_bash_command \
    && $_Dbg_set_show_command == "auto" ]] ; then
      _Dbg_msg "$_Dbg_bash_command"
  fi
}

# Parse $1 $2, $3, and optional $4 setting $filename, $_Dbg_start_line and
# $end_line.  $2 is the maximimum number of lines. If $3 or $4 are
# less than 0, they are interpreted as line numbers counting from the
# end. If $3 is '.' use _Dbg_frame_last_lineno. If $4 is given and is
# greater than $3 then use that as an ending line. If $4 is less than
# $3, then it is a line count. And if $4 omitted, use the line count
# $_Dbg_set_listsize.  if $2 is omitted, use global variable
# $_Dbg_frame_last_lineno.
_Dbg_parse_list_args() {
    typeset -i max_line
    (($# < 3 || $# > 5)) && return 1

    typeset -i center_line
    center_line=$2

    max_line=$2
    filename="$3"

    # Parse start line $3 yielding _Dbg_listline
    if [[ $4 == '.' ]]; then
	((_Dbg_listline=_Dbg_frame_last_lineno))
    elif [[ $4 == '-' ]]; then
	((_Dbg_listline=_Dbg_listline-2*_Dbg_set_listsize))
    elif [[ -n $4 ]] ; then
	if (($4 < 0)) ; then
	    ((_Dbg_listline=$2+$4+1))
	else
	    ((_Dbg_listline=$4))
	fi
    elif (( 0 == _Dbg_listline )) ; then
	_Dbg_listline=$_Dbg_frame_last_lineno
    fi
    (( _Dbg_listline==0 && _Dbg_listline++ ))

    typeset -i count
    ((count=${5:-_Dbg_set_listsize}))
    ((count < 0)) && ((count=$2+$5+1))
    if [[ -z $5 ]] || ((count < _Dbg_listline)) ; then
	((center_line)) && ((_Dbg_listline-=count/2))
	((_Dbg_listline<=0)) && ((_Dbg_listline=1))
	((end_line=_Dbg_listline+count-1))
    else
	((end_line=count))
    fi
    return 0
}

# list lines starting. See _Dbg_parse_list_args for how $2, $3, and $4
# are interpreted. Note though that they are called as $1, $2, $3 there.
_Dbg_list() {
    (($# < 3 || $# > 5)) && return 1

    typeset filename
    filename=$2
    typeset end_line

    _Dbg_readin_if_new "$filename"

    typeset -i max_line
    max_line=$(_Dbg_get_maxline "$filename")

    if (( $? != 0 )) ; then
	_Dbg_errmsg "internal error getting number of lines in $filename"
	return 1
    fi

    _Dbg_parse_list_args "$max_line" "$@"

    if (( _Dbg_listline > max_line )) ; then
      _Dbg_errmsg \
	"Line number $_Dbg_listline out of range;" \
      "$filename has $max_line lines."
      return 1
    fi

    (( end_line >  max_line )) && ((end_line=max_line))

    typeset frame_fullfile
    frame_fullfile=${_Dbg_file2canonic[$_Dbg_frame_last_filename]}

    for ((  ; _Dbg_listline <= end_line ; _Dbg_listline++ )) ; do
     typeset prefix='    '
     _Dbg_get_source_line $_Dbg_listline "$filename"

       (( _Dbg_listline == _Dbg_frame_last_lineno )) \
         && [[ $fullname == $frame_fullfile ]] &&  prefix=' => '
      _Dbg_printf "%3d:%s%s" $_Dbg_listline "$prefix" "$_Dbg_source_line"
    done
    return 0
}

_Dbg_list_columns() {
    typeset colsep='  '
    (($# > 0 )) && { colsep="$1"; shift; }
    typeset -i linewidth
    # 2 below is the initial prefix
    if (($# > 0 )) ; then
	((linewidth=$1-2));
	shift
    else
	((linewidth=_Dbg_set_linewidth-2))
    fi
    (($# != 0)) && return 1
    typeset -a columnized; columnize $linewidth "$colsep"
    typeset -i i
    for ((i=0; i<${#columnized[@]}; i++)) ; do
	_Dbg_msg "  ${columnized[i]}"
    done

}
