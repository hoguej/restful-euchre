source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.3'

gem 'bootsnap', '>= 1.4.4', require: false
gem 'puma', '~> 6.0'
gem 'rails', '~> 8.0.2'
gem 'sqlite3', '~> 2.2'

# CORS removed - not needed for API-only mode in development

group :development, :test do
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'simplecov', require: false      # Code coverage
end

group :development do
  gem 'brakeman', require: false       # Security scanner
  gem 'importmap-rails'                # Asset pipeline management
  gem 'rubocop', require: false        # Code style checker
end
