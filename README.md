# THIS GEM IS A WORK IN PROGRESS
# Scalingo backups manager

This gem allow to download backups of multiple scalingo applications and addons in order to be restore in local database or be send to an SFTP server

## TODO

- Mysql
- Postgresql

## Installation

Add this line to your application's Gemfile (not hosted on Rubygems):

```ruby
gem 'scalingo_backups_manager', git: "https://github.com/9troisquarts/scalingo_backups_manager"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install scalingo_backups_manager

## Usage

In order to use this gem, you need to define an environment variable named SCALINGO_API_TOKEN which can be created on your [scalingo profile](https://dashboard-prev.osc-fr1.scalingo.com/profile)

`bundle exec scalingo_backups_manager`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/scalingo_backups_manager. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/scalingo_backups_manager/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ScalingoBackupsManager project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/scalingo_backups_manager/blob/master/CODE_OF_CONDUCT.md).
