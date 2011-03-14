nr_client=${nr_client-4}
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"

# basically we don't trust our own implementation of content-md5-put
# nor our Ruby 1.9 knowledge nor proper use of encodings in Ruby.
# So we try to use things like curl and sha1sum that are implemented
# without the Ruby interpreter to validate our own Ruby internals.

t_plan 7 "concurrent rack.input hammer stress test (content-length)"

t_begin "setup and startup" && {
	rtmpfiles curl_out curl_err
	rainbows_setup $model
	rainbows -D sha1.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "send $nr_client concurrent requests" && {
	start=$(date +%s)
	for i in $(awk "BEGIN{for(i=0;i<$nr_client;++i) print i}" </dev/null)
	do
		(
			curl -sSf -T random_blob http://$listen/$i \
			  >> $curl_out 2>> $curl_err
		) &
	done
	wait
	t_info elapsed=$(( $(date +%s) - $start ))
}

t_begin "kill server" && kill $rainbows_pid

t_begin "got $nr_client responses" && {
	test $nr_client -eq $(wc -l < $curl_out)
}

t_begin "all responses identical" && {
	test 1 -eq $(sort < $curl_out | uniq | wc -l)
}

t_begin "sha1 matches on-disk sha1" && {
	blob_sha1=$(rsha1 < random_blob)
	t_info blob_sha1=$blob_sha1
	test x"$blob_sha1" = x"$(sort < $curl_out | uniq)"
}

t_begin "no errors in stderr log" && check_stderr

t_done
