# git-clone-if-newer
Script to clone and softlink a git repo... _if needed_.

NOTE: This repo has been "promoted" from a gist. Documentation is still very poor and the idea is to improve it little by little.

## Steps taken by the script

1. Checks that the provided repo is valid (SSH or HTTP)

2. Compares local and remote commit to see if there is a new version

3. Clones the remote commit in local, adding `-<timestamp>-<commit>` to the folder name

4. Deletes `.git` directory of the cloned repo

5. Runs script `<repo name>-after-update.sh`, with two arguments:

  - `<repo name>`
  - `<repo name>-<timestamp>-<commit>`
  
     and fails if:
     - script is not present
     - `.ok-<repo name>` is present _before_ running script
     - script exits with non-zero code
     - `.ok-<repo name>` is not present _after_ running script

6. Softlinks `<repo name>` to `<repo name>-<timestamp>-<commit>`

7. Deletes old versions

## Installation
  
```
git clone https://gist.github.com/cc88af3c9c4f8664216ea07bd08c250f.git _gcin
command cp -f _gcin/git-clone-if-newer.sh . && rm -rf _gcin && chmod +x git-clone-if-newer.sh
```

## Usage

```
./git-clone-if-newer.sh [options] <git repo url> [<local folder>]
```

Where:

 - git repo url has the SSH or HTTP format, e.g.:
   - `git@github.com:gto76/linux-cheatsheet.git`
   - `https://github.com/gto76/linux-cheatsheet.git`
 - local folder: optional destination folder. Default: repo name extracted from [git repo url]

Options:
 - `-b <branch>`: name of branch to clone. Default: `master`
 - `-o <number>`: number of old versions to keep. Default: `3`
 - `-k`: switch to keep the cloned .git folder.

## To do

- [ ] Fix bug with option `-o` and `$SOFTLINK`
- [ ] Change step 5 of the process
  - [ ] Add option to run custom script before softlinkg
  - [ ] If present, take a return code of 0 as success and proceed to softlinking, anything else as failure
  - [ ] Still pass the same two arguments to the custom script
  - [ ] Remove everything about `<repo name>-after-update.sh` and `.ok-<repo name>`
