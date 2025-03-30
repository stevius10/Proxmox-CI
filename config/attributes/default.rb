default['git']['app_user']       = 'app'
default['git']['app_group']      = 'app'
default['git']['ip']             = node['ipaddress']
default['git']['workspace']      = '/share/workspace'
default['git']['cfg_git_org']    = 'srv'
default['git']['git_port']       = 8080
default['git']['git_api_endpoint'] = "http://localhost:#{node['git']['git_port']}/api/v1"
default['git']['git_repo_list']  = ['container-default']
default['git']['install_dir'] = '/app/git'
default['git']['data_dir']    = '/app/git/data'
default['git']['git_home']        = "/home/#{node['git']['app_user']}/git"
default['git']['git_db_path']     = "#{node['git']['data_dir']}/gitea.db"
default['git']['git_repo_ssh']    = "#{node['git']['ip']}:/#{node['git']['cfg_git_org']}"
default['git']['git_default_branch'] = 'main'
default['runner']['install_dir'] = '/app/runner'
default['runner']['data_dir']    = '/app/runner/data'
default['runner']['labels']      = 'shell'
default['git']['token_file']         = "/home/#{node['git']['app_user']}/.token"

load(File.expand_path('secrets.rb', __FILE__)) if File.exist?(File.expand_path('secrets.rb', __FILE__))