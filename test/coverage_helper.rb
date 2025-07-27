# Coverage helper - must be loaded before application code
if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.start 'rails' do
    # Exclude files that don't need coverage tracking
    add_filter '/test/'
    add_filter '/config/'
    add_filter '/vendor/'
    add_filter '/db/'
    add_filter '/bin/'
    add_filter '/coverage/'

    # Track coverage for the main app directories
    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Views', 'app/views'
    add_group 'Libraries', 'lib'

    # Don't fail on coverage threshold - just report
    # Coverage reporting will happen at exit
  end

  # Print coverage summary in the format expected by gap script
  SimpleCov.at_exit do
    SimpleCov.result # Force result calculation
    coverage_percentage = SimpleCov.result.covered_percent.round(2)
    puts "\n" + '=' * 50
    puts 'COVERAGE SUMMARY'
    puts '=' * 50
    puts "Line Coverage: #{coverage_percentage}%"
    puts '=' * 50
  end
end
