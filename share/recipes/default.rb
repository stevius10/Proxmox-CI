%w[samba samba-common samba-client].each do |pkg|
  package pkg do
    action :install
  end
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
  notifies :restart, 'service[smb]'
end

service 'smb' do
  action [:enable, :start]
end
