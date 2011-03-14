#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"

t_plan 14 "ensure we're accounting worker_connections properly"
nr=2

t_begin "setup" && {
	rtmpfiles a b c d
	rainbows_setup $model $nr
	rainbows -D sha1.ru -c $unicorn_config
	rainbows_wait_start
}

null_sha1=da39a3ee5e6b4b0d3255bfef95601890afd80709

t_begin "fire off concurrent processes" && {

	req='POST / HTTP/1.1\r\n'
	req="$req"'Host: example.com\r\n'
	req="$req"'Transfer-Encoding: chunked\r\n\r\n'

	for i in a b c d
	do
		rtmpfiles ${i}_fifo ${i}_tmp
		eval 'i_fifo=$'${i}_fifo
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		(
			(
				cat $i_fifo > $i_tmp &
				# need a full HTTP request to get around
				# httpready
				printf "$req"
				sleep 5
				printf '0\r\n\r\n'
				wait
				echo ok > $i
			) | socat - TCP:$listen > $i_fifo
		) &
	done
	wait
}

t_begin "check results" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		test xok = x$(cat $i)
		test x$null_sha1 = x$(tail -1 $i_tmp)
	done
}

t_begin "repeat concurrent tests with faster clients" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		curl -sSf -T- </dev/null http://$listen/ > $i 2> $i_tmp &
	done
	wait
}

t_begin "check results" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		test ! -s $i_tmp
		test x$null_sha1 = x$(cat $i)
	done
}

t_begin "fire off truncated concurrent requests" && {

	req='POST / HTTP/1.1\r\n'
	req="$req"'Host: example.com\r\n'
	req="$req"'Transfer-Encoding: chunked\r\n'

	for i in a b c d
	do
		rtmpfiles ${i}_tmp
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		(
			(
				# need a full HTTP request to get around
				# httpready
				printf "$req"
				echo ok > $i
			) | socat - TCP:$listen > $i_tmp
		) &
	done
	wait
}

t_begin "check broken results" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		test xok = x$(cat $i)
		dbgcat i_tmp
	done
}

t_begin "repeat concurrent tests with faster clients" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		curl -sSf -T- </dev/null http://$listen/ > $i 2> $i_tmp &
	done
	wait
}

t_begin "check results" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		test ! -s $i_tmp
		test x$null_sha1 = x$(cat $i)
	done
}

t_begin "fire off garbage" && {
	for i in a b c d
	do
		rtmpfiles ${i}_fifo ${i}_tmp
		eval 'i_fifo=$'${i}_fifo
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		(
			(
				cat $i_fifo > $i_tmp &
				dd if=random_blob bs=4096 count=1
				wait
				echo ok > $i
			) | socat - TCP:$listen > $i_fifo
		) &
	done
	wait
}

t_begin "check broken results" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		test xok = x$(cat $i)
		grep -F 'HTTP/1.1 400 Bad Request' $i_tmp
	done
}

t_begin "repeat concurrent tests with faster clients" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		curl -sSf -T- </dev/null http://$listen/ > $i 2> $i_tmp &
	done
	wait
}

t_begin "check results" && {
	for i in a b c d
	do
		eval 'i_tmp=$'${i}_tmp
		eval "i=$"$i
		test ! -s $i_tmp
		test x$null_sha1 = x$(cat $i)
	done
}

t_begin "teardown" && {
	kill $rainbows_pid
}

t_done
