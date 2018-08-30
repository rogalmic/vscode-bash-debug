# -*- shell-script -*-
# filecache.sh - cache file information
#
#   Copyright (C) 2008-2011, 2013-2015, 2018 Rocky Bernstein
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
#   with this program; see the file COPYING.  If not, write to the Free Software
#   Foundation, 59 Temple Place, Suite 330, Boston, MA 02111 USA.

typeset _Dbg_bogus_file=' A really bogus file'

# Maps a name into its canonic form which can then be looked up in filenames
typeset -A _Dbg_file2canonic
_Dbg_file2canonic=()

# Information about a file.
typeset -A _Dbg_fileinfo

# Keys are the canonic expanded filename. _Dbg_filenames[filename] is
# name of variable which contains text.
typeset -A _Dbg_filenames

_Dbg_filecache_reset() {
    _Dbg_filenames=()
    _Dbg_fileinfo=()
    _Dbg_file2canonic=()
}
_Dbg_filecache_reset

# Check that line $2 is not greater than the number of lines in
# file $1
_Dbg_check_line() {
    (( $# != 2 )) && return 1
    typeset -i line_number=$1
    typeset filename="$2"
    typeset -i max_line
    max_line=$(_Dbg_get_maxline "$filename")
    if (( $? != 0 )) ; then
	_Dbg_errmsg "internal error getting number of lines in $filename"
	return 1
    fi

    if (( line_number >  max_line )) ; then
	(( _Dbg_set_basename )) && filename=${filename##*/}
	_Dbg_errmsg "Line $line_number is too large." \
	    "File $filename has only $max_line lines."
	return 1
    fi
    return 0
}

# Error message for file not read in
function _Dbg_file_not_read_in {
    typeset -r filename=$(_Dbg_adjust_filename "$1")
    _Dbg_errmsg "File \"$filename\" not found in read-in files."
    _Dbg_errmsg "See 'info files' for a list of known files and"
    _Dbg_errmsg "'load' to read in a file."
}

# Print the maximum line of filename $1. $1 is expected to be
# read in already and therefore stored in _Dbg_file2canonic.
function _Dbg_get_maxline {
    (( $# != 1 )) && return -1
    _Dbg_set_source_array_var "$1" || return $?
    typeset -r line_count_cmd="line_count=\${#$_Dbg_source_array_var[@]}"
    eval $line_count_cmd
    eval "typeset last_line; last_line=\${${_Dbg_source_array_var}[$line_count]}"
    # If the file had a final newline the last line of the data read in
    # is the empty string.  We want to count the last line whether or
    # not it had a newline.
    typeset -i last_not_null=0
    # [[ -z $last_line ]] && last_line_is_null=1 || last_line_is_null=0
    ((line_count=line_count-last_line_is_null))
    echo $line_count
    return $?
}

# Return text for source line for line $1 of filename $2 in variable
# $_Dbg_source_line.

# If $2 is omitted, use _Dbg_frame_filename, if $1 is omitted use
# _Dbg_frame_last_lineno. The return value is put in _Dbg_source_line.
_Dbg_get_source_line() {
    typeset -i lineno
    if (( $# == 0 )); then
	lineno=$_Dbg_frame_last_lineno
    else
	lineno=$1
	shift
    fi
    typeset filename
    if (( $# == 0 )) ; then
	filename="$_Dbg_frame_last_filename"
    else
	filename="$1"
    fi
    _Dbg_readin_if_new "$filename"
    if [[ -n $_Dbg_set_highlight ]] && [[ -n $_Dbg_highlight_array_var ]]; then
	eval "typeset -i count=\${#$_Dbg_highlight_array_var[@]}"
	if (( count  )) ; then
	    eval "_Dbg_source_line=\${$_Dbg_highlight_array_var[lineno]}"
	else
	    eval "_Dbg_source_line=\${$_Dbg_source_array_var[$lineno]}"
	fi
    else
	eval "_Dbg_source_line=\${$_Dbg_source_array_var[$lineno]}"
    fi
}

# _Dbg_is_file echoes the full filename if $1 is a filename found in files
# '' is echo'd if no file found. Return 0 (in $?) if found, 1 if not.
function _Dbg_is_file {
  if (( $# == 0 )) ; then
    _Dbg_errmsg "Internal debug error _Dbg_is_file(): null file to find"
    echo ''
    return 1
  fi
  # first character might be encoded as \057 == '/',
  # find_file:0:1 == "\" , true story
  typeset find_file="$(printf "$1")"
  typeset try_find_file

  if [[ -z $find_file ]] ; then
    _Dbg_errmsg "Internal debug error _Dbg_is_file(): file argument null"
    echo ''
    return 1
  fi

  if [[ ${find_file:0:1} == '/' ]] ; then
      # Absolute file name
      try_find_file=$(_Dbg_expand_filename "$find_file")
      if [[ -n ${_Dbg_filenames[$try_find_file]} ]] ; then
	  echo "$try_find_file"
	  return 0
      fi
  elif [[ ${find_file:0:1} == '.' ]] ; then
      # Relative file name
      try_find_file=$(_Dbg_expand_filename "${_Dbg_init_cwd}/$find_file")
      # FIXME: turn into common subroutine
      if [[ -n ${_Dbg_filenames[$try_find_file]} ]] ; then
	  echo "$try_find_file"
	  return 0
      fi
  else
    # Resolve file using _Dbg_dir
    typeset -i n=${#_Dbg_dir[@]}
    typeset -i i
    for (( i=0 ; i < n; i++ )) ; do
      typeset basename="${_Dbg_dir[i]}"
      if [[  $basename == '\$cdir' ]] ; then
	basename=$_Dbg_cdir
      elif [[ $basename == '\$cwd' ]] ; then
	basename=$(pwd)
      fi
      try_find_file="$basename/$find_file"
      if [[ -f "$try_find_file" ]] ; then
	  echo "$try_find_file"
	  return 0
      fi
    done
  fi
  echo ''
  return 1
}

# Read $1 into _Dbg_source_*n* array where *n* is an entry in
# _Dbg_filenames.  Variable _Dbg_source_array_var will be set to
# _Dbg_source_*n* and filename will be saved in array
# _Dbg_filenames. fullname is set to the expanded filename
# 0 is returned if everything went ok.
function _Dbg_readin {
    typeset filename
    if (($# != 0)) ; then
	filename="$1"
    else
	_Dbg_frame_file
	filename="$_Dbg_frame_filename"
    fi

    typeset -i line_count=0

    typeset -i next;
    next=${#_Dbg_filenames[@]}
    _Dbg_source_array_var="_Dbg_source_${next}"
    if [[ -n $_Dbg_set_highlight ]] ; then
	_Dbg_highlight_array_var="_Dbg_highlight_${next}"
    fi

    typeset filevar
    typeset source_array
    typeset -ri NOT_SMALLFILE=1000

    if [[ -z $filename ]] || [[ $filename == "$_Dbg_bogus_file" ]] ; then
	eval "${_Dbg_source_array_var}[0]=\"$Dbg_EXECUTION_STRING\""
  else
	fullname=$(_Dbg_resolve_expand_filename "$filename")
	if [[ -r $fullname ]] ; then
	    typeset -r progress_prefix="Reading $filename"
	    _Dbg_file2canonic[$filename]="$fullname"
	    _Dbg_file2canonic[$fullname]="$fullname"
	    # Use readarray which speeds up reading greatly.
	    typeset -ri BIGFILE=30000
	    if wc -l < /dev/null >/dev/null 2>&1 ; then
		line_count=$(wc -l < "${fullname}")
		if (( line_count >= NOT_SMALLFILE )) ; then
		    _Dbg_msg_nocr "${progress_prefix} "
		fi
	    fi
	    builtin readarray -t -O 1 -c $BIGFILE \
		-C "_Dbg_progess_show \"${progress_prefix}\" ${line_count}" \
		$_Dbg_source_array_var < "$fullname"
	    if [[ -n $_Dbg_set_highlight ]] ; then
		opts="--bg=${_Dbg_set_highlight}"
		if [[ -n $_Dbg_set_style ]] ; then
		    opts="--style=${_Dbg_set_style}"
		fi
		highlight_cmd="${_Dbg_libdir}/lib/term-highlight.py $opts $fullname"
		tempfile=$($highlight_cmd 2>/dev/null)
		if (( 0  == $? )) ; then
		    builtin readarray -t -O 1 -c $BIGFILE \
			-C "_Dbg_progess_show \"${progress_prefix}\" ${line_count}" \
			$_Dbg_highlight_array_var < "$tempfile"
		fi
		[[ -r "$tempfile" ]] && rm "$tempfile"
	    fi
	    (( line_count > BIGFILE)) && _Dbg_progess_done
	else
	    return 1
	fi
    fi

    typeset -r line_count_cmd="line_count=\${#${_Dbg_source_array_var[@]}}"
    eval $line_count_cmd

    (( line_count >= NOT_SMALLFILE )) && _Dbg_msg "done."

    # Add $filename to list of all filenames
    _Dbg_filenames["$fullname"]=$_Dbg_source_array_var;
    return 0
}

# Read in file $1 unless it has already been read in.
# 0 is returned if everything went ok.
_Dbg_readin_if_new() {
    (( $# != 1 )) && return 1
    typeset filename="$1"
    _Dbg_set_source_array_var "$filename"
    if [[ -z "$fullname" ]] ; then
	_Dbg_readin "$filename"
	typeset rc=$?
	set +xv
	(( $? != 0 )) && return $rc
	[[ -z "$fullname" ]] && return 1
	_Dbg_set_source_array_var "$filename" || return $?
    fi
    return 0
}

# Set _Dbg_source_array_var to the variable that contains file lines
# for $1. Variable "fullname" will contain the expanded full filename for $1.
# 0 is returned if everything went ok.
_Dbg_set_source_array_var() {
    (( $# != 1 )) && return 1
    typeset filename="$1"
    [[ -z "$filename" ]] && return 2
    fullname="${_Dbg_file2canonic["$filename"]}"
    [[ -z "$fullname" ]] && [[ -n "${_Dbg_filenames["$filename"]}" ]] && {
	fullname="$filename"
    }
    [[ -z "$fullname" ]] && return 2
    _Dbg_source_array_var=${_Dbg_filenames["$fullname"]}
    if [[ -n $_Dbg_set_highlight ]] ; then
	_Dbg_highlight_array_var="${_Dbg_source_array_var/_Dbg_source_/_Dbg_highlight_}"
    fi
    _Dbg_source_array_var=${_Dbg_filenames["$fullname"]}
    [[ -z $_Dbg_source_array_var ]] && return 2
    return 0
}
