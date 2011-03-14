#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"
req_curl_chunked_upload_err_check

t_plan 18 "rack.input client_max_body_size tiny"

t_begin "setup and startup" && {
	rtmpfiles curl_out curl_err
	rainbows_setup $model
	ed -s $unicorn_config <<EOF
,s/client_max_body_size.*/client_max_body_size 256/
w
EOF
	rainbows -D sha1-random-size.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "stops a regular request" && {
	rm -f $ok
	dd if=/dev/zero bs=257 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "stops a large chunked request" && {
	rm -f $ok
	dd if=/dev/zero bs=257 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "small size sha1 chunked ok" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "small size sha1 content-length ok" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "stops a regular request (gets_read_mix)" && {
	rm -f $ok
	dd if=/dev/zero bs=257 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/gets_read_mix > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "stops a large chunked request (gets_read_mix)" && {
	rm -f $ok
	dd if=/dev/zero bs=257 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/gets_read_mix > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "stops a large line-based chunked request (gets_read_mix)" && {
	rm -f $ok
	</dev/null awk 'BEGIN{for(i=22;--i>=0;) print "hello world"}' | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/gets_read_mix > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "OK with line-based chunked request (gets_read_mix)" && {
	rm -f $ok
	</dev/null awk 'BEGIN{for(i=21;--i>=0;) print "hello world"}' | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/gets_read_mix > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test x"$(cat $curl_out)" = x23eab3cebcbe22a0456c8462e3d3bb01ae761702
}

t_begin "small size sha1 chunked ok (gets_read_mix)" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/gets_read_mix > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "small size sha1 content-length ok (gets_read_mix)" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/gets_read_mix > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "stops a regular request (each)" && {
	rm -f $ok
	dd if=/dev/zero bs=257 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/each > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "stops a large chunked request (each)" && {
	rm -f $ok
	dd if=/dev/zero bs=257 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/each > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "small size sha1 chunked ok (each)" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/each > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "small size sha1 content-length ok (each)" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/each > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "stops a large line-based chunked request (each)" && {
	rm -f $ok
	</dev/null awk 'BEGIN{for(i=22;--i>=0;) print "hello world"}' | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/each > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	grep 413 $curl_err
	test -e $ok
}

t_begin "OK with line-based chunked request (each)" && {
	rm -f $ok
	</dev/null awk 'BEGIN{for(i=21;--i>=0;) print "hello world"}' | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/each > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test x"$(cat $curl_out)" = x23eab3cebcbe22a0456c8462e3d3bb01ae761702
}

t_begin "shutdown" && {
	kill $rainbows_pid
}

t_done
