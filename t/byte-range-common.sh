t_begin "byte-range setup vars" && {
	random_blob_size=$(wc -c < random_blob)
	rb_1=$(( $random_blob_size - 1 ))
	range_head=-r-365
	range_tail=-r155-
	range_mid=-r200-300
	range_n1=-r0-$rb_1
	range_n2=-r0-$(($rb_1 - 1))
	range_1b_head=-r0-0
	range_1b_tail=-r$rb_1-$rb_1
	range_1b_mid=-r200-200
	range_all=-r0-$random_blob_size
	url=http://$listen/random_blob
}

check_content_range () {
	grep '^< HTTP/1\.1 206 Partial Content' $err
	grep 'Range:' $err
	# Content-Range: bytes #{offset}-#{offset+count-1}/#{clen}
	d='\([0-9]\+\)'
	start= end= size=
	eval $(< $err sed -n -e \
	  "s/^< Content-Range: bytes $d-$d\/$d"'.*$/start=\1 end=\2 size=\3/p')
	test -n "$start"
	test -n "$end"
	test -n "$size"

	# ensure we didn't screw up the sed invocation
	expect="< Content-Range: bytes $start-$end/$size"
	test x"$(grep -F "$expect" $err)" = x"$(grep '^< Content-Range:' $err)"

	test $start -le $end
	test $end -lt $size
}

t_begin "read random blob sha1s" && {
	sha1_head=$(curl -sSff $range_head file://random_blob | rsha1)
	sha1_tail=$(curl -sSff $range_tail file://random_blob | rsha1)
	sha1_mid=$(curl -sSff $range_mid file://random_blob | rsha1)
	sha1_n1=$(curl -sSff $range_n1 file://random_blob | rsha1)
	sha1_n2=$(curl -sSff $range_n2 file://random_blob | rsha1)
	sha1_1b_head=$(curl -sSff $range_1b_head file://random_blob | rsha1)
	sha1_1b_tail=$(curl -sSff $range_1b_tail file://random_blob | rsha1)
	sha1_1b_mid=$(curl -sSff $range_1b_mid file://random_blob | rsha1)
	sha1_all=$(rsha1 < random_blob)
	echo "$sha1_all=$sha1_n1"
}

t_begin "normal full request matches" && {
	sha1="$(curl -v 2>$err -sSf $url | rsha1)"
	test x"$sha1_all" = x"$sha1"
	grep 'Content-Range:' $err && die "Content-Range unexpected"
	grep 'HTTP/1.1 200 OK' $err || die "200 response expected"
}

t_begin "crazy offset goes over" && {
	range_insane=-r$(($random_blob_size * 2))-$(($random_blob_size * 4))
	curl -vsS 2>$err $range_insane $url >/dev/null
	grep '^< HTTP/1\.[01] 416 ' $err || die "expected 416 error"
	grep '^< Content-Range: bytes \*/'$random_blob_size $err || \
          die "expected Content-Range: bytes */SIZE"
}

t_begin "keepalive/pipelining is supported on 416 responses" && {
	rm -f $tmp
	(
		cat $fifo > $tmp &
		printf 'GET /byte-range-common.sh HTTP/1.1\r\n'
		printf 'Host: %s\r\n' $listen
		printf 'Range: bytes=9999999999-9999999999\r\n\r\n'
		printf 'GET /byte-range-common.sh HTTP/1.1\r\n'
		printf 'Host: %s\r\n' $listen
		printf 'Connection: close\r\n'
		printf 'Range: bytes=0-0\r\n\r\n'
		wait
	) | socat - TCP:$listen > $fifo

	< $tmp awk '
/^HTTP\/1\.1 / && NR == 1 && $2 == 416 { first = $2 }
/^HTTP\/1\.1 / && NR != 1 && $2 == 206 { second = $2 }
END { exit((first == 416 && second == 206) ? 0 : 1) }
	'
}

t_begin "full request matches with explicit ranges" && {
	sha1="$(curl -v 2>$err $range_all -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_all" = x"$sha1"

	sha1="$(curl -v 2>$err $range_n1 -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_all" = x"$sha1"

	range_over=-r0-$(($random_blob_size * 2))
	sha1="$(curl -v 2>$err $range_over -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_all" = x"$sha1"
}

t_begin "no fence post errors" && {
	sha1="$(curl -v 2>$err $range_n2 -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_n2" = x"$sha1"

	sha1="$(curl -v 2>$err $range_1b_head -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_1b_head" = x"$sha1"

	sha1="$(curl -v 2>$err $range_1b_tail -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_1b_tail" = x"$sha1"

	sha1="$(curl -v 2>$err $range_1b_mid -sSf $url | rsha1)"
	check_content_range
	test x"$sha1_1b_mid" = x"$sha1"
}

t_begin "head range matches" && {
	sha1="$(curl -sSfv 2>$err $range_head $url | rsha1)"
	check_content_range
	test x"$sha1_head" = x"$sha1"
}

t_begin "tail range matches" && {
	sha1="$(curl -sSfv 2>$err $range_tail $url | rsha1)"
	check_content_range
	test x"$sha1_tail" = x"$sha1"
}

t_begin "mid range matches" && {
	sha1="$(curl -sSfv 2>$err $range_mid $url | rsha1)"
	check_content_range
	test x"$sha1_mid" = x"$sha1"
}

t_begin "shutdown server" && {
	kill -QUIT $rainbows_pid
}

t_begin "check stderr" && check_stderr

t_done
