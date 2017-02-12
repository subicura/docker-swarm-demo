require 'sinatra'
require 'socket'

get '/' do
  File.read(ENV['SECRET_PATH'])
end

