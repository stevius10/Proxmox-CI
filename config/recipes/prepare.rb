[
  "/home/#{node['git']['app']['user']}",
  "#{node['git']['home']}",
  "#{node['git']['install_dir']}",
  "#{node['git']['data_dir']}",
  "#{node['git']['data_dir']}/custom",
  "#{node['git']['data_dir']}/data",
  "#{node['git']['data_dir']}/data/gitea-repositories",
  "#{node['git']['data_dir']}/log",
  "#{node['git']['data_dir']}/custom/conf",
  "#{node['runner']['install_dir']}",
  "#{node['runner']['data_dir']}",
  "#{node['git']['workspace']}"
].each do |dir|
  directory dir do
    owner node['git']['app']['user']
    group node['git']['app']['group']
    mode '0755'
    recursive true
    action :create
  end
end

package %w(git acl python3-pip python3-dev build-essential libssl-dev lsb-release) do
  action :install
end

execute 'generate_token' do
  command "openssl rand -hex 24 > #{node['git']['token_file']}"
  user node['git']['app']['user']
  creates node['git']['token_file']
  action :run
end

file node['git']['token_file'] do
  owner node['git']['app']['user']
  group node['git']['app']['group']
  mode '0600'
  action :create
end
