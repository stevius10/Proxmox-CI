default['ip']                       = "#{ENV['IP']}"

default['git']['app']['user']       = 'app'
default['git']['app']['group']      = 'app'

default['git']['install_dir']       = '/app/git'
default['git']['data_dir']          = '/app/git/data'
default['git']['home']              = "/home/#{node['git']['app']['user']}/git"
default['git']['workspace']         = '/share/workspace'

default['git']['port']['http']      = 8080
default['git']['port']['ssh']       = 2222
default['git']['endpoint']          = "http://localhost:#{node['git']['port']['http']}/api/v1"

default['git']['repo']['branch']    = "main"
default['git']['repo']['org']       = 'srv'
default['git']['repo']['ssh']       = "#{node['ip']}:#{node['git']['port']['ssh']}/#{node['git']['repo']['org']}"

default['runner']['install_dir']    = '/app/runner'
default['runner']['labels']         = 'shell'

default['git']['repositories']      = [ "./base", "./" ]

# load(File.expand_path('secrets.rb', __FILE__)) if File.exist?(File.expand_path('secrets.rb', __FILE__))