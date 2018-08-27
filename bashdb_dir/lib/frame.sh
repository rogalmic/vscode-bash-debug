# -*- shell-script -*-
# Call Stack routines
#
#   Copyright (C) 2002, 2003, 2004, 2005, 2006, 2008, 2009, 2010, 2014
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

#================ VARIABLE INITIALIZATIONS ====================#

# _Dbg_stack_size: the number of entries on the call stack at the time
# the hook was entered. Note that bash updates the stack inside the
# debugger so it is important to save this value on entry. Also
# note that the most recent entries are pushed or at position 0.
# Thus to get position 0 of the debugged program we need to ignore leading
# any debugger frames.
typeset -i _Dbg_stack_size

# Where are we in stack? This can be changed by "up", "down" or
# "frame" commands. 0 means the most recent stack frame with respect
# to the debugged program and _Dbg_stack_size is the
# least-recent. Note that inside the debugger the stack is still
# updated.  On debugger entry, the value is set to 0
typeset -i  _Dbg_stack_pos

# Save the last-entered frame for to determine stopping when
# "set force" or step+ is in effect.
typeset _Dbg_frame_last_filename=''
typeset -i _Dbg_frame_last_lineno=0

#======================== FUNCTIONS  ============================#

function _Dbg_frame_adjust {
  (($# != 2)) && return 255

  typeset -i count=$1
  typeset -i signum=$2

  typeset -i retval
  _Dbg_frame_int_setup $count || return 2

  typeset -i pos
  if (( signum==0 )) ; then
      if (( count < 0 )) ; then
	  ((pos = _Dbg_stack_size + count - 1))
      else
	  ((pos = count))
      fi
  else
    ((pos=_Dbg_stack_pos+(count*signum)))
  fi

  if (( pos < 0 )) ; then
    _Dbg_errmsg 'Would be beyond bottom-most (most recent) entry.'
    return 1

  elif (( pos >= _Dbg_stack_size - 1 )) ; then
    _Dbg_errmsg 'Would be beyond top-most (least recent) entry.'
    return 1
  fi

  typeset -i adjusted_pos
  adjusted_pos=$(_Dbg_frame_adjusted_pos $pos)
  _Dbg_stack_pos=$pos

  ## DEBUG
  ## typeset -p pos
  ## typeset -p adjusted_pos
  ## typeset -p BASH_LINENO
  ## typeset -p BASH_SOURCE

  _Dbg_listline="${BASH_LINENO[adjusted_pos-1]}"
  _Dbg_frame_last_filename="${BASH_SOURCE[adjusted_pos]}"
  typeset filename; filename="$(_Dbg_file_canonic "$_Dbg_frame_last_filename")"
  _Dbg_frame_print '->' $_Dbg_stack_pos '' "$filename" $_Dbg_listline ''
  _Dbg_print_location_and_command "$_Dbg_listline"
  return 0
}

# Set $_Dbg_frame_filename to be frame file for the call stack at
# given position $1 or _Dbg_stack_pos if $1 is omitted. If $2 is
# given, it indicates if we want the basename only. Otherwise the
# $_Dbg_set_basename setting is used.  0 is returned if no error,
# nonzero means some sort of error.
_Dbg_frame_file() {
    (($# > 2)) && return 2
    # FIXME check to see that $1 doesn't run off the end.
    typeset -i pos=${1:-$_Dbg_stack_pos}
    typeset -i basename_only=${2:-$_Dbg_set_basename}
    _Dbg_frame_filename=${BASH_SOURCE[pos]}
    (( basename_only )) && _Dbg_frame_filename=${_Dbg_frame_filename##*/}
    return 0
}

# Tests for a signed integer parameter and set global retval
# if everything is okay. Retval is set to 1 on error
_Dbg_frame_int_setup() {

  _Dbg_not_running && return 1
  eval "$_seteglob"
  if [[ $1 != '' && $1 != $_Dbg_signed_int_pat ]] ; then
      _Dbg_errmsg "Bad integer parameter: $1"
      eval "$_resteglob"
      return 1
  fi
  eval "$_resteglob"
  return 0
}

# Turn position $1 which uses 0 to represent the most-recent stack entry
# into which may have additional internal debugger frames pushed on.
function _Dbg_frame_adjusted_pos
{
    if (($# != 1)) ; then
	echo -n '-1'
	return 1
    fi
    typeset -i pos
    ((pos=${#FUNCNAME[@]} - _Dbg_stack_size + $1))
    echo -n $pos
    return 0
}

# Creates a parameter string for return in non-local variable
# _Dbg_parm_str. This is obtained from BASH_ARGC and BASH_ARGV.  On
# entry, _Dbg_next_argc, and _Dbg_next_argv should be set. These
# variables and _Dbg_parm_str are updated on exit.  _Dbg_next_argc is
# and integer index into BASH_ARGC and _Dbg_next_argv is and index
# into BASH_ARGV. On return
_Dbg_frame_fn_param_str() {
    (($# == 0)) || return 1
    _Dbg_is_int "$_Dbg_next_argc" || return 2
    _Dbg_is_int "$_Dbg_next_argv" || return 3

    # add 1 to argument count to compensate for this call (of zero
    # parameters) and at the same time we update _Dbg_next_argc for the
    # next call.
    #
    ((_Dbg_next_argc++))
    typeset -i arg_count=BASH_ARGC[$_Dbg_next_argc]
    if ((arg_count == 0)) ; then
	_Dbg_parm_str=''
    else
	typeset -i i
	_Dbg_parm_str="\"${BASH_ARGV[$_Dbg_next_argv+arg_count-1]}\""
	for (( i=1; i <= arg_count-1; i++ )) ; do
	    _Dbg_parm_str+=", \"${BASH_ARGV[$_Dbg_next_argv+arg_count-i-1]}\""
	done
	((_Dbg_next_argv+=arg_count))
    fi
    return 0
}

_Dbg_frame_set_fn_param() {
    (($# == 1)) || return 1
    typeset -i skip_count=$1
    # Set to ignore this call in computation
    _Dbg_next_argc=1
    _Dbg_next_argv=1

    typeset -i i
    for (( i=1; i <= skip_count; i++ )) ; do
	typeset -i arg_count=${BASH_ARGC[$i]}
	((_Dbg_next_argv+=arg_count))
    done
    # After this function returns argv will be one greater. So adjust
    # for that now.
    ((_Dbg_next_argc=skip_count))
    ((_Dbg_next_argv--))

    ## Debug:
    ## typeset -p BASH_ARGC
    ## typeset -p BASH_ARGV
    ## typeset -p FUNCNAME
    ## typeset -p _Dbg_next_argc
    ## typeset -p _Dbg_next_argv
}

# Print "##" or "->" depending on whether or not $1 (POS) is a number
# between 0 and _Dbg_stack_size-1. For POS, 0 is the top-most
# (newest) entry. For _Dbg_stack_pos, 0 is the bottom-most entry.
# 0 is returnd on success, nonzero on failure.
function _Dbg_frame_prefix {
    typeset    prefix='??'
    typeset -i rc=0
    if (($# == 1)) ; then
	typeset -i pos=$1
	if ((pos < 0)) ; then
	    rc=2
	elif ((pos >= _Dbg_stack_size)) ; then
	    rc=3
	elif (( pos == _Dbg_stack_pos )) ; then
	    prefix='->'
	else
	    prefix='##'
	fi
    else
	rc=1
    fi
    echo -n $prefix
    return $rc
}

# Print one line in a call stack
function _Dbg_frame_print {
    typeset prefix=$1
    typeset -i pos=$2
    typeset fn=$3
    typeset filename="$4"
    typeset -i line=$5
    typeset args="$6"
    typeset callstr=$fn
    [[ -n $args ]] && callstr="$callstr($args)"
    _Dbg_msg "$prefix$pos in file \`$filename' at line $line"
}
