#!/bin/sh
nr=${nr-4}
. ./test-lib.sh

# ApacheBench (ab) is commonly installed in the sbin paths in Debian-based
# systems...
AB="$(which ab 2>/dev/null || :)"
if test -z "$AB"
then
	AB=$(PATH=/usr/local/sbin:/usr/sbin:$PATH which ab 2>/dev/null || :)
fi

if test -z "$AB"
then
	t_info "skipping $T since 'ab' could not be found"
	exit 0
fi

t_plan 4 "quiet spurious wakeups for $model"

t_begin "setup and start" && {
	rainbows_setup $model
	echo "preload_app true" >> $unicorn_config
	echo "worker_processes $nr" >> $unicorn_config
	rainbows -D env.ru -c $unicorn_config -E none
	rainbows_wait_start
}

t_begin "spam the server with requests" && {
	$AB -c1 -n100 http://$listen/
}

t_begin "killing succeeds" && {
	kill -QUIT $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
