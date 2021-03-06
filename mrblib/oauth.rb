class OAuth < HttpRequest
  OAUTH_VERSION = '1.0'
  VERSION = '0.1'
  USER_AGENT = "mruby_oauth/" + VERSION
  def initialize(consumer_key, consumer_secret, token, token_secret)
    @consumer_key = consumer_key
    @consumer_secret = consumer_secret
    @token = token
    @token_secret = token_secret
    @signature_method = 'HMAC-SHA1'
    self
  end
  def request(method, url, body = nil, headers = {}) 
    parser = HTTP::Parser.new()
    url = parser.parse_url(url)
    request = create_http_request(method, body, headers)
    host = url.host.to_sym.to_s
    if url.query
        request_uri = url.path + "?" + url.query
    else
        request_uri = url.path
    end
    request['Authorization'] = auth_header(method, url, request["body"])
    request['User-Agent']    = USER_AGENT
    host = url.host.to_sym.to_s
    SimpleHttp.new(url.schema, host, url.port).request(method, request_uri, request)
  end 
  def auth_header(method, url, body)
    parameters = oauth_parameters
    parameters["oauth_signature"] = signature(method, url, body, parameters)
    "OAuth #{encode_parameters(parameters, ', ', '"')}"
  end
  def oauth_parameters
    {
      "oauth_consumer_key" => @consumer_key,
      "oauth_token" => @token,
      "oauth_signature_method" => @signature_method,
      "oauth_timestamp" => timestamp,
      "oauth_nonce" => nonce,
      "oauth_version" => OAUTH_VERSION
    }
  end
  def timestamp
    Time.now.to_i.to_s
  end
  def nonce
    Digest::MD5.hexdigest(timestamp)
  end
  def signature(*args)
    base64(digest_hmac_sha1(signature_base_string(*args)))
  end
  def base64(value)
    r = [ value ].pack('m')
    r.include?("\n") ? r.split("\n").join("") : r
  end
  def digest_hmac_sha1(value)
    Digest::HMAC.digest(value, secret, Digest::SHA1)
  end
  def secret
    escape(@consumer_secret) + '&' + escape(@token_secret)
  end
  def signature_base_string(method, url, body, parameters)
    method = method.upcase
    base_url = signature_base_url(url)
    parameters = normalize_parameters(parameters, body, url.query)
    encode_parameters([ method, base_url, parameters ])
  end
  def signature_base_url(url)
    str = url.schema + "://"
    str += url.host
    str += ":" + url.port.to_s  if url.port
    str += url.path if url.path
    str
  end
  def normalize_parameters(parameters, body, query)
    parameters = encode_parameters(parameters, nil)
    parameters += body.split('&') if body
    parameters += query.split('&') if query
    parameters.sort.join('&')
  end
end
