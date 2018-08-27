# -*- shell-script -*-
# dbg-processor.sh - Top-level debugger commands
#
#   Copyright (C) 2008-2012, 2015
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

# Are we inside the middle of a "skip" command?
typeset -i  _Dbg_inside_skip=0

# Hooks that get run on each command loop
typeset -A _Dbg_cmdloop_hooks
_Dbg_cmdloop_hooks['display']='_Dbg_eval_all_display'

# Can be bash's "read" builtin or a command-completing "read" builtin
# provided by this debugger.
typeset _Dbg_read_fn; _Dbg_read_fn='read'


# A variable holding a space is set so it can be used in a "set prompt" command
# ("read" in the main command loop will remove a trailing space so we need
# another way to allow a user to enter spaces in the prompt.)

typeset _Dbg_space=' '

# Should we allow editing of debugger commands?
# The value should either be '-e' or ''. And if it is
# on, the edit style indicates what style edit keystrokes.
typeset _Dbg_edit='-e'
typeset _Dbg_edit_style='emacs'  # or vi
set -o $_Dbg_edit_style

# What do we use for a debugger prompt? Technically we don't need to
# use the above $bashdb_space in the assignment below, but we put it
# in to suggest to a user that this is how one gets a spaces into the
# prompt.

typeset _Dbg_prompt_str='$_Dbg_debugger_name${_Dbg_less}${#_Dbg_history[@]}${_Dbg_greater}$_Dbg_space'

# The arguments in the last "x" command.
typeset _Dbg_last_x_args=''

# The canonical name of last command run.
typeset _Dbg_last_cmd=''

# A list of debugger command input-file descriptors.
# Duplicate standard input
typeset -i _Dbg_fdi ; exec {_Dbg_fdi}<&0

typeset -i _Dbg_fd_last=0

# keep a list of source'd command files. If the entry is "" then we are
# interactive.
typeset -a _Dbg_cmdfile; _Dbg_cmdfile=('')

# A list of debugger command input-file descriptors.
typeset -a _Dbg_fd; _Dbg_fd=($_Dbg_fdi)

typeset _Dbg_prompt_output

# ===================== FUNCTIONS =======================================

# The main debugger command reading loop.
#
# Note: We have to be careful here in naming "local" variables. In contrast
# to other places in the debugger, because of the read/eval loop, they are
# in fact seen by those using the debugger. So in contrast to other "local"s
# in the debugger, we prefer to preface these with _Dbg_.
function _Dbg_process_commands {

  # THIS SHOULD BE DONE IN dbg-sig.sh, but there's a bug in BASH in
  # trying to change "trap RETURN" inside a "trap RETURN" handler....
  # Turn off return trapping. Not strictly necessary, since it *should* be
  # covered by the _Dbg_ test below if we've named functions correctly.
  # However turning off the RETURN trap should reduce unnecessary
  # trap RETURN calls.

  _Dbg_inside_skip=0
  _Dbg_step_ignore=-1  # Nuke any prior step ignore counts
  _Dbg_continue_rc=-1  # Don't continue exectuion unless told to do so.
  _Dbg_write_journal "_Dbg_step_ignore=$_Dbg_step_ignore"

  typeset key

  # Evaluate all hooks
  for key in ${!_Dbg_cmdloop_hooks[@]} ; do
      ${_Dbg_cmdloop_hooks[$key]}
  done

  # Loop over all pending open input file descriptors
  while (( _Dbg_fd_last > 0)) ; do

    # Set up prompt to show shell and subshell levels.
    typeset _Dbg_greater=''
    typeset _Dbg_less=''
    typeset result  # Used by copies to return a value.

    if _Dbg_copies '>' $_Dbg_DEBUGGER_LEVEL ; then
        _Dbg_greater=$result
        _Dbg_less=${result//>/<}
    fi
    if _Dbg_copies ')' $BASH_SUBSHELL ; then
        _Dbg_greater="${result}${_Dbg_greater}"
        _Dbg_less="${_Dbg_less}${result//)/(}"
    fi

    # Loop over debugger commands. But before reading a debugger
    # command, we need to make sure IFS is set to spaces to ensure our
    # two variables (command name and rest of the arguments) are set
    # correctly.  Saving the IFS and setting it to the "normal" value
    # of space should be done in the DEBUG signal handler entry.

    # Also, we need to make sure the prompt output is
    # redirected to the debugger terminal.  Both of these things may
    # have been changed by the debugged program for its own
    # purposes. Furthermore, were we *not* to redirect our stderr
    # below, we may mess up what the debugged program expects to see
    # in in stderr by adding our debugger prompt.

    # if no tty, no prompt
    _Dbg_prompt_output=${_Dbg_tty:-/dev/null}

    eval "local _Dbg_prompt=$_Dbg_prompt_str"
    _Dbg_preloop

    typeset _Dbg_cmd
    typeset args
    typeset rc

    while : ; do
        set -o history
        _Dbg_input_desc=${_Dbg_fd[_Dbg_fd_last]}
        if [[ $_Dbg_tty == '&1' ]] ; then
            echo -n "$_Dbg_prompt"
            if ! read _Dbg_cmd args <&$_Dbg_input_desc 2>&1; then
                break
            fi
        else
            if ((_Dbg_set_read_completion)) ; then
                _Dbg_read_fn='readc'
            else
                _Dbg_read_fn='read'
            fi
            if ! $_Dbg_read_fn $_Dbg_edit -p "$_Dbg_prompt" _Dbg_cmd args \
                <&$_Dbg_input_desc 2>>$_Dbg_prompt_output ; then
                set +o history
                break
            fi
        fi

        # FIXME: until I figure out to fix builtin readc, this happens
        # on command completion:
        if [[ $_Dbg_cmd =~ ' ' && -z $args ]] ; then
            typeset -a ary; IFS=' ' ary=( $_Dbg_cmd )
            _Dbg_cmd=${ary[0]}
            unset ary[0]
            args="${ary[@]}"
        fi
        set +o history
        if (( _Dbg_brkpt_commands_defining )) ; then
          case $_Dbg_cmd in
              silent )
                  _Dbg_brkpt_commands_silent[$_Dbg_brkpt_commands_current]=1
                  continue
                  ;;
              end )
                  _Dbg_brkpt_commands_defining=0
                  #### ??? TESTING
                  ## local -i cur=$_Dbg_brkpt_commands_current
                  ## local -i start=${_Dbg_brkpt_commands_start[$cur]}
                  ## local -i end=${_Dbg_brkpt_commands_end[$cur]}
                  ## local -i i
                  ## echo "++ brkpt: $cur, start: $start, end: $end "
                  ## for (( i=start; (( i < end )) ; i++ )) ; do
                  ##    echo ${_Dbg_brkpt_commands[$i]}
                  ## done
                  eval "_Dbg_prompt=$_Dbg_prompt_str"
                  continue
                  ;;
              *)
                  _Dbg_brkpt_commands[${#_Dbg_brkpt_commands[@]}]="$_Dbg_cmd $args"
                  (( _Dbg_brkpt_commands_end[$_Dbg_brkpt_commands_current]++ ))
                  continue
                  ;;
         esac
         rc=$?
     else
        _Dbg_onecmd "$_Dbg_cmd" "$args"
        _Dbg_postcmd
    fi
    ((_Dbg_continue_rc >= 0)) && return $_Dbg_continue_rc

    if (( _Dbg_brkpt_commands_defining )) ; then
       _Dbg_prompt='>'
    else
       eval "_Dbg_prompt=$_Dbg_prompt_str"
    fi

    done  # while read $_Dbg_edit -p ...

    unset _Dbg_fd[_Dbg_fd_last--]
  done  # Loop over all open pending file descriptors

  # EOF hit. Same as quit without arguments
  _Dbg_msg '' # Cause <cr> since EOF may not have put in.
  _Dbg_do_quit
}

# Run a debugger command "annotating" the output
_Dbg_annotation() {
    typeset label="$1"
    shift
    _Dbg_do_print "$label"
    $*
    _Dbg_do_print  ''
}

# Run a single command
# Parameters: _Dbg_cmd and args
#
_Dbg_onecmd() {
    typeset full_cmd=$@
    typeset _Dbg_orig_cmd="$1"
    typeset expanded_alias; _Dbg_alias_expand "$_Dbg_orig_cmd"
    typeset _Dbg_cmd="$expanded_alias"
    shift
    typeset _Dbg_args="$@"

     # Set default next, step or skip command
     if [[ -z $_Dbg_cmd ]]; then
        _Dbg_cmd=$_Dbg_last_next_step_cmd
        _Dbg_args=$_Dbg_last_next_step_args
        full_cmd="$_Dbg_cmd $_Dbg_args"
      fi

     # If "set trace-commands" is "on", echo the the command
     if [[  $_Dbg_set_trace_commands == 'on' ]]  ; then
         _Dbg_msg "+$full_cmd"
     fi

     local dq_cmd=$(_Dbg_esc_dq "$_Dbg_cmd")
     local dq_args=$(_Dbg_esc_dq "$_Dbg_args")

     # _Dbg_write_journal_eval doesn't work here. Don't really understand
     # how to get it to work. So we do this in two steps.
     _Dbg_write_journal \
        "_Dbg_history[${#_Dbg_history[@]}]=\"$dq_cmd $dq_args\""

     _Dbg_history[${#_Dbg_history[@]}]="$_Dbg_cmd $_Dbg_args"

     _Dbg_hi=${#_Dbg_history[@]}
     history -s -- "$full_cmd"

     typeset -i _Dbg_redo=1
     while (( _Dbg_redo )) ; do

         _Dbg_redo=0

         [[ -z $_Dbg_cmd ]] && _Dbg_cmd=$_Dbg_last_cmd
         if [[ -n $_Dbg_cmd ]] ; then
             typeset -i found=0
             typeset found_cmd
             if [[ -n ${_Dbg_debugger_commands[$_Dbg_cmd]} ]] ; then
                 found=1
                 found_cmd=$_Dbg_cmd
             else
                 # Look for a unique abbreviation
                 typeset -i count=0
                 typeset list; list="${!_Dbg_debugger_commands[@]}"
                 for try in $list ; do
                     if [[ $try =~ ^$_Dbg_cmd ]] ; then
                         found_cmd=$try
                         ((count++))
                     fi
                 done
                 ((found=(count==1)))
             fi
             if ((found)); then
                 ${_Dbg_debugger_commands[$found_cmd]} $_Dbg_args
                 IFS=$_Dbg_space_IFS;
                 eval "_Dbg_prompt=$_Dbg_prompt_str"
                 ((_Dbg_continue_rc >= 0)) && return $_Dbg_continue_rc
                 continue
             fi
         fi

         case $_Dbg_cmd in

             # Comment line
             [#]* )
                 _Dbg_history_remove_item
                 _Dbg_last_cmd='#'
                 ;;

             # list current line
             . )
                 _Dbg_list $_Dbg_frame_last_filename $_Dbg_frame_last_lineno 1
                 _Dbg_last_cmd='list'
                 ;;

             # Search forwards for pattern
             /* )
                 _Dbg_do_search $_Dbg_cmd
                 _Dbg_last_cmd='search'
                 ;;

             # Search backwards for pattern
             [?]* )
                 _Dbg_do_reverse $_Dbg_cmd
                 _Dbg_last_cmd="reverse"
                 ;;

             # Change Directory
             cd )
                 # Allow for tilde expansion. We also allow expansion of
                 # variables like $HOME which gdb doesn't allow. That's life.
                 local cd_command="cd $_Dbg_args"
                 eval $cd_command
                 _Dbg_do_pwd
                 _Dbg_last_cmd='cd'
                 ;;

             # complete
             comp | compl | comple | complet | complete )
                 _Dbg_do_complete $_Dbg_args
                 _Dbg_last_cmd='complete'
                 ;;

             # Set up a script for debugging into.
             debug )
                 _Dbg_do_debug $_Dbg_args
                 # Skip over the execute statement which presumably we ran above.
                 _Dbg_do_next_skip 'skip' 1
                 IFS="$_Dbg_old_IFS";
                 return 1
                 _Dbg_last_cmd='debug'
                 ;;

             # Delete all breakpoints.
             D | deletea | deleteal | deleteall )
                 _Dbg_clear_all_brkpt
                 _Dbg_last_cmd='deleteall'
                 ;;

             # return from function/source without finishing executions
             return )
                 ;;

             # run shell command. Has to come before ! below.
             shell | '!!' )
                 eval $_Dbg_args ;;

             # Send signal to process
             si | sig | sign | signa | signal )
                 _Dbg_do_signal $_Dbg_args
                 _Dbg_last_cmd='signal'
                 ;;

             # single-step
             'step+' | 'step-' )
                 _Dbg_do_step "$_Dbg_cmd" $_Dbg_args
                 return 0
                 ;;

             # # toggle execution trace
             # to | tog | togg | toggl | toggle )
             #   _Dbg_do_trace
             #   ;;


             # List all breakpoints and actions.
             L )
                 _Dbg_do_list_brkpt
                 _Dbg_list_watch
                 _Dbg_list_action
                 ;;

             # Remove all actions
             A )
                 _Dbg_do_clear_all_actions $_Dbg_args
                 ;;

             # List debugger command history
             H )
                 _Dbg_history_remove_item
                 _Dbg_do_history_list $_Dbg_args
                 ;;

             #  S List subroutine names
             S )
                 _Dbg_do_list_functions $_Dbg_args
                 ;;

             # Dump variables
             V )
                 _Dbg_do_info_variables "$_Dbg_args"
                 ;;

             # Has to come after !! of "shell" listed above
             # Run an item from the command history
             \!* | history )
                 _Dbg_do_history $_Dbg_args
                 ;;

             '' )
                 # Redo last_cmd
                 if [[ -n $_Dbg_last_cmd ]] ; then
                     _Dbg_cmd=$_Dbg_last_cmd
                     _Dbg_redo=1
                 fi
                 ;;
             * )

                 if (( _Dbg_set_autoeval )) ; then
                     _Dbg_do_eval $_Dbg_cmd $_Dbg_args
                 else
                     _Dbg_undefined_cmd "$_Dbg_cmd"
                     _Dbg_history_remove_item
                     # local -a last_history=(`history 1`)
                     # history -d ${last_history[0]}
                 fi
                 ;;
         esac
     done # while (( $_Dbg_redo ))

     IFS=$_Dbg_space_IFS;
     eval "_Dbg_prompt=$_Dbg_prompt_str"
}

_Dbg_preloop() {
    if ((_Dbg_set_annotate)) ; then
        _Dbg_annotation 'breakpoints' _Dbg_do_info breakpoints
        # _Dbg_annotation 'locals'      _Dbg_do_backtrace 3
        _Dbg_annotation 'stack'       _Dbg_do_backtrace 3
    fi
}

_Dbg_postcmd() {
    if ((_Dbg_set_annotate)) ; then
        case $_Dbg_last_cmd in
            break | tbreak | disable | enable | condition | clear | delete )
                _Dbg_annotation 'breakpoints' _Dbg_do_info breakpoints
                ;;
            up | down | frame )
                _Dbg_annotation 'stack' _Dbg_do_backtrace 3
                ;;
            * )
        esac
    fi
}
