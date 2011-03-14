# -*- encoding: binary -*-
Rainbows.const_set(:RevFiberSpawn, Rainbows::CoolioFiberSpawn)

# CoolioFiberSpawn is the new version of this, use that instead.
#
# A combination of the Rev and FiberSpawn models.  This allows Ruby
# 1.9 Fiber-based concurrency for application processing while
# exposing a synchronous execution model and using scalable network
# concurrency provided by Rev.  A streaming "rack.input" is exposed.
# Applications are strongly advised to wrap all slow IO objects
# (sockets, pipes) using the Rainbows::Fiber::IO or a Rev-compatible
# class whenever possible.
module Rainbows::RevFiberSpawn; end
