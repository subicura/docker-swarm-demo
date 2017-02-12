require 'sinatra'
require 'socket'

get '/' do
  "v2 - #{Socket.gethostname}"
end

