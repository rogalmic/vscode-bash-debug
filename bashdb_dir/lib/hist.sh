# -*- shell-script -*-
# hist.sh - Bourne Again Shell Debugger history routines
#
#   Copyright (C) 2002-2003, 2006-2008, 2011, 2015 Rocky Bernstein
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
#   You should have received a copy of the GNU General Public License
#   along with This program; see the file COPYING.  If not, write to
#   the Free Software Foundation, 59 Temple Place, Suite 330, Boston,
#   MA 02111 USA.

typeset -i _Dbg_hi_last_stop=0
typeset -i _Dbg_hi=0           # Current next history entry to store into.
typeset -a _Dbg_history; _Dbg_history=()

typeset -i _Dbg_set_history=1
typeset -i _Dbg_history_length=${HISTSIZE:-256}  # gdb's default value
typeset _Dbg_histfile=${HOME:-.}/.bashdb_hist

# Set to rerun history item, or print history if command is of the form
#  !n:p. If command is "history" then $1 is number of history item.
# the history command index to run is returned or $_Dbg_hi if
# there's nothing to run.
# Return value in $history_num
_Dbg_history_parse() {

  history_num=$1
  ((history_num < 0)) && ((history_num=${#_Dbg_history[@]}-1+$1))

  _Dbg_hi=${#_Dbg_history[@]}
  [[ -z $history_num ]] && let history_num=$_Dbg_hi-1

  if [[ $_Dbg_cmd == h* ]] ; then
    if [[ $history_num != $int_pat ]] ; then
      if [[ $history_num == -$int_pat ]] ; then
	history_num=$_Dbg_hi+$history_num
      else
	_Dbg_errmsg "Invalid history number skipped: $history_num"
	history_num=-1
      fi
    fi
  else
    # Handle ! form. May need to parse number out number and modifier
    # case $_Dbg_cmd in
    #   \!\-${int_pat}:p )
    # 	typeset -a word1
    # 	word1=($(_Dbg_split '!' $_Dbg_cmd))
    # 	local -a word2
    # 	word2=($(_Dbg_split ':' ${word1[0]}))
    # 	typeset -i num=_Dbg_hi+${word2[0]}
    # 	_Dbg_do_history_list $num $num
    # 	history_num=-1
    # 	;;
    #   [!]${int_pat}:p )
    # 	local -a word1
    # 	word1=($(_Dbg_split '!' $_Dbg_cmd))
    # 	local -a word2
    # 	word2=($(_Dbg_split ':' ${word1[0]}))
    # 	_Dbg_do_history_list ${word2[0]} ${word2[0]}
    # 	history_num=-1
    # 	;;
    #   \!\-$int_pat )
    # 	local -a word
    # 	word=($(_Dbg_split '!' $_Dbg_cmd))
    # 	history_num=$_Dbg_hi+${word[0]}
    # 	;;
    #   \!$int_pat )
    # 	local -a word
    # 	word=($(_Dbg_split '!' $_Dbg_cmd))
    # 	history_num=${word[0]}
    # 	;;
    #   '!' )
    #     if [[ $history_num != $int_pat ]] ; then
    # 	  if [[ $history_num == -$int_pat ]] ; then
    # 	    history_num=$_Dbg_hi+$history_num
    # 	  else
    # 	    _Dbg_msg "Invalid history number skipped: $history_num"
    # 	    history_num=-1
    # 	  fi
    # 	fi
    #   ;;
    #  * )
    #  _Dbg_errmsg "Invalid history number skipped: $_Dbg_cmd"
    #  history_num=-1
    # esac
      :
  fi
}

_Dbg_history_read() {
  if [[ -r $_Dbg_histfile ]] ; then
    history -r $_Dbg_histfile
    typeset -a last_history; last_history=($(history 1))
    typeset -i max_history=${last_history[0]}
    if (( max_history > _Dbg_history_length )) ; then
      max_history=$_Dbg_history_length
    fi
    local OLD_HISTTIMEFORMAT=${HISTTIMEFORMAT}
    local hist
    HISTTIMEFORMAT=''
    local -i i
    for (( i=1; (( i <= max_history )) ; i++ )) ; do
      last_history=($(history $i))
      hist=${last_history}[1]
      # _Dbg_history[$i]=$hist
    done
    HISTTIMEFORMAT=${OLD_HISTTIMEFORMAT}
  fi
}

# Save history file
_Dbg_history_write() {
    (( _Dbg_history_length > 0 && _Dbg_set_history)) \
	&& history -w $_Dbg_histfile
}

# Remove the last command from the history list.
_Dbg_history_remove_item() {
  _Dbg_hi=${#_Dbg_history[@]}-1
  unset _Dbg_history[$_Dbg_hi]
}

# _Dbg_history_read
