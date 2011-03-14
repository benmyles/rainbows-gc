# based on examples/streaming.rb in git://github.com/lifo/cramp
# commit ca54f8a944ae582a0c858209daf3c74efea7d27c

# Rack::Lint does not like async + EM stuff, so disable it:
#\ -E deployment

require 'cramp'

class StreamController < Cramp::Action
  periodic_timer :send_data, :every => 1
  periodic_timer :check_limit, :every => 2

  def start
    @limit = 0
  end

  def send_data
    render ["Hello World", "\n"]
  end

  def check_limit
    @limit += 1
    finish if @limit > 1
  end

end

run StreamController
