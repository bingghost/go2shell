#!/bin/sh
# Creates directories with awkward names for manual / scripted launcher tests.
# Usage: Scripts/make-test-dirs.sh [base]   (default: ~/tmp/go2shell-test)
set -eu
BASE="${1:-$HOME/tmp/go2shell-test}"
mkdir -p "$BASE"
cd "$BASE"
mkdir -p -- "a b" "it's" '$HOME' '`whoami`' "中文 目录" "🚀rocket" "-dash" 'semi;colon & amp' 'quote"double'
mkdir -p "$(printf 'new\nline')"
ls -1b "$BASE"
