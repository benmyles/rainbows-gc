# -*- encoding: binary -*-
# :enddoc:
module Rainbows::NeverBlock::Core
  def init_worker_process(worker)
    super
    o = Rainbows::O
    pool = NB::Pool::FiberPool.new(o[:pool_size])
    base = o[:backend].to_s.gsub!(/([a-z])([A-Z])/, '\1_\2').downcase!
    require "rainbows/never_block/#{base}"
    client_class = Rainbows::NeverBlock::Client
    client_class.superclass.const_set(:APP, Rainbows.server.app)
    client_class.const_set(:POOL, pool)
    logger.info "NeverBlock/#{o[:backend]} pool_size=#{o[:pool_size]}"
  end
end
