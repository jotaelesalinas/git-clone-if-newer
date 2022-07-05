# git-clone-if-newer
Script to clone and softlink a git repo... _if needed_.

NOTE: This repo has been "promoted" from a gist. Documentation is still very poor and the idea is to improve it little by little.

## Installation
  
```bash
git clone --depth 1 https://github.com/jotaelesalinas/git-clone-if-newer.git _gcin
command cp -f _gcin/git-clone-if-newer.sh .
rm -rf _gcin
chmod +x git-clone-if-newer.sh
```

## Usage

```
./git-clone-if-newer.sh [options] <git repo url> [<local folder>]
```

Where:

 - `git repo url` has the SSH or HTTP format, e.g.:
   - `git@github.com:gto76/linux-cheatsheet.git`
   - `https://github.com/gto76/linux-cheatsheet.git`
 - `local folder`: optional destination folder. Default: repo name extracted from [git repo url]

Options:
 - `-b <branch>`: name of branch to clone. Default: `master`
 - `-o <number>`: number of old versions to keep. Default: `3`
 - `-s <script>`: run script after cloning and before softlinking.
 - `-k`: switch to keep the cloned .git folder.

## Steps taken by the script

1. Checks that the provided repo is valid (SSH or HTTP).

2. Compares local and remote commit to see if there is a new version.

3. Clones the remote commit in local, adding `-<timestamp>-<commit>` to the folder name.

4. Deletes `.git` directory of the cloned repo.

5. If present, runs script specified by option `-s`, with two arguments:

    - `<local folder>`
    - `<local folder>-<timestamp>-<commit>`

    If the script returns a value different than `0`, the recently cloned repo is deleted and the program exits.

6. Softlinks `<local folder>` to `<local folder>-<timestamp>-<commit>`.

7. Deletes old versions.
