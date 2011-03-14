use Rack::ContentLength
run proc { |env|
  [ 200, { "Content-Type" => "text/plain" }, [ ENV["RACK_ENV"] ] ]
}
