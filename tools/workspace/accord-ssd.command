#!/bin/zsh
set -eu

launcher_dir=${0:A:h}
workspace=${launcher_dir:h:h:h}

case "${1:-root}" in
  root) work_dir="$workspace" ;;
  v2)   work_dir="$workspace/accord_mobile_v2" ;;
  erp)  work_dir="$workspace/mini_rs_erp" ;;
  -h|--help)
    print 'accord-ssd [root|v2|erp] [buyruq ...]'
    exit 0 ;;
  *)
    print -u2 'Foydalanish: accord-ssd [root|v2|erp] [buyruq ...]'
    exit 2 ;;
esac
if (( $# )); then shift; fi
cd -- "$work_dir"
source "$launcher_dir/environment.zsh" "$workspace"

if (( $# )); then
  exec "$@"
fi
print -r -- "Accord SSD · $PWD"
exec /bin/zsh -i
