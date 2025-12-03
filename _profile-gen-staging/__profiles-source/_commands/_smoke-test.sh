
bash -n ~/.bashrc.generated && echo "Syntax OK"
source ~/.bashrc.generated
declare -p PS1
echo "$AMP_DEV_PROJECT"
type -a python; python --version
type amp; amp && pwd


response 2025/10/03

Syntax OK
declare -- PS1="\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\\$ "
/mnt/e/users/gigster/workspace/dev/repos/amp.dev
python is /home/gig/.pyenv/shims/python
Python 3.9.18
amp is aliased to `cd $AMP_DEV_PROJECT'
-bash: cd: /mnt/e/users/gigster/workspace/dev/repos/amp.dev: No such file or directory