node['git']['repositories'].each do |repo_name|
  src = (repo_name == "./") ?  "#{ENV['PWD']}" : File.expand_path(repo_name, ENV['PWD'])
  name = File.basename(src)
  dst = File.join(node['git']['workspace'], name)

  ruby_block "create_repo_#{name}" do
    block do

      Chef::Log.info("src=#{src}, name=#{name}, dst=#{dst}")

      require 'net/http'
      require 'uri'
      api = URI("#{node['git']['endpoint']}/admin/users/#{node['git']['repo']['org']}/repos")
      http = Net::HTTP.new(api.host, api.port)
      req = Net::HTTP::Post.new(api.request_uri)
      req.basic_auth(node['user'], node['password'])
      req['Content-Type'] = 'application/json'
      req.body = { name: name, private: false, auto_init: false, default_branch: node['git']['repo']['branch'] }.to_json
      response = http.request(req)
      code = response.code.to_i
      if code != 201 && code != 409
        raise "Fehler beim Erstellen des Repos #{name} (HTTP #{code}): #{response.body}"
      end
    end
    action :run
  end

  directory dst do
    recursive true
    action :create
  end

  ruby_block "copy_repo_#{name}" do
    block do
      require 'fileutils'
      src = (repo_name == "./") ? ENV['PWD'] : File.expand_path(name, ENV['PWD'])
      dst = File.join(node['git']['workspace'], File.basename(name))
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
    only_if { ::File.directory?("#{dst}/.git") }
  end

  execute "git_init_#{name}" do
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
    variables(repo: name, git_user: node['git']['app']['user'])
    action :create
  end

  execute "git_add_#{name}" do
    command 'git add --all'
    cwd dst
    user node['git']['app']['user']
    action :run
  end

  ruby_block "check_git_status_#{name}" do
    block do
      result = %x(cd #{dst} && git status --porcelain)
      node.run_state["#{name}_dirty"] = !result.strip.empty?
    end
    action :run
  end

  execute "configure_git_identity_#{name}" do
    command <<~EOH
      git config user.name "#{node['user']}"
      git config user.email "#{node['email']}"
    EOH
    cwd dst
    user node['git']['app']['user']
    only_if { node.run_state["#{name}_dirty"] }
    action :run
  end

  execute "git_commit_#{name}" do
    command "git commit -a --allow-empty --allow-empty-message -m '' "
    cwd dst
    user node['git']['app']['user']
    environment 'HOME' => "/home/#{node['git']['app']['user']}"
    only_if { node.run_state["#{name}_dirty"] }
    action :run
  end

  execute "git_push_#{name}" do
    command "git push -f --set-upstream origin #{node['git']['repo']['branch']}"
    cwd dst
    user node['git']['app']['user']
    environment 'GIT_TERMINAL_PROMPT' => '0', 'HOME' => "/home/#{node['git']['app']['user']}"
    only_if "git rev-parse HEAD", cwd: dst
    action :run
  end
end