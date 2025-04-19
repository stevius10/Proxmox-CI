package 'samba' do
  action :install
end

node['mount'].each do |name, config|
  path = name == 'share' ? '/share' : "/share/#{name}"

  directory path do
    owner node['git']['app']['user']
    group node['git']['app']['group']
    mode '2775'
    recursive true
    action :create
  end
end

template '/etc/samba/smb.conf' do
  source 'smb.conf.erb'
  variables(
    share: node['mount']
  )
  notifies :restart, 'service[smbd]'
end

service 'smbd' do
  action [:enable, :start]
end
