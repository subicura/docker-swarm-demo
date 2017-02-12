require 'sinatra'
require 'redis'
require 'socket'

redis = Redis.new(:host => ENV['REDIS_HOST'])

get '/' do
  hostname = Socket.gethostname
  count = redis.incr hostname

  redis.keys('*').map do |k|
    "#{k} > #{redis.get(k)}"
  end.join("\n")
end
