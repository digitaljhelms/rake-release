## Requirements

* [git](http://git-scm.com/)
* [Rake](http://rake.rubyforge.org/)

### Optional

* [grunt-bump](https://www.npmjs.org/package/grunt-bump)
   - used primarily for node projects, depends on [node](http://nodejs.org/) and [grunt](http://gruntjs.com)

## Instructions

1. Install dependencies above
2. Clone this repository as a submodule into `tasks/rake`: 

   `git submodule add -b master git@github.com:digitaljhelms/rake-release.git tasks/rake`

3. Paste the example code below into `Rakefile`
4. Run `rake` to see a list of available commands

### Updates

To pull in updates from this repository into your submodule, use `git submodule update --remote`.

## `Rakefile`

```rb
require 'rake'

ROOT = File.expand_path(File.dirname(__FILE__))

OWNER = '' # GitHub organization or username
TASKENV = 'prod' # debug == do not commit/tag/push/etc...
REPOSITORY_SRC = '' # source repository
REPOSITORY_DEST = '' # destination repository

REMOVE_PATHS = [] # array of paths specific to project
REMOVE_SUBMODULES = [] # array of submodules specific to project

SHIP_DIST = true # release built output? if false, PRE_BUILD and BUILD_CMD are not needed
DIST_TLD = false # (if SHIP_DIST=true) move dist contents to top-level in release repository?
PRE_BUILD = '' # commands to perform prior to build, such as `npm install && bower install`
BUILD_CMD = '' # distribution build command, such as `grunt build:dist`

task :default => ['list']

desc "List all Rake tasks, even those not exposed to rake -T"
task :list do
  puts "Tasks:\n  #{(Rake::Task.tasks - [Rake::Task[:list]]).join("\n  ")}"
  puts "(type rake -T for exposed tasks and their usage)\n\n"
end

# Script loader for rake tasks defined in ./tasks/rake/*.rake files
Dir['tasks/rake/*.rake'].each { |r| load r }
```

### Using `rake bump`

The grunt-bump package requires an additional configuration be added to your Gruntfile:

```js
bump: {
  options: {
    files: [
      'package.json',
      'bower.json'
    ],
    commit: true,
    commitMessage: '%VERSION% bump', // can use %VERSION%
    commitFiles: ['-a'], // '-a' for all files
    createTag: false,
    push: true,
    pushTo: 'origin'
  }
}
```

## Release Workflow

Caveats before running the tasks:

1. Ensure you have a clean repository state (no uncommitted changes, staged or unstaged).
2. Make sure you're on the `master` branch.

Rake tasks for creating a release:

1. `rake release:bump['versiontype']` (**optional**)
    - Bump the project version and commit, versiontype can be one of three options; assuming the version is currently 0.0.1:
        * `patch` would bump to 0.0.2
        * `minor` would bump to 0.1.0
        * `major` would bump to 1.0.0
2. `rake release:noffmerge`
    - Creates a no-fast-forward merge from `master` into `stable` of the development repository; as such, all subsequent tasks will be run against the stable branch.
3. `rake release:clean`
    - Clear any temporary files related to previous releases or release attempts.
4. `rake release:prepare`
    - Does all the heavy lifting.
5. `rake release:diff` (**optional**)
    - Review what's going to be added.
6. `rake release:add`
    - Add all files to the release.
7. `rake release:deploy['X.Y.Z','codename']`
    - Commit, push, tag. Optionally, this task can take an additional argument to supply metadata to the tagging mechanism. For example: `rake release:deploy['X.Y.Z','codename','SHA']` would result in a tag being created according to SEMVER specifications, such as: `X.Y.Z-codename+SHA`

At any time during the release process, you may check the git status of the release using `rake release:status`.

Also, all of the release commands can be run in succession with a single command chain:

`rake release:bump['versiontype']; rake release:noffmerge; rake release:clean; rake release:prepare; rake release:add; rake release:deploy['X.Y.Z','codename']`

Once the release tasks have been run, the final step is a manual one where Releases are created on GitHub.

For each release, both the working and release repository will need the following steps completed:

1. Go to the "Releases" area for the repository you're releasing;
   - for the working repository, click on the latest version tag created by the release process, then click the "Edit tag" button
   - for the release repository, click the "Draft a new release" button
2. Enter the following:
    - **Tag version:** `X.Y.Z-codename`
    - **Target:** if present, leave this set to master
    - **Release title:**
        * If pushing new release: *Release X.Y.Z, codename "codename"*
        * If patching previous release: *Release X.Y.Z, patching "codename"*
    - **Description:** this is where release notes should go, preferably in Markdown format
    - Optionally check the box for pre-release
3. Click "Publish release"

These steps will tag master/HEAD of the release repository with the release tag, thus creating a URL for the release; example:

https://github.com/foo/bar/releases/tag/X.Y.Z-codename

This is the URL that should be sent in the release announcement to external teams.
