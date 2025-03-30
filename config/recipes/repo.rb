node['git']['git_repo_list'].each do |repo_name|
  ruby_block "create_repo_#{repo_name}" do
    block do
      require 'net/http'
      require 'uri'
      require 'json'
      api = URI("#{node['git']['git_api_endpoint']}/org/#{node['git']['cfg_git_org']}/repos")
      http = Net::HTTP.new(api.host, api.port)
      req = Net::HTTP::Post.new(api.request_uri)
      req.basic_auth(node['git']['login_user'], node['git']['login_password'])
      req['Content-Type'] = 'application/json'
      req.body = { name: repo_name, private: false, auto_init: false, default_branch: node['git']['git_default_branch'] }.to_json
      res = http.request(req)
      code = res.code.to_i
      if code != 201 && code != 409
        raise "Fehler beim Anlegen von Repository #{repo_name} (HTTP #{code}): #{res.body}"
      end
    end
    action :run
  end

  directory "#{node['git']['workspace']}/#{repo_name}" do
    owner node['git']['app_user']
    group node['git']['app_group']
    mode '0755'
    recursive true
    action :create
  end

  directory "#{node['git']['workspace']}/#{repo_name}/.git" do
    recursive true
    action :delete
  end

  remote_directory "#{node['git']['workspace']}/#{repo_name}" do
    source repo_name
    owner node['git']['app_user']
    group node['git']['app_group']
    mode '0755'
    purge false
    action :create
  end

  execute "git_init_#{repo_name}" do
    command "git init -b #{node['git']['git_default_branch']}"
    cwd "#{node['git']['workspace']}/#{repo_name}"
    user node['git']['app_user']
    action :run
  end

  template "#{node['git']['workspace']}/#{repo_name}/.git/config" do
    source 'repo_config.erb'
    owner node['git']['app_user']
    group node['git']['app_group']
    mode '0644'
    variables(repo: repo_name)
    action :create
  end

  execute "git_add_#{repo_name}" do
    command 'git add --all'
    cwd "#{node['git']['workspace']}/#{repo_name}"
    user node['git']['app_user']
    action :run
  end

  ruby_block "check_git_status_#{repo_name}" do
    block do
      result = %x(cd #{node['git']['workspace']}/#{repo_name} && git status --porcelain)
      node.run_state["#{repo_name}_dirty"] = !result.strip.empty?
    end
    action :run
  end

  execute "git_commit_#{repo_name}" do
    command "git commit -m 'Update repository state'"
    cwd "#{node['git']['workspace']}/#{repo_name}"
    user node['git']['app_user']
    only_if { node.run_state["#{repo_name}_dirty"] }
    action :run
  end

  execute "git_push_#{repo_name}" do
    command "git push -f --set-upstream origin #{node['git']['git_default_branch']}"
    cwd "#{node['git']['workspace']}/#{repo_name}"
    user node['git']['app_user']
    environment 'GIT_TERMINAL_PROMPT' => '0'
    only_if "git rev-parse HEAD", cwd: "#{node['git']['workspace']}/#{repo_name}"
    action :run
  end
end
