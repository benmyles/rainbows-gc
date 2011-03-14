# -*- encoding: binary -*-
# :enddoc:
class Rainbows::NeverBlock::Client < Rainbows::EventMachine::Client
  def app_call input
    POOL.spawn do
      begin
        super input
      rescue => e
        handle_error(e)
      end
    end
  end
end
