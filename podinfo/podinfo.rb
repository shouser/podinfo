require 'dotenv/load'
require 'json'
require 'redis'
require 'sinatra/base'
require 'sinatra/multi_route'

class PodInfo < Sinatra::Application
  enable :status, :ready

  get '/healthz' do
    content_type :json
    if settings.status
      status 200
      { status: 'OK' }.to_json
    else
      status 500
      { status: 'NOT OK' }.to_json
    end
  end

  get '/readyz' do
    content_type :json
    if settings.ready
      status 200
      { status: 'OK' }.to_json
    else
      status 500
      { status: 'NOT OK' }.to_json
    end
  end

  get '/readyz/:operation' do |operation|
    status 202
    if operation == 'enable'
      settings.ready = true
    elsif operation == 'disable'
      settings.ready = false
    else
      status 405
    end
  end

  get '/env' do
    content_type :json
    ENV.to_h.to_json
  end

  get '/headers' do
    content_type :json
    request.env.to_json
  end

  get '/delay/:seconds' do |s|
    sleep s.to_i
    content_type :json
    { delay: s }.to_json
  end

  def redis_connect
    uri = URI.parse(ENV['REDIS_URL'])
    Redis.new(:host => uri.host, :port => uri.port)
  end

  route :put, :post, '/cache/:key' do |key|
    begin
      redis = redis_connect
      redis.set(key, request.body.read)
      status 202
      return
    rescue Redis::BaseError
      content_type :json
      { code: 400, message: 'Redis is offline' }.to_json
    end
  end

  get '/cache/:key' do |key|
    begin
      redis = redis_connect
      redis.get(key)
    rescue Redis::BaseError
      content_type :json
      { code: 400, message: 'Redis is offline' }.to_json
    end
  end

  delete '/cache/:key' do |key|
    begin
      redis = redis_connect
      redis.del(key)
      status 202
    rescue Redis::BaseError
      content_type :json
      { code: 400, message: 'Redis is offline' }.to_json
    end
  end
end
