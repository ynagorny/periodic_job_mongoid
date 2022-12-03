# frozen_string_literal: true

require_relative "lib/periodic_job_mongoid/version"

Gem::Specification.new do |spec|
  spec.name = "periodic_job_mongoid"
  spec.version = PeriodicJob::VERSION
  spec.authors = ["Yurie Nagorny"]
  spec.email = ["ynagorny@bearincorp.com"]

  spec.summary = "Coordinate and run periodic background jobs for a distributed application built using Mongoid ODM for MongoDB."
  spec.description = <<EOS
Periodic Job helps you run jobs with a time interval between runs. You may have several copies of your Periodic Job process running (e.g. as part of an application server cluster) and they will coordinate their work with help of a collection stored in a shared MongoDB database to avoid duplicate runs of a job.
EOS
  spec.homepage = "https://github.com/ynagorny/periodic_job_mongoid"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ynagorny/periodic_job_mongoid"
  spec.metadata["changelog_uri"] = "https://github.com/ynagorny/periodic_job_mongoid/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mongoid", "~> 7.4"
end
