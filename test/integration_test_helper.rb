require 'test_helper'
require 'rack/test'
require 'sinatra/base'

class MiniTest::Unit::TestCase
  include Rack::Test::Methods
end

module Nesta
  class App < Sinatra::Base
    set :environment, :test
    set :reload_templates, true
  end
end

require File.expand_path('../lib/nesta/env', File.dirname(__FILE__))
require File.expand_path('../lib/nesta/app', File.dirname(__FILE__))

module RequestSpecHelper
  def app
    Nesta::App
  end
  
  def body
    last_response.body
  end
end
