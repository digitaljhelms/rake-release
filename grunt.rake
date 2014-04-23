namespace :release do
  desc "Bumps version number of project using grunt-bump"
  task :bump, [:versiontype] do | t, args |
    grunt = `grunt --version`
    if (grunt.include? 'command not found')
      puts "Must have the 'grunt' command line tool installed: http://gruntjs.com/"
      exit
    end

    if(['patch','minor','major'].include? args[:versiontype])
      puts "Bumping project version"
      puts `grunt bump:#{args.versiontype}`
    else
      puts "Version type required: patch, minor, major"
      exit
    end
  end
end
