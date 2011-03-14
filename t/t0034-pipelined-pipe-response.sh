#!/bin/sh
. ./test-lib.sh

t_plan 6 "pipelined pipe response for $model"

t_begin "setup and startup" && {
	rtmpfiles err out dd_fifo
	rainbows_setup $model

	# can't load Rack::Lint here since it clobbers body#to_path
	rainbows -E none -D fast-pipe-response.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "read random blob sha1" && {
	random_blob_sha1=$(rsha1 < random_blob)
}

script='
require "digest/sha1"
require "kcar"
$stdin.binmode
expect = ENV["random_blob_sha1"]
kcar = Kcar::Response.new($stdin, {})
3.times do |i|
	nr = 0
	status, headers, body = kcar.rack
	dig = Digest::SHA1.new
	body.each { |buf| dig << buf ; nr += buf.size }
	sha1 = dig.hexdigest
	warn "[#{i}] nr: #{nr}"
	sha1 == expect or abort "mismatch: sha1=#{sha1} != expect=#{expect}"
	body.close
end
$stdout.syswrite("ok\n")
'

t_begin "staggered pipeline of 3 HTTP requests" && {
	req='GET /random_blob HTTP/1.1\r\nHost: example.com\r\n'
	rm -f $ok
	(
		export random_blob_sha1
		$RUBY -e "$script" < $fifo >> $ok &
		printf "$req"'X-Req:0\r\n\r\n'
		exec 6>&1
		(
			dd bs=16384 count=1
			printf "$req" >&6
			dd bs=16384 count=1
			printf 'X-Req:1\r\n\r\n' >&6
			dd bs=16384 count=1
			printf "$req" >&6
			dd bs=16384 count=1
			printf 'X-Req:2\r\n' >&6
			dd bs=16384 count=1
			printf 'Connection: close\r\n\r' >&6
			dd bs=16384 count=1
			printf '\n' >&6
			cat
		) < $dd_fifo > $fifo &
		wait
		echo ok >> $ok
	) | socat - TCP:$listen > $dd_fifo
	test 2 -eq $(grep '^ok$' $ok |wc -l)
}

t_begin "pipeline 3 HTTP requests" && {
	rm -f $ok
	req='GET /random_blob HTTP/1.1\r\nHost: example.com\r\n'
	req="$req"'\r\n'"$req"'\r\n'"$req"
	req="$req"'Connection: close\r\n\r\n'
	(
		export random_blob_sha1
		$RUBY -e "$script" < $fifo >> $ok &
		printf "$req"
		wait
		echo ok >> $ok
	) | socat - TCP:$listen > $fifo
	test 2 -eq $(grep '^ok$' $ok |wc -l)
}

t_begin "shutdown server" && {
	kill -QUIT $rainbows_pid
}

t_begin "check stderr" && check_stderr

t_done
