#!/usr/bin/env bash


## DocPatch -- patching documents that matter
## Copyright (C) 2012-18 Benjamin Heisig <https://benjamin.heisig.name/>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.


##
## Create script
##

## About this command:
: "${COMMAND_DESC:="$COMMAND_CREATE"}"

## 'pdf' is one more supported output format:
SUPPORTED_FORMATS="pdf"

## Checks whether everything is prepared before creating output.
function checks {
  loginfo "Checking whether everything is prepared before creating output..."

  logdebug "Checking output directory..."
  if [ ! -d "$OUTPUT_DIR" ]; then
      logdebug "Output directory not found. Create it."
      exe "$MKDIR -p $OUTPUT_DIR"
      if [ "$?" -gt 0 ]; then
          logwarning "Cannot create output directory under '${OUTPUT_DIR}'."
          logerror "Checks failed."
          return 1
        fi
      logdebug "Output directory created under '${OUTPUT_DIR}'."
    else
      logdebug "Output directory found under '${OUTPUT_DIR}'."
    fi

  logdebug "Verifying output format..."
  local found=0
  for format in $SUPPORTED_FORMATS; do
      if [ "$OUTPUT_FORMAT" == "$format" ]; then
          found=1
          break
        fi
    done
  if [ "$found" -eq 0 ]; then
      logwarning "Output format '${OUTPUT_FORMAT}' is not supported."
      logerror "Checks failed."
      return 1
    fi
  logdebug "Output format '${OUTPUT_FORMAT}' verified."

  logdebug "Checks succeded."
  return 0
}


## Fetches supported output formats:
function fetchSupportedOutputFormats {
  loginfo "Fetching supported output formats..."

  logdebug "Parsing formats..."
  while read supported_format; do
      if [ -n "$SUPPORTED_FORMATS" ]; then
          SUPPORTED_FORMATS="$SUPPORTED_FORMATS "
        fi
      SUPPORTED_FORMATS="${SUPPORTED_FORMATS}$supported_format"
      logdebug "Appended output format '${supported_format}' to list."
    done < <(cat "$OUTPUT_FORMAT_FILE" | grep -v '^#' | grep -v '^$' | awk '{print $1}')

  logdebug "Fetched supported output formats from file '${OUTPUT_FORMAT_FILE}'."
  return 0
}


## Loads meta information
function loadMetaInformation {
  loginfo "Loading meta information..."

  if [ ! -r "$DOCPATCH_CONF_TARGET" ]; then
      logwarning "Cannot access meta information under '${DOCPATCH_CONF_TARGET}'."
      logerror "Failed to load meta information."
      return 1
    fi
  logdebug "Meta information found under '${DOCPATCH_CONF_TARGET}'."

  logdebug "Including file..."
  source "$DOCPATCH_CONF_TARGET"
  logdebug "File included."

  logdebug "Meta information loaded."
  return 0
}


## Determines Repository
function determineRepository {
  loginfo "Determining repository..."

  logdebug "Checking argument..."
  if [ -z "$REPOSITORY" ]; then
      logdebug "Argument not set. Use default repository under '${REPO_DIR}'."

      logdebug "Checking for existing repository..."
      if [ ! -d "${REPO_DIR}/.git/" ]; then
          lognotice "There is no repository under '${REPO_DIR}'."
          logwarning "Cannot use default repository."
          logerror "Failed to determine repository."
          return 1
        fi
      logdebug "Repository found under '${REPO_DIR}'."
    else
      logdebug "Cloning repository '${REPOSITORY}'..."

      logdebug "Checking for existing repository..."
      if [ -d "${REPO_DIR}/.git/" ]; then
          lognotice "Repository found under '${REPO_DIR}'."
          logwarning "Cannot clone repository '${REPOSITORY}'."
          logerror "Failed to determine repository."
          return 1
        fi
      logdebug "There is no repository under '${REPO_DIR}'."

      logdebug "Creating empty directory..."
      exe "$RM -rf $REPO_DIR"
      exe "$MKDIR -p $REPO_DIR"
      logdebug "Empty directory under '${REPO_DIR}' created."

      logdebug "Cloning repository from '${REPOSITORY}'..."
      exe "$GIT clone $REPOSITORY $REPO_DIR"
      if [ "$?" -gt 0 ]; then
          logwarning "Cannot clone repository '${REPOSITORY}' under '${REPO_DIR}'."
          logerror "Failed to determine repository."
          return 1
        fi
      logdebug "Repository cloned under '${REPO_DIR}'."
    fi

  logdebug "Repository determined."
  return 0
}


## Counts revisions.
function countRevisions {
  loginfo "Counting revisions..."

  cd "$REPO_DIR" || return 1
  REVISIONS=`"$GIT" tag -l | "$WC" -l`
  if [ "$?" -gt 0 ]; then
      logerror "Cannot count revisions."
      return 1
    fi
  if [ "$REVISIONS" -eq 1 ]; then
      logdebug "There is 1 revision."
    else
      logdebug "There are $REVISIONS revisions."
    fi

  logdebug "Revisions counted."
  return 0
}


## Determines which revisions are meant.
function determineRevisions {
  loginfo "Determining revisions..."

  logdebug "Parsing argument for revisions..."
  if [ -z "$ARG_REVISION" ]; then
      logdebug "No specific revision given. Assuming first revision."
      LIST_OF_REVISIONS=0
    elif [ "$ARG_REVISION" == "first" ]; then
      logdebug "It's the first revision."
      LIST_OF_REVISIONS=0
    elif [ "$ARG_REVISION" == "last" ]; then
      logdebug "It's the last revision."
      LIST_OF_REVISIONS=$(($REVISIONS - 1))
    elif [ "$ARG_REVISION" == "all" ]; then
      logdebug "All revisions selected."

      for (( rev=0; rev < "$REVISIONS"; rev++ )); do
          if [ "$rev" -lt 0 ]; then
              logwarning "Inproperly named revision '${rev}' found."
              logerror "Failed to determine revisions."
              return 1
            fi

          if [ -n "$LIST_OF_REVISIONS" ]; then
              LIST_OF_REVISIONS="$LIST_OF_REVISIONS "
            fi

          LIST_OF_REVISIONS="${LIST_OF_REVISIONS}$rev"
          logdebug "Appended revision '${rev}' to list."
        done
    elif [[ "$ARG_REVISION" == "${ARG_REVISION//[^0-9]/}" ]]; then
      if [ "$ARG_REVISION" -lt 0 ]; then
          logwarning "Inproperly named revision '${ARG_REVISION}' found."
          logerror "Failed to determine revisions."
          return 1
        fi
      logdebug "Revision '${ARG_REVISION}' is meant."
      LIST_OF_REVISIONS="$ARG_REVISION"
    else
      logdebug "Looking for more than one revision..."
      IFS=","
      for rev in $ARG_REVISION; do
          if [ "$rev" -lt 0 ]; then
              logwarning "Argument for one or more revisions is invalid."
              logerror "Failed to determine revisions."
              return 1
            fi

          if [ -n "$LIST_OF_REVISIONS" ]; then
              LIST_OF_REVISIONS="$LIST_OF_REVISIONS "
            fi
          LIST_OF_REVISIONS="${LIST_OF_REVISIONS}$rev"
          logdebug "Appended revision '${rev}' to list."
        done
      unset IFS
    fi
  logdebug "Found these revisions: $LIST_OF_REVISIONS"

  logdebug "Revisions determined."
  return 0
}


## Switches repository to a revision.
##   $1 Revision
function switchRevision {
  loginfo "Switching revision..."

  logdebug "Changing into directory '${REPO_DIR}'..."
  cd "$REPO_DIR" || return 1

  logdebug "Checking out revision '${1}'..."
  exe "$GIT checkout $1"
  if [ "$?" -gt 0 ]; then
      logwarning "Cannot checkout revision '${1}'."
      logerror "Failed to switch revision."
      return 1
    fi
  logdebug "Check out done."

  logdebug "Revision switched."
  return 0
}


## Creates output.
function createOutput {
  loginfo "Creating output..."

  logdebug "Iterating through each destinated revision..."
  for REVISION in $LIST_OF_REVISIONS; do
      logdebug "Handling revision '${REVISION}'..."

      switchRevision "$REVISION"
      if [ "$?" -gt 0 ]; then
          logwarning "Cannot handle revision '${REVISION}'."
          logerror "Failed to create output."
          return 1
        fi

      loadMetaInformation "$REVISION"
      if [ "$?" -gt 0 ]; then
          logwarning "Cannot handle revision '${REVISION}'."
          logerror "Failed to create output."
          return 1
        fi

      local status=0
      case "$OUTPUT_FORMAT" in
          "epub")
            produceEPUB
            local status="$?";;
          "man")
            produceManPage
            local status="$?";;
          "pdf")
            producePDF
            local status="$?";;
          *)
            produceGeneric "$OUTPUT_FORMAT"
            local status="$?";;
        esac
      if [ "$status" -gt 0 ]; then
          logwarning "Cannot handle revision '${REVISION}'."
          logerror "Failed to create output."
          return 1
        fi

      logdebug "Handling done."
    done
  logdebug "Iteration done."

  logdebug "Output created."
  return 0
}


## Produces a file (the generic way).
##   $1 Output format
function produceGeneric {
  local output_format="$1"
  local file_extension=""
  local standalone_support=""
  local arg_standalone=""
  local smart_support=""
  local arg_smart=""
  local toc_support=""
  local arg_toc=""
  local output_file=""

  loginfo "Producing '${output_format}'..."

  logdebug "Determining file extension..."
  file_extension=`"$CAT" "$OUTPUT_FORMAT_FILE" | "$GREP" "^$output_format" | "$HEAD" -n1 | "$AWK" '{print $2}'`
  logdebug "File extension is '${file_extension}'."

  logdebug "Determining whether standalone or embedded output will be created..."
  standalone_support=`"$CAT" "$OUTPUT_FORMAT_FILE" | "$GREP" "$output_format" | "$HEAD" -n1 | "$AWK" '{print $3}'`

  if [ "$EMBED" -eq 1 ] || [ "$standalone_support" == "-1" ]; then
      logdebug "Create embedded output."
  elif [ "$EMBED" -eq 0 ] && [ "$standalone_support" == "0" ]; then
      logdebug "Create embedded output."
    elif [ "$EMBED" -eq 0 ] || [ "$standalone_support" == "1" ]; then
      logdebug "Create standalone output."
      arg_standalone=" --standalone"
    fi

  logdebug "Determining whether to use smart option or not..."
  smart_support=`"$CAT" "$OUTPUT_FORMAT_FILE" | "$GREP" "$output_format" | "$HEAD" -n1 | "$AWK" '{print $4}'`

  if [ "$SIMPLE" -eq 1 ] || [ "$smart_support" == "-1" ]; then
      logdebug "Create simplified output."
    elif [ "$SIMPLE" -eq 0 ] && [ "$smart_support" == "0" ]; then
      logdebug "Create simplified output."
    elif [ "$SIMPLE" -eq 0 ] && [ "$smart_support" == "1" ]; then
      logdebug "Create smart output."
      arg_smart=" --smart"
    fi

  logdebug "Determining whether to add table of contents..."
  toc_support=`"$CAT" "$OUTPUT_FORMAT_FILE" | "$GREP" "$output_format" | "$HEAD" -n1 | "$AWK" '{print $5}'`

  if [ "$TOC" -eq 0 ] || [ "$toc_support" == "-1" ]; then
      logdebug "Do not add table of contents."
    else
      logdebug "Add table of contents."
      arg_toc=" --toc"
    fi

  output_file="${OUTPUT_DIR}/${IDENTIFIER}$file_extension"
  logdebug "Producing file..."
  exe "$PANDOC --from=$INPUT_FORMAT --to=${1}${arg_standalone}${arg_smart}${arg_toc} --output=$output_file `perl -e 'print join(" ", <'${REPO_DIR}/'*'$INPUT_FORMAT_EXT'>), "\n"'`"
  if [ "$?" -gt 0 ]; then
      logwarning "Cannot produce file '${output_file}'."
      logerror "Failed to produce '${output_format}'."
      return 1
    fi
  logdebug "Wrote content to file '${output_file}'."

  logdebug "Produced '${output_format}'."
  return 0
}


## Produces EPUB file.
## TODO Support epub tempplate files and cover image.
function produceEPUB {
    local meta_file="${TPL_DIR}/metadata.xml"
    local output_file="${OUTPUT_DIR}/${IDENTIFIER}.epub"
    local tocArg=""

  loginfo "Producing EPUB..."

  logdebug "Creating meta information..."
  logdebug "Cleaning up meta information..."
  exe "$RM -f $meta_file && touch $meta_file"
  if [ "$?" -gt 0 ]; then
      logwarning "Cannot clean up meta information under '${meta_file}'."
      logerror "Failed to produce EPUB."
      return 1
    fi
  logdebug "Cleaned up meta information."
  logdebug "Updating meta information..."
  if [ -n "$CONTRIBUTOR" ]; then
      loginfo "Contributor is: $CONTRIBUTOR"
      "$ECHO" "<dc:contributor>${CONTRIBUTOR}</dc:contributor>" > $meta_file
    fi
  if [ -n "$COVERAGE" ]; then
      loginfo "Coverage is: $COVERAGE"
      "$ECHO" "<dc:coverage>${COVERAGE}</dc:coverage>" > $meta_file
    fi
  if [ -n "$CREATOR" ]; then
      loginfo "Creator is: $CREATOR"
      "$ECHO" "<dc:creator>${CREATOR}</dc:creator>" > $meta_file
    fi
  if [ -n "$DATE" ]; then
      loginfo "Date is: $DATE"
      "$ECHO" "<dc:date>${DATE}</dc:date>" > $meta_file
    fi
  if [ -n "$DESCRIPTION" ]; then
      loginfo "Description is: $DESCRIPTION"
      "$ECHO" "<dc:description>${DESCRIPTION}</dc:description>" > $meta_file
    fi
  if [ -n "$FORMAT" ]; then
      loginfo "Format is: $FORMAT"
      "$ECHO" "<dc:format>${FORMAT}</dc:format>" > $meta_file
    fi
  if [ -n "$IDENTIFIER" ]; then
      loginfo "Identifier is: $IDENTIFIER"
      "$ECHO" "<dc:identifier>${IDENTIFIER}</dc:identifier>" > $meta_file
    fi
  if [ -n "$LANGUAGE" ]; then
      loginfo "Language is: $LANGUAGE"
      "$ECHO" "<dc:language>${LANGUAGE}</dc:language>" > $meta_file
    fi
  if [ -n "$PUBLISHER" ]; then
      loginfo "Publisher is: $PUBLISHER"
      "$ECHO" "<dc:publisher>${PUBLISHER}</dc:publisher>" > $meta_file
    fi
  if [ -n "$RELATION" ]; then
      loginfo "Relation is: $RELATION"
      "$ECHO" "<dc:relation>${RELATION}</dc:relation>" > $meta_file
    fi
  if [ -n "$RIGHTS" ]; then
      loginfo "Rights is: $RIGHTS"
      "$ECHO" "<dc:rights>${RIGHTS}</dc:rights>" > $meta_file
    fi
  if [ -n "$SOURCE" ]; then
      loginfo "Source is: $SOURCE"
      "$ECHO" "<dc:source>${SOURCE}</dc:source>" > $meta_file
    fi
  if [ -n "$SUBJECT" ]; then
      loginfo "Subject is: $SUBJECT"
      "$ECHO" "<dc:subject>${SUBJECT}</dc:subject>" > $meta_file
    fi
  if [ -n "$TITLE" ]; then
      loginfo "Title is: $TITLE"
      "$ECHO" "<dc:title>${TITLE}</dc:title>" > $meta_file
    fi
  if [ -n "$TYPE" ]; then
      loginfo "Type is: $TYPE"
      "$ECHO" "<dc:type>${TYPE}</dc:type>" > $meta_file
    fi
  logdebug "Updated meta information."
  logdebug "Produced meta information under '${meta_file}'."

  if [[ "$TOC" -eq 1 ]]; then
      logdebug "Add table of contents"
      tocArg="--toc"
  fi

  logdebug "Producing file..."
  exe "$PANDOC --from=$INPUT_FORMAT $tocArg --output=$output_file --smart --epub-metadata=$meta_file `perl -e 'print join(" ", <'${REPO_DIR}/'*'$INPUT_FORMAT_EXT'>), "\n"'`"
  if [ "$?" -gt 0 ]; then
      logwarning "Cannot produce file '${output_file}'."
      logerror "Failed to produce EPUB."
      return 1
    fi
  logdebug "Wrote content to file '${output_file}'."

  logdebug "EPUB produced."
  return 0
}


## Produces man page.
function produceManPage {
  loginfo "Producing man page..."

  logdebug "Checking for any template file..."
  local tpl_option=""
  local tpl_file="${TPL_DIR}/tpl.man"
  if [ -r "$tpl_file" ]; then
      logdebug "Template file found under '${tpl_file}'."
      local tpl_option="--template=$tpl_file"
    else
      logdebug "No template file found under '${tpl_file}'."
    fi

  local output_file="${OUTPUT_DIR}/${IDENTIFIER}.1.gz"
  logdebug "Producing file..."
  exe "$PANDOC --from=$INPUT_FORMAT --to=man --standalone $tpl_option `perl -e 'print join(" ", <'${REPO_DIR}/'*'$INPUT_FORMAT_EXT'>), "\n"'` | $GZIP -c > $output_file"
  if [ "$?" -gt 0 ]; then
      logwarning "Cannot produce file '${output_file}'."
      logerror "Failed to produce man page."
      return 1
    fi
  logdebug "Wrote content to file '${output_file}'."

  logdebug "Man page produced."
  return 0
}


## Produces PDF file.
function producePDF {
    local tocArg=""
    local tpl_file="${TPL_DIR}/tpl.tex"
    local tpl_option=""
    local output_file=""

  loginfo "Producing PDF..."

  logdebug "Checking for any template file..."

  if [ -r "$tpl_file" ]; then
      logdebug "Template file found under '${tpl_file}'."
      tpl_option="--template=$tpl_file --pdf-engine=xelatex -V lang=de -V papersize=a4 -V documentclass=scrartcl -V classoption=twoside"
    else
      logdebug "No template file found under '${tpl_file}'."
    fi

    if [[ "$TOC" -eq 1 ]]; then
        logdebug "Add table of contents"
        tocArg="--toc"
    fi

  output_file="${OUTPUT_DIR}/${IDENTIFIER}.pdf"
  logdebug "Producing file..."
  exe "$PANDOC --from=$INPUT_FORMAT $tocArg $tpl_option --output=$output_file `perl -e 'print join(" ", <'${REPO_DIR}/'*'$INPUT_FORMAT_EXT'>), "\n"'`"
  if [ "$?" -gt 0 ]; then
      logwarning "Cannot produce file '${output_file}'."
      logerror "Failed to produce PDF."
      return 1
    fi
  logdebug "Wrote content to file '${output_file}'."

  logdebug "PDF produced."
  return 0
}


## Main method
function main {
  fetchSupportedOutputFormats || abort 21

  checks || abort 22

  countRevisions || abort 23

  determineRepository || abort 24

  determineRevisions || abort 25

  createOutput || abort 26
}


## Prints command specific options.
function printCommandOptions {
  loginfo "Printing command specific options..."

  fetchSupportedOutputFormats || return 1

  local formats=""
  for format in $SUPPORTED_FORMATS; do
      if [ -n "$formats" ]; then
          formats="${formats}, "
        fi
      formats="${formats}'$format'"
    done

  prntLn "    -f, --format, --output FORMAT\tSelect output format FORMAT. Supported formats are ${formats}. Defaults to 'pdf'."
  prntLn "    -e, --embed, --embedded\t\tCreate an embedded version."
  prntLn "    -r, --rev, --revision REV\t\tGenerate output from revision REV. 'first', 'last', 'all' and a comma separated list of revisions are allowed. Defaults to 0."
  prntLn "    -R, --repo, --repository REPO\tSelect repository REPO which will be cloned. Defaults to existing repository under ${REPO_DIR}."
  prntLn "    -S, --simple, --not-smart\t\tDo not create a smart version."
  prntLn "    -t, --toc\t\t\t\tAdd table of contents (TOC)."

  logdebug "Options printed."
  return 0
}
