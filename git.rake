namespace :git do
  desc "Rebase a branch from master"
  task :rebase, :branch do |t, args|
    #make sure we have a branch
    branch = args[:branch]
    if(branch.nil?)
      puts "Must specify branch"
      exit
    end

    `git co master`
    `git fetch`
    `git pull origin master`

    if local_branch? branch
      `git co #{branch}`
    else
      `git co --track origin/#{branch}`
    end

    `git pull origin #{branch}`
    `git rebase origin/master`

    puts "Assuming the rebase worked you should be able to push your changes:"
    puts "git push origin #{branch}"
  end

  desc "Convert an existing issue into a pull request"
  task :pullrequest, :issue, :head, :base do |t, args|
    hub = `hub`
    if (hub.include? 'command not found')
      puts "Must have the 'hub' command line tool installed: https://github.com/defunkt/hub"
      exit
    end

    base_ref = args[:issue]
    if(base_ref.nil?)
      puts "Must specify a GitHub issue"
      exit
    end

    head_sha = args[:head] || get_branch
    base_sha = args[:base] || 'master'

    output = `hub pull-request -i #{base_ref} -b #{OWNER}:#{base_sha} -h #{OWNER}:#{head_sha}`

    puts "Assuming the conversion worked, issue \##{base_ref} is now a pull request:"
    puts "#{output}"
  end
end

def change_branch branch
  current_branch = get_branch
  puts current_branch
  if(current_branch != branch)
    puts "Switching to the #{branch} branch"
    `git checkout --track -b #{branch} origin/#{branch} `
  end
end

def get_branch
  `git status | grep '# On branch '`.sub('# On branch ','').strip!
end

def local_branch? branch
  `git branch -l | grep '#{branch}' | wc -l`
end

def store_hash build_dir
  `git log --format='%H' -n1 > #{build_dir}/hash.txt`
end

def get_hash build_dir
  `cat #{build_dir}/hash.txt`.strip!
end
