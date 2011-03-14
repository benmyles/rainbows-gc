# -*- encoding -*-
# :enddoc:
module Rainbows::ReverseProxy::MultiThread
  def pick_upstream(env)
    @lock.synchronize { super(env) }
  end
end
