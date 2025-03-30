ruby_block 'wait_for_gitea' do
  block do
    require 'socket'
    port = node['git']['port']
    begin
      Timeout.timeout(15) do
        loop do
          begin
            TCPSocket.new('127.0.0.1', port).close
            break
          rescue Errno::ECONNREFUSED
            sleep 1
          end
        end
      end
    rescue Timeout::Error
      Chef::Log.warn("Gitea (Port #{port}) nicht erreichbar – fahre dennoch fort")
    end
  end
  action :run
end

directory "/home/#{node['git']['app']['user']}/.ssh" do
  owner node['git']['app']['user']
  group node['git']['app']['user']
  mode '0700'
  action :create
end

execute 'generate_app_ssh_key' do
  command "ssh-keygen -t rsa -b 4096 -C \"#{node['email']}\" -f \"/home/#{node['git']['app']['user']}/.ssh/id_rsa\" -N \"\""
  user node['git']['app']['user']
  creates "/home/#{node['git']['app']['user']}/.ssh/id_rsa"
  action :run
end

ruby_block 'read_app_public_key' do
  block do
    pub_key_path = "/home/#{node['git']['app']['user']}/.ssh/id_rsa.pub"
    node.run_state['pub'] = ::File.read(pub_key_path).strip
  end
  action :run
end

execute 'create_gitea_user' do
  command "#{node['git']['install_dir']}/gitea admin user create --config #{node['git']['install_dir']}/app.ini " +
          "--username #{node['user']} --password #{node['password']} " +
          "--email #{node['email']} --admin --must-change-password=false"
  environment 'GITEA_WORK_DIR' => node['git']['data_dir']
  user node['git']['app']['user']
  returns [0, 1]
  action :run
end

ruby_block 'add_ssh_key_via_api' do
  block do
    require 'net/http'
    require 'uri'
    api = URI("#{node['git']['endpoint']}/admin/users/#{node['user']}/keys")
    http = Net::HTTP.new(api.host, api.port)
    req = Net::HTTP::Post.new(api.request_uri)
    req.basic_auth(node['user'], node['password'])
    req['Content-Type'] = 'application/json'
    key_content = node.run_state['pub'] || ''
    req.body = { title: "technical key for #{node['user']}", key: key_content }.to_json
    response = http.request(req)
    code = response.code.to_i
    if code != 201 && code != 422
      raise "Fehler beim Setzen des SSH-Schlüssels (HTTP #{code}): #{response.body}"
    end
  end
  action :run
end

execute 'fix_app_home_permissions' do
  command "chown -R #{node['git']['app']['user']}:#{node['git']['app']['group']} /home/#{node['git']['app']['user']}"
  action :run
end

file "/home/#{node['git']['app']['user']}/.ssh/config" do
  content <<-CONF.gsub(/^\s+/, '')
    Host #{node['ip']}
      HostName #{node['ip']}
      User #{node['user']}
      IdentityFile /home/#{node['git']['app']['user']}/.ssh/id_rsa
      StrictHostKeyChecking no
  CONF
  owner node['git']['app']['user']
  group node['git']['app']['user']
  mode '0600'
  action :create
end

execute 'test_ssh_connection' do
  command "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -T #{node['user']}@#{node['git']['ip']} || true"
  user node['git']['app']['user']
  action :run
  live_stream true
end

execute 'configure_git_globals' do
  command <<-SH
    git config --global user.email "#{node['email']}" && \
    git config --global user.name "#{node['user']}" && \
    git config --global core.sshCommand "ssh -i /home/#{node['git']['app']['user']}/.ssh/id_rsa" && \
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
    req.body = { username: node['git']['cfg_git_org'] }.to_json
    response = http.request(req)
    code = response.code.to_i
    if code != 201 && code != 422
      raise "Fehler beim Erstellen der Organisation (HTTP #{code}): #{response.body}"
    end
  end
  action :run
end

ruby_block 'set_org_variables_and_secrets' do
  block do
    require 'net/http'
    require 'uri'
    require 'json'
    org = node['git']['cfg_git_org']
    api_base = "#{node['git']['endpoint']}/orgs/#{org}/actions"
    creds = [node['user'], node['password']]
    env_vars = {
      'LOGIN_USER'     => node['user'],
      'LOGIN_PASSWORD' => node['password']
    }
    env_vars.each do |key, value|
      uri_var = URI("#{api_base}/variables/#{key}")
      http = Net::HTTP.new(uri_var.host, uri_var.port)
      req_var = Net::HTTP::Post.new(uri_var.request_uri)
      req_var.basic_auth(*creds)
      req_var['Content-Type'] = 'application/json'
      req_var.body = { name: key, value: value.to_s }.to_json
      res_v = http.request(req_var)
      code_v = res_v.code.to_i
      if ![201, 204, 409, 422].include?(code_v)
        raise "Fehler beim Setzen von Variable #{key} (HTTP #{code_v}): #{res_v.body}"
      end

      uri_sec = URI("#{api_base}/secrets/#{key}")
      req_sec = Net::HTTP::Put.new(uri_sec.request_uri)
      req_sec.basic_auth(*creds)
      req_sec['Content-Type'] = 'application/json'
      req_sec.body = { name: key, value: value.to_s }.to_json
      res_s = http.request(req_sec)
      code_s = res_s.code.to_i
      if ![201, 204, 409, 422].include?(code_s)
        raise "Fehler beim Setzen von Secret #{key} (HTTP #{code_s}): #{res_s.body}"
      end
    end
  end
  action :run
end
