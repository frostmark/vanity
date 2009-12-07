$LOAD_PATH.delete_if { |path| path[/gems\/vanity-\d/] }
$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
RAILS_ROOT = File.expand_path("..")
require "test/unit"
require "mocha"
require "action_controller"
require "action_controller/test_case"
require "active_record"
require "initializer"
require "lib/vanity/rails"
require "timecop"


if $VERBOSE
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::DEBUG
else
  $logger = Logger.new("/dev/null")
end

class Test::Unit::TestCase

  def setup
    FileUtils.mkpath "tmp/experiments/metrics"
    new_playground
  end

  # Call this on teardown. It wipes put the playground and any state held in it
  # (mostly experiments), resets vanity ID, and clears Redis of all experiments.
  def nuke_playground
    new_playground
    Vanity.playground.redis.flushdb
  end

  # Call this if you need a new playground, e.g. to re-define the same experiment,
  # or reload an experiment (saved by the previous playground).
  def new_playground
    Vanity.playground = Vanity::Playground.new(:logger=>$logger, :load_path=>"tmp/experiments", :db=>15)
    Vanity.playground.mock! unless ENV["REDIS"]
  end

  # Defines the specified metrics (one or more names).  Returns metric, or array
  # of metric (if more than one argument).
  def metric(*names)
    metrics = names.map do |name|
      id = name.to_s.downcase.gsub(/\W+/, '_').to_sym
      Vanity.playground.metrics[id] ||= Vanity::Metric.new(Vanity.playground, name)
    end
    names.size == 1 ? metrics.first : metrics
  end
  
  def teardown
    Vanity.context = nil
    FileUtils.rm_rf "tmp"
    Vanity.playground.redis.flushdb
  end

end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end
Rails.configuration = Rails::Configuration.new

ActiveRecord::Base.logger = $logger
ActiveRecord::Base.establish_connection :adapter=>"sqlite3", :database=>File.expand_path("database.sqlite")

class Array
  # Not in Ruby 1.8.6.
  unless method_defined?(:shuffle)
    def shuffle
      copy = clone
      Array.new(size) { copy.delete_at(Kernel.rand(copy.size)) } 
    end
  end
end
