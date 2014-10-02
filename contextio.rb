require 'faraday'
require 'faraday_middleware'

class ContextIO
  attr_reader :key, :secret

  def initialize(key, secret)
    @key = key
    @secret = secret
  end

  def request(method, path, params)
    normalized_params = params.inject({}) do |normalized_params, (key, value)|
      normalized_params[key.to_sym] = value
      normalized_params
    end

    connection.send(method, URI.escape(path, '<>'), normalized_params)
  end

  private

  def connection
    @connection ||= Faraday::Connection.new('https://api.context.io') do |faraday|
      faraday.headers['Accept'] = 'application/json'

      faraday.request :oauth, consumer_key: key, consumer_secret: secret
      faraday.request :url_encoded

      faraday.adapter Faraday.default_adapter
      faraday.use FaradayMiddleware::ParseJson
    end
  end
end

