source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

gem 'rails', '~> 8.0.2'
gem 'sqlite3', '~> 2.2'
gem 'puma', '~> 6.0'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'image_processing', '~> 1.2'

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem 'rack-cors'

group :development, :test do
  gem 'debug', platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem 'listen', '~> 3.3'
  gem 'spring'
end 