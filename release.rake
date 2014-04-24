namespace :release do
  desc "Cleans the tmp dir to allow you to run the prepare"
  task :clean do
    vars = deploy_vars
    build_dir = vars[:build_dir]

    if(File.directory?(build_dir))
      puts "Removing build dir: #{build_dir}"
      FileUtils.rm_rf(build_dir)
    end

    puts "Done"
  end

  desc "Removes unnecessary files/directories from release"
  task :prune do | t, args |
    vars = deploy_vars(args)
    source = vars[:source]

    remove_paths = [
      '.git',
      '.gitignore',
      '.gitmodules',
      'Rakefile'
    ]
    remove_paths.push(*REMOVE_PATHS) # merge with repo-specific config

    remove_submodules = ['tasks/rake']
    remove_submodules.push(*REMOVE_SUBMODULES) # merge with repo-specific config

    puts "Removing submodules unnecessary for release"
    remove_submodules.each do |path|
      current_file = source[:dir] + '/' + path
      puts "Removing: #{current_file}"
      if(File.directory?(current_file))
        puts "Found: #{current_file}"
      end
      FileUtils.rm_rf(current_file)
    end

    puts "Removing git files from submodules"
    submodules = `git submodule status`.split("\n")
    submodules.each do |submodule|
      sub = submodule.split(' ')
      if !remove_submodules.include?(sub[1])
        puts sub[1]
        sub_path = source[:dir]+'/'+sub[1]
        next unless File.directory?(sub_path)
        FileUtils.cd(sub_path)
        FileUtils.rm_rf('.git')
      end
    end
    FileUtils.cd(source[:dir])

    puts "Removing files/directories unnecessary for release"
    remove_paths.each do |path|
      current_file = source[:dir] + '/' + path
      puts "Removing: #{current_file}"
      if(File.directory?(current_file))
        puts "Found: #{current_file}"
      end
      FileUtils.rm_rf(current_file)
    end
  end

  desc "Builds distribution release output"
  task :build do | t, args |
    puts "Resolving pre-build dependencies"
    `#{PRE_BUILD}`

    puts "Building distribution output"
    puts `#{BUILD_CMD}`
  end

  desc "Relocates distribution release output to the top-level"
  task :toplevel do | t, args |
    puts "Making dist the root"
    Dir.foreach(source[:dir]) do |item|
      next if item == '.' or item == '..' or item == 'dist'
      puts "Removing: " + source[:dir] + '/' + item
      current_file = source[:dir] + '/' + item
      FileUtils.rm_rf(current_file)
    end
    `mv #{source[:dir]}/dist/* #{source[:dir]}`
    FileUtils.rm_rf(source[:dir]+'/dist')
  end

  desc "Performs a no-fast-forward merge of master into stable"
  task :noffmerge do | t, args |
    vars = deploy_vars(args)
    source = vars[:source]

    puts "Checking out stable branch"
    puts `git checkout stable`

    puts "Merging master into stable"
    puts `git merge --no-ff -m "Merge branch 'master' into stable" master`

    puts "Pushing stable branch"
    puts `git push origin #{source[:branch]}` if !TASKENV.eql? "debug"
  end

  desc "Clones and prunes the dev repo"
  task :prepare, [:source, :target] do | t, args |
    vars = deploy_vars(args)
    build_dir = vars[:build_dir]
    source = vars[:source]
    target = vars[:target]

    if(File.directory?(build_dir))
      puts "Error, tmp dir exist please remove it and re-run command"
      exit
    end
    puts "Making build dir: #{build_dir}"
    Dir.mkdir(build_dir)

    puts "Cloning the code repo"
    `git clone #{source[:repo]} #{source[:dir]}`

    puts "Changing dir: #{source[:dir]}"
    FileUtils.cd(source[:dir])

    change_branch(source[:branch])

    # Rake::Task["release:noffmerge"].invoke

    store_hash(build_dir)

    # Copy code repo for tagging later
    FileUtils.cd(build_dir)
    `cp -R #{source[:dir]} #{source[:tag]}`

    puts "Updating submodules"
    FileUtils.cd(source[:dir])
    `git submodule init`
    `git submodule update`

    if(SHIP_DIST)
      # Run production/dist build tasks
      Rake::Task["release:build"].invoke

      if(DIST_TLD)
        # Position production/dist build at top-level
        Rake::Task["release:toplevel"].invoke
      end
    end

    # Scrub all files to remove any cruft
    Rake::Task["release:prune"].invoke

    puts "Cloning the release repo"
    FileUtils.cd(build_dir)
    `git clone #{target[:repo]} #{target[:dir]}`

    FileUtils.cd(target[:dir])
    change_branch(target[:branch])
    FileUtils.cd(source[:dir])

    puts "Copying git files"
    `cp -R #{target[:dir]}/.git #{source[:dir]}`

    puts "Status"
    puts `git status`

    puts "Done"
  end

  desc "Git a status of what will be committed"
  task :status do
    vars = deploy_vars
    source = vars[:source]

    puts "Changing dir: #{source[:dir]}"
    FileUtils.cd(source[:dir])

    puts "Status"
    puts `git status`
  end

  desc "Add all of the files to the git"
  task :add do
    vars = deploy_vars
    source = vars[:source]

    puts "Changing dir: #{source[:dir]}"
    FileUtils.cd(source[:dir])

    puts "Adding files"
    puts `git add --all .`
  end

  desc "See a diff of what will be committed"
  task :diff do
    vars = deploy_vars
    source = vars[:source]

    puts "Changing dir: #{source[:dir]}"
    FileUtils.cd(source[:dir])

    puts "Diff"
    puts `git diff`
  end

  desc "Tag the code repository"
  task :tag, [:tagname] do | t, args |
    vars = deploy_vars
    source = vars[:source]

    puts "Changing dir: #{source[:tag]}"
    FileUtils.cd(source[:tag])

    change_branch(source[:branch])

    puts "Tag: " + args[:tagname]
    puts `git tag #{args[:tagname]}` if !TASKENV.eql? "debug"
    puts `git push --tags` if !TASKENV.eql? "debug"
  end

  desc "Commit and push the changes, must be run after release:prepare"
  task :deploy, [:semver, :shortname, :metadata, :target] do | t, args |
    if(args[:semver].nil?)
      puts "Version number required"
      exit
    elsif(args[:shortname].nil?)
      puts "NATO compliant shortname/codename required"
      exit
    end
    vars = deploy_vars(args)
    build_dir = vars[:build_dir]
    source = vars[:source]
    target = vars[:target]
    tagname = args[:semver] + "-" + args[:shortname]
    unless args[:metadata].nil?
      tagname << "+" + args[:metadata]
    end

    hash = get_hash(build_dir)
    puts "Working with hash: " + hash

    message = "Release #{args[:semver]}, codename \"#{args[:shortname]}\""
    message << "\n\nCross-repository release reference: #{OWNER}/#{REPOSITORY_SRC}@#{hash}"

    puts "Changing dir: #{source[:dir]}"
    FileUtils.cd(source[:dir])

    puts "Commit: " + message
    puts `git commit -m '#{message}'` if !TASKENV.eql? "debug"

    puts "Push: " + target[:branch]
    puts `git push origin #{target[:branch]}` if !TASKENV.eql? "debug"

    # Tag the source repository
    Rake::Task["release:tag"].invoke(tagname)
  end
end

def deploy_vars options = {}
  opts = {
    :source => 'stable',
    :target => 'master'
  }.merge options

  build_dir = "/tmp/#{REPOSITORY_SRC}-build"

  source = {
    :dir => "#{build_dir}/build",
    :tag => "#{build_dir}/tag",
    :branch => opts[:source],
    :repo => "git@github.com:#{OWNER}/#{REPOSITORY_SRC}.git"
  }
  target = {
    :dir => "#{build_dir}/target",
    :branch => opts[:target],
    :repo => "git@github.com:#{OWNER}/#{REPOSITORY_DEST}.git"
  }

  return {
    :build_dir => build_dir,
    :source => source,
    :target => target
  }
end
