# git-clone-if-newer
Script to clone and softlink a git repo... _if needed_.

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
 - `local folder`: optional destination folder. Default: repo name extracted from `git repo url`

Options:
 - `-b <branch>`: name of branch to clone. Default: `master`
 - `-o <number>`: number of old versions to keep. Default: `3`
 - `-s <script>`: run script after cloning and before softlinking.
 - `-k`: switch to keep the cloned .git folder.

## Example

These are your initial folder contents:

```
./
├── build.sh
└── git-clone-if-newer.sh
```

`build.sh` contains a script that will initialize your tool (DB migration, docker builds, whatever).

First run:

```
./git-clone-if-newer.sh -s build.sh https://github.com/gto76/linux-cheatsheet.git my-repo
```

If everything goes ok, you will have the repo with timestamp and commit and a softlink to it,
with the name of the repo (or the selected local folder name):

```
./
├── build.sh
├── git-clone-if-newer.sh
├── my-repo -> my-repo-20220701_132334-d0c4d78a
└── my-repo-20220701_132334-d0c4d78a
    ├── .gitignore
    ├── README.md
    └── ...
```

If you run the same command and there is a new remote commit, the program will try to clone it. If anything goes wrong (there are *lots* of things that can go wrong, like no network, git server is down, script fails, drive is full...) the program will delete the newly cloned repository and leave the filesystem in the same state.

If you run a script and it fails, you have to make sure that the system does not end up in an inconsistent state.

Everytime you run the script, a new timestamped folder will be created, leaving the current one plus the ones specified by the option `-o`. With its default value, `3`, even after running the script tens of times, you will end up with the current + 3 old folders:

```
./
├── build.sh
├── git-clone-if-newer.sh
├── my-repo -> my-repo-20220916_130546-e1d5e89b
├── my-repo-20220831_162512-856dbd4e
│   └── ...
├── my-repo-20220905_091257-e745cac3
│   └── ...
├── my-repo-20220915_140434-cfb3c679
│   └── ...
└── my-repo-20220916_130546-e1d5e89b
    └── ...
```

## Custom script

The script that you specify with the option `-s` will be run after successfully cloning the repo.

Since the new repo is not already softlinked, and most probably you will need to do something inside it,
the script is passed two arguments:

1. Local folder, e.g. `my-repo`
2. Full local repo folder, e.g. `my-repo-20220916_130546-e1d5e89b`.

This way you will be able to run things like:

```
docker build -f $2/Dockerfile -t my-docker-image $2 || exit 1
```

or

```
cd $2
cp ../.env .env || exit 1
composer install || exit 2
php artisan migrate || exit 3
npm install || exit 4
npm run prod || exit 5
```

If the script exits with code `0`, the program continues execution.

Any other return code causes the program to delete the newly created repo folder and terminate.

## Steps taken by the script

1. Checks that the provided repo is valid (SSH or HTTP).

2. Compares local and remote commits to see if there is a new version.

3. Clones the remote commit in local, adding `-<timestamp>-<commit>` to the folder name.

4. Deletes `.git` directory.

5. Runs custom script.

6. Softlinks `<local folder>` to `<local folder>-<timestamp>-<commit>`.

7. Deletes old versions.

## To do

- [ ] Add option (`-f`?) to run script in case of failure.
