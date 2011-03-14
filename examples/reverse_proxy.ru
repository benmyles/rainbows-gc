# see Rainbows::ReverseProxy RDoc
cfg = {
  :upstreams => [
    "/tmp/.r.sock",
    "http://bogomips.org/",
    [ "http://10.6.6.6:666/", { :weight => 666 } ],
  ]
}
run Rainbows::ReverseProxy.new(cfg)
