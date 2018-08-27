# -*- shell-script -*-
# break.sh - Debugger Break and Watch routines
#
#   Copyright (C) 2002-2003, 2006-2011, 2014-2016 Rocky Bernstein
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
#   along with this program; see the file COPYING.  If not, write to
#   the Free Software Foundation, 59 Temple Place, Suite 330, Boston,
#   MA 02111 USA.

#================ VARIABLE INITIALIZATIONS ====================#

typeset -a _Dbg_keep
_Dbg_keep=('keep' 'del')

# Note: we loop over possibly sparse arrays with _Dbg_brkpt_max by adding one
# and testing for an entry. Could add yet another array to list only
# used indices. Bash is kind of primitive.

# Breakpoint data structures

# Line number of breakpoint $i
typeset -a _Dbg_brkpt_line; _Dbg_brkpt_line=()

# Number of breakpoints.
typeset -i _Dbg_brkpt_count=0

# filename of breakpoint $i
typeset -a  _Dbg_brkpt_file; _Dbg_brkpt_file=()

# 1/0 if enabled or not
typeset -a  _Dbg_brkpt_enable; _Dbg_brkpt_enable=()

# Number of times hit
typeset -a _Dbg_brkpt_counts; _Dbg_brkpt_counts=()

# Is this a onetime break?
typeset -a _Dbg_brkpt_onetime; _Dbg_brkpt_onetime=()

# Condition to eval true in order to stop.
typeset -a  _Dbg_brkpt_cond; _Dbg_brkpt_cond=()

# Needed because we can't figure out what the max index is and arrays
# can be sparse.
typeset -i  _Dbg_brkpt_max=0

# Maps a resolved filename to a list of beakpoint line numbers in that file
typeset -A _Dbg_brkpt_file2linenos; _Dbg_brkpt_file2linenos=()

# Maps a resolved filename to a list of breakpoint entries.
typeset -A _Dbg_brkpt_file2brkpt; _Dbg_brkpt_file2brkpt=()

# Note: we loop over possibly sparse arrays with _Dbg_brkpt_max by adding one
# and testing for an entry. Could add yet another array to list only
# used indices. Bash is kind of primitive.

# Watchpoint data structures
typeset -a  _Dbg_watch_exp=() # Watchpoint expressions
typeset -a  _Dbg_watch_val=() # values of watchpoint expressions
typeset -ai _Dbg_watch_arith=()  # 1 if arithmetic expression or not.
typeset -ai _Dbg_watch_count=()  # Number of times hit
typeset -ai _Dbg_watch_enable=() # 1/0 if enabled or not
typeset -i  _Dbg_watch_max=0     # Needed because we can't figure out what
                                    # the max index is and arrays can be sparse

typeset     _Dbg_watch_pat="${int_pat}[wW]"

#========================= FUNCTIONS   ============================#

_Dbg_save_breakpoints() {
  typeset file
  typeset -p _Dbg_brkpt_line         >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_file         >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_cond         >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_count        >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_enable       >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_onetime      >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_max          >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_file2linenos >> $_Dbg_statefile
  typeset -p _Dbg_brkpt_file2brkpt   >> $_Dbg_statefile

}

_Dbg_save_watchpoints() {
  typeset -p _Dbg_watch_exp >> $_Dbg_statefile
  typeset -p _Dbg_watch_val >> $_Dbg_statefile
  typeset -p _Dbg_watch_arith >> $_Dbg_statefile
  typeset -p _Dbg_watch_count >> $_Dbg_statefile
  typeset -p _Dbg_watch_enable >> $_Dbg_statefile
  typeset -p _Dbg_watch_max >> $_Dbg_statefile
}

# Start out with general break/watchpoint functions first...

# Enable/disable breakpoint or watchpoint by entry numbers.
_Dbg_enable_disable() {
    if (($# <= 2)) ; then
	_Dbg_errmsg "_Dbg_enable_disable error - need at least 2 args, got $#"
	return 1
    fi
    typeset -i on=$1
    typeset en_dis=$2
    shift; shift

  if [[ $1 == 'display' ]] ; then
    shift
    typeset to_go="$@"
    typeset i
    eval "$_seteglob"
    for i in $to_go ; do
      case $i in
	$int_pat )
	  _Dbg_enable_disable_display $on $en_dis $i
	;;
	* )
	  _Dbg_errmsg "Invalid entry number skipped: $i"
      esac
    done
    eval "$_resteglob"
    return 0
  elif [[ $1 == 'action' ]] ; then
    shift
    typeset to_go="$@"
    typeset i
    eval "$_seteglob"
    for i in $to_go ; do
      case $i in
	$int_pat )
	  _Dbg_enable_disable_action $on $en_dis $i
	;;
	* )
	  _Dbg_errmsg "Invalid entry number skipped: $i"
      esac
    done
    eval "$_resteglob"
    return 0
  fi

  typeset to_go; to_go="$@"
  typeset i
  eval "$_seteglob"
  for i in $to_go ; do
    case $i in
      $_Dbg_watch_pat )
        _Dbg_enable_disable_watch $on $en_dis ${del:0:${#del}-1}
        ;;
      $int_pat )
        _Dbg_enable_disable_brkpt $on $en_dis $i
	;;
      * )
      _Dbg_errmsg "Invalid entry number skipped: $i"
    esac
  done
  eval "$_resteglob"
  return 0
}

# Print a message regarding how many times we've encountered
# breakpoint number $1 if the number of times is greater than 0.
# Uses global array _Dbg_brkpt_counts.
function _Dbg_print_brkpt_count {
  typeset -i i; i=$1
  if (( _Dbg_brkpt_counts[i] != 0 )) ; then
    if (( _Dbg_brkpt_counts[i] == 1 )) ; then
      _Dbg_printf "\tbreakpoint already hit 1 time"
    else
      _Dbg_printf "\tbreakpoint already hit %d times" ${_Dbg_brkpt_counts[$i]}
    fi
  fi
}

#======================== BREAKPOINTS  ============================#

# clear all brkpts
_Dbg_clear_all_brkpt() {
  _Dbg_write_journal_eval "_Dbg_brkpt_file2linenos=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_file2brkpt=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_line=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_cond=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_file=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_enable=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_counts=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_onetime=()"
  _Dbg_write_journal_eval "_Dbg_brkpt_count=0"
}

# Internal routine to a set breakpoint unconditonally.

_Dbg_set_brkpt() {
    (( $# < 3 || $# > 4 )) && return 1
    typeset source_file
    source_file=$(_Dbg_expand_filename "$1")
    typeset -ri lineno=$2
    typeset -ri is_temp=$3
    typeset -r  condition=${4:-1}

    # Increment brkpt_max here because we are 1-origin
    ((_Dbg_brkpt_max++))
    ((_Dbg_brkpt_count++))

    _Dbg_brkpt_line[$_Dbg_brkpt_max]=$lineno
    _Dbg_brkpt_file[$_Dbg_brkpt_max]="$source_file"
    _Dbg_brkpt_cond[$_Dbg_brkpt_max]="$condition"
    _Dbg_brkpt_onetime[$_Dbg_brkpt_max]=$is_temp
    _Dbg_brkpt_counts[$_Dbg_brkpt_max]=0
    _Dbg_brkpt_enable[$_Dbg_brkpt_max]=1

    typeset dq_source_file
    dq_source_file=$(_Dbg_esc_dq "$source_file")
    typeset dq_condition=$(_Dbg_esc_dq "$condition")

    # Make sure we are not skipping over functions.
    _Dbg_old_set_opts="$_Dbg_old_set_opts -o functrace"
    _Dbg_write_journal_eval "_Dbg_old_set_opts='$_Dbg_old_set_opts'"

    _Dbg_write_journal_eval "_Dbg_brkpt_line[$_Dbg_brkpt_max]=$lineno"
    _Dbg_write_journal_eval "_Dbg_brkpt_file[$_Dbg_brkpt_max]=\"$dq_source_file\""
    _Dbg_write_journal "_Dbg_brkpt_cond[$_Dbg_brkpt_max]=\"$dq_condition\""
    _Dbg_write_journal "_Dbg_brkpt_onetime[$_Dbg_brkpt_max]=$is_temp"
    _Dbg_write_journal "_Dbg_brkpt_counts[$_Dbg_brkpt_max]=\"0\""
    _Dbg_write_journal "_Dbg_brkpt_enable[$_Dbg_brkpt_max]=1"

    # Add line number with a leading and trailing space. Delimiting the
    # number with space helps do a string search for the line number.
    _Dbg_write_journal_eval "_Dbg_brkpt_file2linenos[$source_file]+=\" $lineno \""
    _Dbg_write_journal_eval "_Dbg_brkpt_file2brkpt[$source_file]+=\" $_Dbg_brkpt_max \""

    source_file=$(_Dbg_adjust_filename "$source_file")
    if (( is_temp == 0 )) ; then
	_Dbg_msg "Breakpoint $_Dbg_brkpt_max set in file ${source_file}, line $lineno."
    else
	_Dbg_msg "One-time breakpoint $_Dbg_brkpt_max set in file ${source_file}, line $lineno."
    fi
    _Dbg_write_journal "_Dbg_brkpt_max=$_Dbg_brkpt_max"
    return 0
}

# Internal routine to unset the actual breakpoint arrays.
# 0 is returned if successful
_Dbg_unset_brkpt_arrays() {
    (( $# != 1 )) && return 1
    typeset -i del=$1
    _Dbg_write_journal_eval "unset _Dbg_brkpt_line[$del]"
    _Dbg_write_journal_eval "unset _Dbg_brkpt_counts[$del]"
    _Dbg_write_journal_eval "unset _Dbg_brkpt_file[$del]"
    _Dbg_write_journal_eval "unset _Dbg_brkpt_enable[$del]"
    _Dbg_write_journal_eval "unset _Dbg_brkpt_cond[$del]"
    _Dbg_write_journal_eval "unset _Dbg_brkpt_onetime[$del]"
    ((_Dbg_brkpt_count--))
    return 0
}

# Internal routine to delete a breakpoint by file/line.
# We return the number of breakpoints found or zero if we didn't find
# a breakpoint
function _Dbg_unset_brkpt {
    (( $# != 2 )) && return 0

    typeset    filename=$1
    typeset -i lineno=$2
    typeset -i found=0
    typeset    fullname
    fullname=$(_Dbg_expand_filename "$filename")

    # FIXME: combine with _Dbg_hook_breakpoint_hit
    typeset -a linenos
    eval "linenos=(${_Dbg_brkpt_file2linenos[$fullname]})"
    typeset -a brkpt_nos
    eval "brkpt_nos=(${_Dbg_brkpt_file2brkpt[$fullname]})"

    typeset -i i
    # Note: <= rather than < looks funny below, but that is correct.
    for ((i=0; i <= ${#linenos[@]}; i++)); do
	if (( linenos[i] == lineno )) ; then
	    # Got a match, find breakpoint entry number
	    typeset -i brkpt_num
	    (( brkpt_num = brkpt_nos[i] ))
	    _Dbg_unset_brkpt_arrays $brkpt_num
	    unset linenos[i]
	    _Dbg_brkpt_file2linenos[$fullname]=${linenos[@]}
	    typeset -a brkpt_nos
	    eval "brkpt_nos=(${_Dbg_brkpt_file2brkpt[$filename]})"
	    unset brkpt_nos[$i]
	    _Dbg_brkpt_file2brkpt[$filename]=${brkpt_nos[@]}
	    (( found ++ ))
	fi
    done
    if (( found == 0 )) ; then
	filename=$(_Dbg_file_canonic "$filename")
	_Dbg_errmsg "No breakpoint found at $filename, line ${lineno}."
    fi
    return $found
}

# Routine to a delete breakpoint by entry number: $1.
# Returns whether or not anything was deleted.
function _Dbg_delete_brkpt_entry {
    (( $# == 0 )) && return 0
    typeset -r  del="$1"
    typeset -i  i
    typeset -i  found=0

    if [[ -z ${_Dbg_brkpt_file[$del]} ]] ; then
	_Dbg_errmsg "No breakpoint number $del."
	return 1
    fi
    typeset    source_file=${_Dbg_brkpt_file[$del]}
    typeset -i lineno=${_Dbg_brkpt_line[$del]}
    typeset -i try
    typeset    new_lineno_val=''
    typeset    new_brkpt_nos=''
    typeset -i i=-1
    typeset -a brkpt_nos
    brkpt_nos=(${_Dbg_brkpt_file2brkpt[$source_file]})
    for try in ${_Dbg_brkpt_file2linenos[$source_file]} ; do
	((i++))
	if (( brkpt_nos[i] == del )) ; then
	    if (( try != lineno )) ; then
		_Dbg_errmsg 'internal brkpt structure inconsistency'
		return 1
	    fi
	    _Dbg_unset_brkpt_arrays $del
	    ((found++))
	else
	    new_lineno_val+=" $try "
	    new_brkpt_nos+=" ${brkpt_nos[$i]} "
	fi
    done
    if (( found > 0 )) ; then
	if (( ${#new_lineno_val[@]} == 0 )) ; then
	    # Remove array entirely
	    _Dbg_write_journal_eval "unset '_Dbg_brkpt_file2linenos[$source_file]'"
	    _Dbg_write_journal_eval "unset '_Dbg_brkpt_file2brkpt[$source_file]'"
	else
	    # Replace array entries with reduced set.
	    _Dbg_write_journal_eval "_Dbg_brkpt_file2linenos[$source_file]=\"${new_lineno_val}\""
	    _Dbg_write_journal_eval "_Dbg_brkpt_file2brkpt[$source_file]=\"$new_brkpt_nos\""
	fi
	return 0
    fi
    return 1
}

# Enable/disable aciton(s) by entry numbers.
function _Dbg_enable_disable_action {
    (($# != 3)) && return 1
    typeset -i on=$1
    typeset en_dis=$2
    typeset -i i=$3
    if [[ -n "${_Dbg_brkpt_file[$i]}" ]] ; then
	if [[ ${_Dbg_action_enable[$i]} == $on ]] ; then
	    _Dbg_errmsg "Breakpoint entry $i already ${en_dis}, so nothing done."
	    return 1
	else
	    _Dbg_write_journal_eval "_Dbg_brkpt_enable[$i]=$on"
	    _Dbg_msg "Action entry $i $en_dis."
	    return 0
	fi
    else
	_Dbg_errmsg "Action entry $i doesn't exist, so nothing done."
	return 1
    fi
}

# Enable/disable breakpoint(s) by entry numbers.
function _Dbg_enable_disable_brkpt {
    (($# != 3)) && return 1
    typeset -i on=$1
    typeset en_dis=$2
    typeset -i i=$3
    if [[ -n "${_Dbg_brkpt_file[$i]}" ]] ; then
	if [[ ${_Dbg_brkpt_enable[$i]} == $on ]] ; then
	    _Dbg_errmsg "Breakpoint entry $i already ${en_dis}, so nothing done."
	    return 1
	else
	    _Dbg_write_journal_eval "_Dbg_brkpt_enable[$i]=$on"
	    _Dbg_msg "Breakpoint entry $i $en_dis."
	    return 0
	fi
    else
	_Dbg_errmsg "Breakpoint entry $i doesn't exist, so nothing done."
	return 1
    fi
}

#======================== WATCHPOINTS  ============================#

_Dbg_get_watch_exp_eval() {
  typeset -i i=$1
  typeset new_val

  if [[ $(eval echo \"${_Dbg_watch_exp[$i]}\") == "" ]]; then
    new_val=''
  elif (( _Dbg_watch_arith[$i] == 1 )) ; then
    . ${_Dbg_libdir}/dbg-set-d-vars.inc
    eval let new_val=\"${_Dbg_watch_exp[$i]}\"
  else
    . ${_Dbg_libdir}/dbg-set-d-vars.inc
    eval new_val="${_Dbg_watch_exp[$i]}"
  fi
  echo $new_val
}

# Enable/disable watchpoint(s) by entry numbers.
_Dbg_enable_disable_watch() {
  typeset -i on=$1
  typeset en_dis=$2
  typeset -i i=$3
  if [ -n "${_Dbg_watch_exp[$i]}" ] ; then
    if [[ ${_Dbg_watch_enable[$i]} == $on ]] ; then
      _Dbg_msg "Watchpoint entry $i already $en_dis so nothing done."
    else
      _Dbg_write_journal_eval "_Dbg_watch_enable[$i]=$on"
      _Dbg_msg "Watchpoint entry $i $en_dis."
    fi
  else
    _Dbg_msg "Watchpoint entry $i doesn't exist so nothing done."
  fi
}

_Dbg_list_watch() {
  if [ ${#_Dbg_watch_exp[@]} != 0 ]; then
    typeset i=0 j
    _Dbg_section "Num Type       Enb  Expression"
    for (( i=0; (( i < _Dbg_watch_max )); i++ )) ; do
      if [ -n "${_Dbg_watch_exp[$i]}" ] ;then
	_Dbg_printf '%-3d watchpoint %-4s %s' $i \
	  ${_Dbg_yn[${_Dbg_watch_enable[$i]}]} \
          "${_Dbg_watch_exp[$i]}"
	_Dbg_print_brkpt_count ${_Dbg_watch_count[$i]}
      fi
    done
  else
    _Dbg_msg "No watch expressions have been set."
  fi
}

_Dbg_delete_watch_entry() {
  typeset -i del=$1

  if [ -n "${_Dbg_watch_exp[$del]}" ] ; then
    _Dbg_write_journal_eval "unset _Dbg_watch_exp[$del]"
    _Dbg_write_journal_eval "unset _Dbg_watch_val[$del]"
    _Dbg_write_journal_eval "unset _Dbg_watch_enable[$del]"
    _Dbg_write_journal_eval "unset _Dbg_watch_count[$del]"
  else
    _Dbg_msg "Watchpoint entry $del doesn't exist so nothing done."
  fi
}

_Dbg_clear_watch() {
  if (( $# < 1 )) ; then
    typeset _Dbg_prompt_output=${_Dbg_tty:-/dev/null}
    read $_Dbg_edit -p "Delete all watchpoints? (y/n): " \
      <&$_Dbg_input_desc 2>>$_Dbg_prompt_output

    if [[ $REPLY == [Yy]* ]] ; then
      _Dbg_write_journal_eval unset _Dbg_watch_exp[@]
      _Dbg_write_journal_eval unset _Dbg_watch_val[@]
      _Dbg_write_journal_eval unset _Dbg_watch_enable[@]
      _Dbg_write_journal_eval unset _Dbg_watch_count[@]
      _Dbg_msg "All Watchpoints have been cleared"
    fi
    return 0
  fi

  eval "$_seteglob"
  if [[ $1 == $int_pat ]]; then
    _Dbg_write_journal_eval "unset _Dbg_watch_exp[$1]"
    _msg "Watchpoint $i has been cleared"
  else
    _Dbg_list_watch
    _basdhb_msg "Please specify a numeric watchpoint number"
  fi

  eval "$_resteglob"
}
