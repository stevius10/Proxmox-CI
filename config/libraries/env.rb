module Env
  require 'net/http'
  require 'uri'
  require 'json'

  def self.base_url(node)
    "#{node['git']['endpoint']}/orgs/#{node['git']['repo']['org']}/actions"
  end

  def self.creds(node)
    [self.get(node, 'user'), self.get(node, 'password')]
  end

  def self.get(node, key)
    return node[key] if node.key?(key) && !node[key].to_s.empty?
    Chef::Log.info("#{key} not found locally")
    get_variable(Chef.run_context.node, key) || get_secret(Chef.run_context.node, key)
  rescue => e
    Chef::Log.warn("Error #{key}: #{e}")
    nil
  end

  def self.set_variable(node, key, value)
    uri = URI("#{base_url(node)}/variables/#{key}")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.request_uri)
    req.basic_auth(*creds(node))
    req['Content-Type'] = 'application/json'
    req.body = { name: key, value: value.to_s }.to_json
    res = http.request(req)
    raise "set_variable #{key} failed: #{res.code} – #{res.body}" unless [201, 204, 409, 422].include?(res.code.to_i)
    true
  end

  def self.get_variable(node, key)
    uri = URI("#{base_url(node)}/variables/#{key}")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Get.new(uri.request_uri)
    req.basic_auth(*creds(node))
    res = http.request(req)
    raise "get_variable #{key} failed: #{res.code} – #{res.body}" unless res.code.to_i == 200
    JSON.parse(res.body)['data']['value']
  end

  def self.set_secret(node, key, value)
    uri = URI("#{base_url(node)}/secrets/#{key}")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Put.new(uri.request_uri)
    req.basic_auth(*creds(node))
    req['Content-Type'] = 'application/json'
    req.body = { name: key, value: value.to_s }.to_json
    res = http.request(req)
    raise "set_secret #{key} failed: #{res.code} – #{res.body}" unless [201, 204, 409, 422].include?(res.code.to_i)
    true
  end

  def self.get_secret(node, key)
    uri = URI("#{base_url(node)}/secrets/#{key}")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Get.new(uri.request_uri)
    req.basic_auth(*creds(node))
    res = http.request(req)
    raise "get_secret #{key} failed: #{res.code} – #{res.body}" unless res.code.to_i == 200
    JSON.parse(res.body)['data']['value']
  end

end