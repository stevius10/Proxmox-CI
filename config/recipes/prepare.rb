ruby_block 'environment_info' do
  block do
    Chef::Log.info("Node Attributes: ")
    node&.each do |key, value|
      Chef::Log.info("ATTR #{key}=#{value}")
    end

    Chef::Log.info("Databag Attributes: ")
    node.override_attrs&.each do |key, value|
      Chef::Log.info("DATA #{key}=#{value}")
    end
  end
end

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

package %w(git acl python3-pip nodejs npm) do
  action :install
end
