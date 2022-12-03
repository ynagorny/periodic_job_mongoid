# Periodic Job for Mongoid

Periodic Job executes jobs with a specified interval between runs. If you have several application servers, they will coordinate their work so that only one of the servers will run a job when the time comes to run the job. The coordination is done with help of the collection **periodic_job_checkpoints** in MongoDB database.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add periodic_job_mongoid

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install periodic_job_mongoid

## Usage

### Basic Usage

Create an instance of **PeriodicJob::Scheduler**, define jobs, and then run scheduler's **#tick** method periodically:

```ruby
require 'periodic_job_mongoid'

scheduler = PeriodicJob::Scheduler.new

scheduler.every 30.seconds, :foo do
  Foo.work
end

scheduler.every 1.minute, :bar do
  Bar.work
end

loop do
  sleep 1.second
  scheduler.tick 
end
```

In the above example when **scheduler#tick** is called, **Foo#work** will be executed after the initial 30 seconds pass, and then it will be called again 30 seconds **_after_** the point in time when **Foo#work** completes. **Bar#work** will be executed similarly, but with 1 minute gaps.

The first argument to **#every** is how much time should pass between block executions. So if **Foo#work** takes 10 seconds to complete, effectively it will be called every 40 seconds.

The second argument to **#every** (**:foo** and **:bar** above) are job IDs. If you have several instances of Periodic Job schedulers running, only one block passed to **#every** will be executed for a given job ID when the time comes for the job to run. This will be true regardless of whether the Priodic Job schedulers run in the same or different processes, and on the same or different machines as long as they share the same MongoDB database.  

Only one job will be executed at a time per process regardless of job ID. If a job is due to run but another one is running, it will be delayed until the previous job completes. Having multiple processes with Periodic Job (for example if you have several application servers) will allow running jobs with differed IDs in parallel, but still only one per process.

Obviously the above example is not production ready (who wants infinite loops in their code). Later on you will find a more realistic example.

### Before and After hooks

You may define hooks that are executed before or after each job run:

```ruby
scheduler.before do |job_id|
  puts "Before #{job_id}"
end

scheduler.before do |job_id|
  puts "After #{job_id}"
end
```

Before and after hooks should be defined before you make calls to **#every**.

You can have only one before and one after hook per scheduler.

### Common error handler

If a job raises an exception, you may intercept it in a shared error handler:

```ruby
scheduler.error_handler do |e, job_id|
  Rails.logger.error "Error in job #{job_id}: #{e.message}"
end
```

Error handler hooks should be defined before you make calls to **#every**.

You can have only one error handler per scheduler.

### All together now

Here's an example using all mentioned above:

```ruby
require 'periodic_job_mongoid'

@start = Time.now

def timestamp(string)
  printf "%.3f: %s\n", Time.now - @start, string
end

scheduler = PeriodicJob::Scheduler.new

scheduler.before do |job_id|
  timestamp "Before #{job_id}"
end

scheduler.after do |job_id|
  timestamp "After #{job_id}"
end

scheduler.error_handler do |e, job_id|
  timestamp "Error in #{job_id}: #{e.message}"
end

counter = Hash.new 0

scheduler.every 10.seconds, :foo do
  counter[:foo] += 1
  timestamp "Start foo, run #: #{counter[:foo]}"
  raise "Foo failed" if counter[:foo] % 5 == 0
  sleep 2
  timestamp "End foo, run #: #{counter[:foo]}"
end

scheduler.every 15.seconds, :bar do
  counter[:bar] += 1
  timestamp "Start bar, run #: #{counter[:bar]}"
  sleep 4
  timestamp "End bar, run #: #{counter[:bar]}"
end

timestamp "Start"

loop do
  sleep 1.second
  scheduler.tick 
end
```

Here's the output produced:

```text
0.225: Start
10.603: Before foo
10.603: Start foo, run #: 1
12.603: End foo, run #: 1
12.603: After foo
16.189: Before bar
16.189: Start bar, run #: 1
20.190: End bar, run #: 1
20.190: After bar
23.365: Before foo
23.365: Start foo, run #: 2
25.365: End foo, run #: 2
25.365: After foo
35.810: Before foo
35.810: Start foo, run #: 3
37.811: End foo, run #: 3
37.811: After foo
37.937: Before bar
37.937: Start bar, run #: 2
41.937: End bar, run #: 2
41.937: After bar
48.000: Before foo
48.000: Start foo, run #: 4
50.001: End foo, run #: 4
50.001: After foo
57.088: Before bar
57.088: Start bar, run #: 3
61.088: End bar, run #: 3
61.088: After bar
62.252: Before foo
62.252: Start foo, run #: 5
62.252: Error in foo: Foo failed
62.252: After foo
72.433: Before foo
72.433: Start foo, run #: 6
74.433: End foo, run #: 6
74.433: After foo
76.474: Before bar
76.474: Start bar, run #: 4
80.475: End bar, run #: 4
80.475: After bar
^C
```

### A more realistic example

Below is a more realistic example of using PeriodicJob, this time in a background process of a Ruby on Rails application managed by systemd on linux.

```ruby
#!/usr/bin/env -S rails runner

# it will run until it receives signal TERM

# Customize process title
Process.setproctitle 'periodic_job'

# make sure STDOUT/ERR are not buffered
$stdout.sync = true
$stderr.sync = true

require 'periodic_job_mongoid'

scheduler = PeriodicJob::Scheduler.new

scheduler.error_handler do |e, job_id|
  Rails.logger.error "Periodic Job #{job_id}: #{e.message}"
  Rails.logger.error e.backtrace.join "\n"
end

scheduler.before do |job_id|
  # run before every job
end

scheduler.after do |job_id|
  # run after every job
end

scheduler.every 30.seconds, :job_a do |job_id|
  # do work here 
end

# ...

$running = true
Signal.trap "TERM" do
  $running = false
end

while $running do
  sleep 1.second
  scheduler.tick
end
```

A systemd unit file that you may use to run the process for a rails application (assuming the above script is in **script/periodic_jobs**)

```
[Unit]
Description = Periodic Job process
After = syslog.target network.target

[Service]
Type = simple
User = <user under which your rails app runs>
WorkingDirectory = <path to your rails app>
Environment = RAILS_ENV=production

ExecStart = /bin/bash -lc 'bundle exec --keep-file-descriptors rails runner script/periodoc_jobs'

KillSignal = SIGTERM

Restart = always
RestartSec = 10

StandardOutput = syslog
StandardError = syslog
SyslogIdentifier = priodic_job
SyslogFacility = local7

[Install]
WantedBy = multi-user.target
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/periodic_job_mongoid.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
