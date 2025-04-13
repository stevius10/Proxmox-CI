if !node['runner']['version'] && node['runner']['version'].to_s.empty?
  ruby_block 'fetch_latest_runner_version' do
    block do
      require 'open-uri'
      html = URI.open('https://gitea.com/gitea/act_runner/releases/latest').read
      latest = html.match(/title>v([\d\.]+)/)
      if latest
        node.run_state['runner_version'] = latest[1]
      else
        raise 'Konnte neueste Act Runner-Version nicht ermitteln'
      end
    end
    action :run
  end
end

remote_file "#{node['runner']['install_dir']}/ace_runner" do
  source lazy {
    ver = node['runner']['version'] && !node['runner']['version'].to_s.empty? ? node['runner']['version'] : node.run_state['runner_version']
    arch = (node['kernel']['machine'] =~ /arm64|aarch64/) ? 'arm64' : 'amd64'
    "https://gitea.com/gitea/act_runner/releases/download/v#{ver}/act_runner-#{ver}-linux-#{arch}"
  }
  owner node['git']['app']['user']
  group node['git']['app']['group']
  mode '0755'
  action :create_if_missing
end

template "#{node['runner']['install_dir']}/config.yaml" do
  source 'runner.config.yaml.erb'
  owner node['git']['app']['user']
  group node['git']['app']['group']
  mode '0644'
  action :create
end

template '/etc/systemd/system/runner.service' do
  source 'runner.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
  notifies :run, 'execute[daemon_reload]', :immediately
end

ruby_block 'generate_runner_token' do
  block do
    cmd = Mixlib::ShellOut.new("#{node['git']['install_dir']}/gitea actions --config #{node['git']['install_dir']}/app.ini generate-runner-token", user: node['git']['app']['user'], environment: { 'HOME' => "/home/#{node['git']['app']['user']}" })
    cmd.run_command
    cmd.error!
    node.run_state['runner_token'] = cmd.stdout.strip
  end
end

execute 'register_runner' do
  command lazy {
    "#{node['runner']['install_dir']}/ace_runner register " \
      "--instance http://localhost:#{node['git']['port']} " \
      "--token #{node.run_state['runner_token']} " \
      "--no-interactive " \
      "--config #{node['runner']['install_dir']}/config.yaml"
  }
  cwd node['runner']['install_dir']
  user node['git']['app']['user']
  environment('HOME' => "/home/#{node['git']['app']['user']}")
  returns [0, 1]
  not_if { ::File.exist?("#{node['runner']['data_dir']}/.runner") }
  action :run
end

directory node['runner']['install_dir'] do
  owner node['git']['app']['user']
  group node['git']['app']['group']
  mode '0755'
  recursive true
  action :create
end

service 'runner' do
  action [:enable, :start]
  subscribes :restart, 'template[runner.config.yaml.erb]', :delayed
  subscribes :restart, 'remote_file[#{node["git"]["runner_install_dir"]}/ace_runner]', :delayed
end
