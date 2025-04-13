node['git']['repositories'].each do |repo_name|
  repo_id = File.basename(repo_name)
  src = File.expand_path(repo_name, Dir.pwd)
  dst = File.join(node['git']['workspace'], repo_id)

  ruby_block "create_repo_#{repo_id}" do
    block do
      require 'net/http'
      require 'uri'
      api = URI("#{node['git']['endpoint']}/admin/users/#{node['git']['repo']['org']}/repos")
      http = Net::HTTP.new(api.host, api.port)
      req = Net::HTTP::Post.new(api.request_uri)
      req.basic_auth(node['user'], node['password'])
      req['Content-Type'] = 'application/json'
      req.body = { name: repo_id, private: false, auto_init: false, default_branch: node['git']['repo']['branch'] }.to_json
      response = http.request(req)
      code = response.code.to_i
      if code != 201 && code != 409
        raise "Fehler beim Erstellen des Repos #{repo_id} (HTTP #{code}): #{res.body}"
      end
    end
    action :run
  end

  directory ::File.dirname(dst) do
    recursive true
    action :create
  end

  ruby_block "copy_repo_#{repo_id}" do
    block do
      require 'fileutils'
      source_root = ENV['PWD']
      src = File.expand_path(repo_name, source_root)
      dst = File.join(node['git']['workspace'], File.basename(repo_name))
      raise "Not found: #{src}" unless ::Dir.exist?(src)
      FileUtils.rm_rf(dst)
      FileUtils.mkdir_p(dst)
      FileUtils.cp_r(Dir.glob("#{src}/."), dst, remove_destination: true)
      FileUtils.chown_R(node['git']['app']['user'], node['git']['app']['group'], dst)
    end
    action :run
  end

  directory "#{dst}/.git" do
    recursive true
    action :delete
  end

  execute "git_init_#{repo_id}" do
    command "git init -b #{node['git']['repo']['branch']}"
    cwd dst
    user node['git']['app']['user']
    action :run
  end

  template "#{dst}/.git/config" do
    source 'repo_config.erb'
    owner node['git']['app']['user']
    group node['git']['app']['group']
    mode '0644'
    variables(repo: repo_id)
    action :create
  end

  execute "git_add_#{repo_id}" do
    command 'git add --all'
    cwd dst
    user node['git']['app']['user']
    action :run
  end

  ruby_block "check_git_status_#{repo_id}" do
    block do
      result = %x(cd #{dst} && git status --porcelain)
      node.run_state["#{repo_id}_dirty"] = !result.strip.empty?
    end
    action :run
  end

  execute "configure_git_identity_#{repo_id}" do
    command <<~EOH
      git config user.name "#{node['user']}"
      git config user.email "#{node['email']}"
    EOH
    cwd dst
    user node['git']['app']['user']
    only_if { node.run_state["#{repo_id}_dirty"] }
    action :run
  end

  execute "git_commit_#{repo_id}" do
    command "git commit -m 'Update repository state'"
    cwd dst
    user node['git']['app']['user']
    only_if { node.run_state["#{repo_id}_dirty"] }
    action :run
  end

  execute "git_push_#{repo_id}" do
    command "git push -f --set-upstream origin #{node['git']['repo']['branch']}"
    cwd dst
    user node['git']['app']['user']
    environment 'GIT_TERMINAL_PROMPT' => '0'
    only_if "git rev-parse HEAD", cwd: dst
    action :run
  end
end