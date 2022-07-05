#!/bin/bash
set -u
IFS=$'\n\t'

# Clones and softlinks a git repo, _if needed_.
# for usage, just run and see output:
# ./git-clone-if-newer.sh

############################################################################
# defaults
############################################################################

DEFAULT_GIT_BRANCH=master
DEFAULT_KEEP_GIT_DIR=0
DEFAULT_KEEP_OLD_VERSIONS=3
DEFAULT_DEST_DIR=""
DEFAULT_PRE_SCRIPT=""
DEFAULT_SOFTLINK=1

############################################################################
# usage and read arguments
############################################################################

function usage () {
    __USAGE="Usage: $(basename $0) [options] <git repo url> [<local folder>]

Where:
    <git repo url> has the SSH or HTTP format, e.g.:
        - git@github.com:gto76/linux-cheatsheet.git
        - https://github.com/gto76/linux-cheatsheet.git
    <local folder>: optional destination folder. Default: repo name extracted from <git repo url>

Options:
    -b <branch>: name of branch to clone. Default: $DEFAULT_GIT_BRANCH
    -o <number>: number of old versions to keep. Default: $DEFAULT_KEEP_OLD_VERSIONS
    -s <script>: run script after cloning and before softlinking.
    -k: switch to keep the cloned .git folder.
"

    if [[ $# -gt 0 ]]; then
        echo "Error: $1" >&2
        echo "" >&2
    fi
    echo "$__USAGE" >&2
    exit 1;
}

GIT_BRANCH=$DEFAULT_GIT_BRANCH
KEEP_GIT_DIR=$DEFAULT_KEEP_GIT_DIR
KEEP_OLD_VERSIONS=$DEFAULT_KEEP_OLD_VERSIONS
DEST_DIR=$DEFAULT_DEST_DIR
PRE_SCRIPT=$DEFAULT_PRE_SCRIPT
SOFTLINK=$DEFAULT_SOFTLINK

while getopts ":b:o:s:k" VARNAME; do
    case $VARNAME in
        b)
            GIT_BRANCH="$OPTARG"
            ;;
        o)
            re='^[1-9][0-9]*$'
            if ! [[ $OPTARG =~ $re ]] ; then
                if [ ! $OPTARG == "0" ] ; then
                    usage "<old versions to keep> is not a positive integer number"
                fi
            fi
            KEEP_OLD_VERSIONS="$OPTARG"
            ;;
        s)
            PRE_SCRIPT="$OPTARG"
            ;;
        k)
            KEEP_GIT_DIR=1
            ;;
        \?)
            usage "Invalid option -$OPTARG"
            ;;
        :)
            usage "Option -$VARNAME requires a parameter."
            ;;
    esac
done

# remove all options from the argument list
shift $((OPTIND - 1))

if [ $# -lt 1 ]; then
    usage "Missing argument <git repo url>"
fi

GIT_FULL_REPO="$1"
shift

if [ $# -gt 0 ]; then
    DEST_DIR="$1"
    shift
fi

if [ $# -gt 0 ]; then
    usage "Too many arguments"
fi

# expected variables now:
# - GIT_FULL_REPO -> string
# - GIT_BRANCH -> string
# - KEEP_GIT_DIR -> 0 or 1
# - KEEP_OLD_VERSIONS -> integer >= 0
# - DEST_DIR -> string, "" for repo_name

############################################################################
# functions
############################################################################

BASE_DIR=`pwd`

function error () {
    echo "" >&2
    echo "Error: $1" >&2
    cd $BASE_DIR
    exit $2
}

function error_and_clean () {
    echo "" >&2
    echo "Error: $1" >&2
    echo "Cleaning up and exiting..."
    cd $BASE_DIR
    rm -rf $LOCAL_DIR
    exit $2
}

############################################################################
# 1. check and parse repo
############################################################################

REGEX_SITE="[A-Za-z0-9_\\-\\.]+"
REGEX_USER="[A-Za-z0-9_\\-]+"
REGEX_REPO="[A-Za-z0-9_\\-]+"

REGEX_FULL_SSH="^git@($REGEX_SITE):($REGEX_USER)\\/($REGEX_REPO)\\.git$"

REGEX_FULL_HTTP="^https:\\/\\/($REGEX_SITE)\\/($REGEX_USER)\\/($REGEX_REPO)\\.git$"

if [[ $GIT_FULL_REPO =~ $REGEX_FULL_SSH ]]; then
    GIT_SERVER=${BASH_REMATCH[1]}
    GIT_USER=${BASH_REMATCH[2]}
    GIT_REPO=${BASH_REMATCH[3]}
else
    if [[ $GIT_FULL_REPO =~ $REGEX_FULL_HTTP ]]; then
        GIT_SERVER=${BASH_REMATCH[1]}
        GIT_USER=${BASH_REMATCH[2]}
        GIT_REPO=${BASH_REMATCH[3]}
    else
        usage "The repository is not valid."
    fi
fi

#echo $GIT_SERVER $GIT_USER $GIT_REPO

if [ "$DEST_DIR" == "$DEFAULT_DEST_DIR" ]; then
    DEST_DIR="$GIT_REPO"
fi

############################################################################
# summary
############################################################################

echo "Repository:           $GIT_FULL_REPO"
echo "Branch:               $GIT_BRANCH"
echo "Destination:          $DEST_DIR"
echo "Keep .git directory:  $KEEP_GIT_DIR"
echo "Create softlink:      $SOFTLINK"
echo "Old versions to keep: $KEEP_OLD_VERSIONS"

############################################################################
# 2. compare local and remote commits
############################################################################

echo ""

COMMIT_ID_LOCAL=`ls -d $DEST_DIR-*/ 2> /dev/null | tail -n 1 | rev | cut -d'-' -f1 | rev | sed -e 's/\/$//'`
if [[ $COMMIT_ID_LOCAL != "" ]]; then
    echo "Last local commit id:  $COMMIT_ID_LOCAL"
else
    echo "No local clones found."
fi

COMMIT_ID_REMOTE=`git ls-remote $GIT_FULL_REPO refs/heads/$GIT_BRANCH | cut -c-8`
echo "Last remote commit id: $COMMIT_ID_REMOTE"

if [ "$COMMIT_ID_LOCAL" == "$COMMIT_ID_REMOTE" ]; then
    echo "No new commit to clone. Exiting."
    exit
fi

############################################################################
# 3. clone!
############################################################################

which git > /dev/null 2> /dev/null

RETCODE=$?
if [ ! $RETCODE -eq 0 ]; then
    error "Git is not present. You have to install it." 30
fi

LOCAL_TIME=$(date +%Y%m%d_%H%M%S)
LOCAL_DIR="$DEST_DIR-$LOCAL_TIME-$COMMIT_ID_REMOTE"

echo ""
echo "Cloning $GIT_FULL_REPO ..."
git clone --depth 1 -b $GIT_BRANCH $GIT_FULL_REPO $LOCAL_DIR

RETCODE=$?
if [ ! $RETCODE -eq 0 ]; then
    error_and_clean "git clone failed." 31
fi

echo "Cloned."

############################################################################
# check that the commit matches the expected one
############################################################################

echo ""

cd $LOCAL_DIR
GIT_COMMIT=$(git log --format="%H" -n 1 | cut -c-8)
cd ..

echo "Local cloned commit: $GIT_COMMIT"
if [ -z $GIT_COMMIT ]; then
    error_and_clean "Could not get commit id of cloned repo" 32
fi

if [ ! "$COMMIT_ID_REMOTE" == "$GIT_COMMIT" ]; then
    echo "Looks like there was a commit between reading the remote repo and cloning!"
    echo "Fear not. Renaming directory..."
    NEW_DIR="$DEST_DIR-$LOCAL_TIME-$GIT_COMMIT"
    mv $LOCAL_DIR $NEW_DIR
    LOCAL_DIR="$NEW_DIR"
    echo "Done. Next!"
else
    echo "As expected."
fi

############################################################################
# 4. delete .git dir
############################################################################

if [ $KEEP_GIT_DIR -eq 0 ]; then
    echo ""
    echo "Deleting cloned .git dir..."
    cd $LOCAL_DIR
    rm -rf .git
    cd ..
    echo "Deleted."
fi

############################################################################
# 5. YOUR SCRIPT IS RUN HERE
############################################################################

if [ ! -z $PRE_SCRIPT ]; then
    if [ ! -f $PRE_SCRIPT ]; then
        error_and_clean "Script $PRE_SCRIPT does not exist." 50
    elif [ ! -x $PRE_SCRIPT ]; then
        error_and_clean "Script $PRE_SCRIPT is not executable." 51
    fi

    echo ""
    echo "Running script $PRE_SCRIPT ..."

    sh -c "`realpath $PRE_SCRIPT` $DEST_DIR $LOCAL_DIR"

    RETCODE=$?
    if [ ! $RETCODE -eq 0 ]; then
        error_and_clean "Script returned non-zero code ($RETCODE)." 53
    fi

    cd $BASE_DIR
fi


############################################################################
# 6. softlink
############################################################################

if [ $SOFTLINK -eq 1 ]; then
    echo ""
    echo "Softlinking $DEST_DIR to $LOCAL_DIR ..."
    if [ -h $DEST_DIR ]; then
        unlink $DEST_DIR
    fi
    ln -sf $LOCAL_DIR $DEST_DIR

    RETCODE=$?
    if [ ! $RETCODE -eq 0 ]; then
        error_and_clean "Could not create the link." 60
    else
        echo "Linked."
    fi
fi

############################################################################
# 7. delete old versions
############################################################################

if [ `ls -d $DEST_DIR-*/ 2> /dev/null | wc -l` -gt $(($KEEP_OLD_VERSIONS + 1)) ]; then
    echo ""
    echo "Deleting old folders..."
    while [ `ls -d $DEST_DIR-*/ 2> /dev/null | wc -l` -gt $(($KEEP_OLD_VERSIONS + 1)) ]; do
        OLDEST_DIR=`ls -d $DEST_DIR-*/ 2> /dev/null | head -n 1`
        echo " - $OLDEST_DIR ..."
        rm -rf $OLDEST_DIR
    done
fi

############################################################################
# oki doki!
############################################################################

echo ""
echo "Finished!"
