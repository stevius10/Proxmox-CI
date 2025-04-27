node['git']['repositories'].each do |repo_name|

  src = (repo_name == "./") ? ENV['PWD'] : File.expand_path(repo_name, ENV['PWD'])
  name = File.basename(src)
  dst = File.join(node['git']['workspace'], name)

  directory dst do
    owner     node['git']['app']['user']
    group     node['git']['app']['group']
    recursive true
    action    :delete
    only_if   { Dir.exist?(dst) }
  end

  directory dst do
    owner     node['git']['app']['user']
    group     node['git']['app']['group']
    mode      '0755'
    action    :create
  end

  ruby_block "git_repo_#{name}" do
    block do
      require 'net/http'
      require 'uri'
      api = URI("#{node['git']['endpoint']}/admin/users/#{node['git']['repo']['org']}/repos")
      http = Net::HTTP.new(api.host, api.port)
      req = Net::HTTP::Post.new(api.request_uri)
      req.basic_auth(node['user'], node['password'])
      req['Content-Type'] = 'application/json'
      req.body = { name: name, private: false, auto_init: false, default_branch: node['git']['repo']['branch'] }.to_json

      code = http.request(req).code.to_i
      node.run_state["#{name}_repo_created"] = (code == 201)
      node.run_state["#{name}_repo_exists"]  = (code == 409)

      raise "#{name} (HTTP #{code}): #{response.body}" unless [201, 409].include?(code)
    end
    action :run
  end

  execute "git_config_#{name}" do
    command <<-EOH
      git config --global user.name "#{node['user']}"
      git config --global user.email "#{node['email']}"
    EOH
    action :run
  end

  execute "git_init_#{name}" do
    command "git init -b #{node['git']['repo']['branch']}"
    cwd dst
    user node['git']['app']['user']
    action :run
    # only_if { node.run_state["#{name}_repo_created"] }
  end

  template "#{dst}/.git/config" do
    source 'repo_config.erb'
    owner node['git']['app']['user']
    group node['git']['app']['group']
    mode '0644'
    variables(repo: name, git_user: node['git']['app']['user'])
    action :create
    only_if { ::File.directory?("#{dst}/.git") }
  end

  execute "git_pull_#{name}" do
    command "git fetch origin && git branch --set-upstream-to=origin/#{node['git']['repo']['branch']}  #{node['git']['repo']['branch']} && git pull"
    cwd dst
    user node['git']['app']['user']
    action :run
    environment 'HOME' => "/home/#{node['git']['app']['user']}"
    only_if { node.run_state["#{name}_repo_exists"] && false } # TODO
  end

  ruby_block "git_files_#{name}" do
    block do
      require 'fileutils'
      Dir.children(src).each do |entry|
        next if entry == '.git'
        FileUtils.cp_r(File.join(src, entry), File.join(dst, entry), remove_destination: true)
      end
      FileUtils.chown_R(node['git']['app']['user'], node['git']['app']['group'], dst)
    end
    action :run
  end

  execute "git_push_#{name}" do
    command <<-EOH
      git add --all
    
      if [ -n "$(git status --porcelain)" ]; then
        git -c user.name="#{node['user']}" -c user.email="#{node['email']}" commit -m 'initial commit [skip ci]'
      fi
    
      if git rev-parse HEAD &>/dev/null; then
        git push -f origin HEAD:#{node['git']['repo']['branch']}
      fi
    
      git commit --allow-empty --allow-empty-message -m ""
      git push -f origin HEAD:#{node['git']['repo']['release']}
    EOH

    cwd dst
    user node['git']['app']['user']
    environment 'HOME' => "/home/#{node['git']['app']['user']}"
    only_if { ::File.directory?("#{dst}/.git") }
    action :run
  end

end