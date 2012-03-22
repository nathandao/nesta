require 'minitest/unit'
require 'mocha'
require 'nutrasuite'

MiniTest::Unit.autorun

module ConfigStubs
  def stub_yaml_config
    @config = {}
    Nesta::Config.stub!(:yaml_exists?).and_return(true)
    Nesta::Config.stub!(:yaml_conf).and_return(@config)
  end

  def stub_config_key(key, value, options = {})
    stub_yaml_config unless @config
    if options[:rack_env]
      @config['test'] ||= {}
      @config['test'][key] = value
    else
      @config[key] = value
    end
  end
  
  def stub_configuration(options = {})
    stub_config_key('title', 'My blog', options)
    stub_config_key('subtitle', 'about stuff', options)
    stub_config_key(
        'content', temp_path('content'), options.merge(:rack_env => true))
  end
end

module TempFileHelper
  TEMP_DIR = File.expand_path('tmp', File.dirname(__FILE__))

  def create_temp_directory
    FileUtils.mkdir_p(TempFileHelper::TEMP_DIR)
  end

  def remove_temp_directory
    FileUtils.rm_r(TempFileHelper::TEMP_DIR, :force => true)
  end
  
  def temp_path(base)
    File.join(TempFileHelper::TEMP_DIR, base)
  end
end
