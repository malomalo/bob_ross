require 'bundler/setup'
require "bundler/gem_tasks"
Bundler.require(:development)

require 'fileutils'
require "rake/testtask"

BACKENDS = %w(libvips imagemagick)

namespace :test do
  BACKENDS.each do |backend|
    Rake::TestTask.new(backend => "#{backend}:setup") do |t|
        t.libs << 'lib' << 'test'
        t.test_files = FileList[ARGV[1] ? ARGV[1] : 'test/**/*_test.rb']
        t.warning = false
        t.verbose = true
    end
    
    namespace backend do
      task(:setup) { ENV["BOBROSS_BACKEND"] = backend }
    end
  end
  
  desc "Run test with all backends"
  task all: BACKENDS.shuffle.map{ |e| "test:#{e}" }
end

task test: "test:all"