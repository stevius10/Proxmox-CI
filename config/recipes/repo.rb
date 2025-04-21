node['git']['repositories'].each do |repo_name|
  src = (repo_name == "./") ? ENV['PWD'] : File.expand_path(repo_name, ENV['PWD'])
  name = File.basename(src)
  dst = File.join(node['git']['workspace'], name)

  # Repo anlegen (API-Call)
  ruby_block "create_repo_#{name}" do
    block do
      require 'net/http'
      require 'uri'
      api = URI("#{node['git']['endpoint']}/admin/users/#{node['git']['repo']['org']}/repos")
      http = Net::HTTP.new(api.host, api.port)
      req = Net::HTTP::Post.new(api.request_uri)
      req.basic_auth(node['user'], node['password'])
      req['Content-Type'] = 'application/json'
      req.body = {
        name: name,
        private: false,
        auto_init: false,
        default_branch: node['git']['repo']['branch']
      }.to_json

      response = http.request(req)
      code = response.code.to_i
      node.run_state["#{name}_repo_created"] = code == 201

      raise "#{name} (HTTP #{code}): #{response.body}" unless [201, 409].include?(code)
    end
    action :run
  end

  # Zielverzeichnis immer löschen und neu anlegen, um den Stand zu garantieren
  ruby_block "prepare_repo_#{name}" do
    block do
      require 'fileutils'
      FileUtils.rm_rf(dst)
      FileUtils.mkdir_p(dst)
      FileUtils.cp_r("#{src}/.", dst, remove_destination: true)
      FileUtils.chown_R(node['git']['app']['user'], node['git']['app']['group'], dst)
    end
    action :run
  end

  # Git initialisieren, falls neu
  execute "git_init_#{name}" do
    command "git init -b #{node['git']['repo']['branch']}"
    cwd dst
    user node['git']['app']['user']
    action :run
    only_if { node.run_state["#{name}_repo_created"] }
  end

  # .git/config immer via Template überschreiben
  template "#{dst}/.git/config" do
    source 'repo_config.erb'
    owner node['git']['app']['user']
    group node['git']['app']['group']
    mode '0644'
    variables(
      repo: name,
      git_user: node['git']['app']['user']
    )
    action :create
    only_if { ::File.directory?("#{dst}/.git") }
  end

  # Neues Repo: normaler Push auf Default-Branch
  execute "git_initial_push_#{name}" do
    command <<-EOH
      git add --all
      git config user.name "#{node['user']}"
      git config user.email "#{node['email']}"
      git commit -m 'Initial commit' --allow-empty
      git push -u origin #{node['git']['repo']['branch']}
    EOH
    cwd dst
    user node['git']['app']['user']
    environment 'HOME' => "/home/#{node['git']['app']['user']}"
    only_if { node.run_state["#{name}_repo_created"] }
    action :run
  end

  # Existierendes Repo: Orphan-Branch "static" pushen, ohne Historie
  execute "git_orphan_static_push_#{name}" do
    command <<-EOH
      git init
      git remote add origin ssh://#{node['git']['app']['user']}@#{node['git']['repo']['ssh']}/#{name}.git || git remote set-url origin ssh://#{node['git']['app']['user']}@#{node['git']['repo']['ssh']}/#{name}.git
      git checkout --orphan static
      git rm -rf .
      git add .
      git config user.name "#{node['user']}"
      git config user.email "#{node['email']}"
      git commit -m 'static branch: aktueller Stand' --allow-empty
      git push -f origin static
    EOH
    cwd dst
    user node['git']['app']['user']
    environment 'HOME' => "/home/#{node['git']['app']['user']}"
    only_if { !node.run_state["#{name}_repo_created"] && ::File.directory?("#{dst}/.git") }
    action :run
  end
end
