# -*- shell-script -*-
# hist.sh - history routines
#
#   Copyright (C) 2002, 2003, 2006, 2007, 2008, 2009, 2011 Rocky Bernstein
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

_Dbg_help_add history \
"history [N]

Rerun a debugger command from the debugger history. 

See also H to list the history. If N is negative you are you going
back that many items from the end rather specifying an absolute history number."

_Dbg_do_history() {
  typeset -i history_num
  _Dbg_history_parse $@
  _Dbg_history_remove_item
  if (( history_num >= 0 )) ; then 
      if (( history_num < ${#_Dbg_history[@]} )) ; then 
	  set ${_Dbg_history[$history_num]}
	  _Dbg_cmd=$1
	  shift
	  _Dbg_args="$@"
	  _Dbg_redo=1;
      else
	  _Dbg_errmsg \
	      "Number $1 ($history_num) should be less than ${#_Dbg_history[@]}"
	  return 1
      fi
  fi
  return 0
}

# Print debugger history $1 is where to start or highest number if not given.
# If $1 is negative, it is how many history items.
# $2 is where to stop or 0 if not given.
_Dbg_do_history_list() {

  eval "$_seteglob"
  if [[ $1 != $int_pat ]] && [[ $1 != -$int_pat ]] && [[ -n $1 ]] ; then 
    _Dbg_msg "Invalid history number: $1"
    eval "$_resteglob"
    return 1
  fi
  eval "$_resteglob"

  _Dbg_hi=${#_Dbg_history[@]}
  local -i n=${1:-$_Dbg_hi-1}
  local -i stop=${2:0}
  local -i i

  # Were we given a count rather than a starting history number? 
  if (( n<0 )) ; then
    ((stop=_Dbg_hi+n))
    ((n=_Dbg_hi-1))
  elif (( n > _Dbg_hi-1 )) ; then
    ((n=_Dbg_hi-1))
  fi

  for (( i=n ; i >= stop && i >= 0; i-- )) ; do
    _Dbg_msg "${i}: ${_Dbg_history[$i]}"
  done
  return 0
}

_Dbg_alias_add '!' 'history'
