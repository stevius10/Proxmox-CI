require_relative '../libraries/env'

ruby_block 'wait_for_startup' do
  block do
    require 'socket'; require 'timeout'
    Timeout.timeout(15) do
      loop do
        break if TCPSocket.new('127.0.0.1', node['git']['port']['http']).close rescue sleep 1
      end
    end
  rescue Timeout::Error
    Chef::Log.warn('Service not reachable')
  end
  action :run
end

directory "/home/#{node['git']['app']['user']}/.ssh" do
  owner node['git']['app']['user']
  group node['git']['app']['user']
  mode '0700'
  action :create
end

execute 'generate_key' do
  command "ssh-keygen -t rsa -b 4096 -C \"#{node['email']}\" -f \"/home/#{node['git']['app']['user']}/.ssh/id_rsa\" -N \"\""
  user node['git']['app']['user']
  creates "/home/#{node['git']['app']['user']}/.ssh/id_rsa"
  action :run
end

ruby_block 'read_key' do
  block do
    pub_key_path = "/home/#{node['git']['app']['user']}/.ssh/id_rsa.pub"
    node.run_state['pub'] = ::File.read(pub_key_path).strip
  end
  action :run
end

execute 'create_user' do
  command "#{node['git']['install_dir']}/gitea admin user create --config #{node['git']['install_dir']}/app.ini " +
          "--username #{node['user']} --password #{node['password']} " +
          "--email #{node['email']} --admin --must-change-password=false"
  environment 'GITEA_WORK_DIR' => node['git']['data_dir']
  user node['git']['app']['user']
  returns [0, 1]
  action :run
end

ruby_block 'add_key' do
  block do
    require 'net/http'; require 'uri'
    api = URI("#{node['git']['endpoint']}/admin/users/#{Env.get(node, 'user')}/keys")
    http, req = Net::HTTP.new(api.host, api.port), Net::HTTP::Post.new(api.request_uri)
    req['Content-Type'] = 'application/json'
    req.basic_auth(Env.get(node, 'user'), Env.get(node, 'password'))
    req.body = { title: "proxmox-ci", key: node.run_state['pub'] || Env.get(node, 'pub') }.to_json
    response = http.request(req)
    code = response.code.to_i
    raise "HTTP #{code}: #{response.body}" if code != 201 && code != 422
  end
  action :run
end

execute 'fix_permissions' do
  command "chown -R #{node['git']['app']['user']}:#{node['git']['app']['group']} /home/#{node['git']['app']['user']}"
  action :run
end

file "/home/#{node['git']['app']['user']}/.ssh/config" do
  content <<~CONF
    Host #{node['ip']}
      HostName #{node['ip']}
      User #{node['git']['app']['user']}
      IdentityFile /home/#{node['git']['app']['user']}/.ssh/id_rsa
      StrictHostKeyChecking no
  CONF
  owner node['git']['app']['user']
  group node['git']['app']['user']
  mode '0600'
  action :create
end

execute 'test_connection' do
  command "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -T #{node['user']}@#{node['git']['ip']} || true"
  user node['git']['app']['user']
  action :run
  live_stream true
end

execute 'configure_git' do
  command <<-SH
    git config --global user.email "#{Env.get(node, 'email')}" && \
    git config --global user.name "#{Env.get(node, 'user')}" && \
    git config --global --add safe.directory "*" && \
    sudo git config --system --add safe.directory "*"
  SH
  environment 'HOME' => "/home/#{node['git']['app']['user']}"
  action :run
end

ruby_block 'create_organization' do
  block do
    require 'net/http'
    require 'uri'
    api = URI("#{node['git']['endpoint']}/orgs")
    http = Net::HTTP.new(api.host, api.port)
    req = Net::HTTP::Post.new(api.request_uri)
    req.basic_auth(node['user'], node['password'])
    req['Content-Type'] = 'application/json'
    req.body = { username: node['git']['repo']['org'] }.to_json
    response = http.request(req)
    code = response.code.to_i
    if code != 201 && code != 422
      raise "HTTP #{code}: #{response.body}"
    end
  end
  action :run
end

# ruby_block 'configure_environment' do
#   block do
#
#
#     all_from_databag.each do |key, value|
#       next if value.nil? || value.to_s.strip.empty?
#       Env.set_variable(Chef.run_context.node, key, value)
#       Env.set_secret(Chef.run_context.node, key, value)
#       Chef::Log.info("Set: #{key}")
#     end
#   end
#   action :run
# end