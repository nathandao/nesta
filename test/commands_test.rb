require 'test_helper'
require File.expand_path('../lib/nesta/commands', File.dirname(__FILE__))

class NestaCommandTest < MiniTest::Unit::TestCase
  include TempFileHelper

  before do
    create_temp_directory
    @project_path = temp_path('mysite.com')
  end
  
  after do
    remove_temp_directory
  end
  
  def project_path(path)
    File.join(@project_path, path)
  end

  def should_exist(file)
    File.exist?(project_path(file)).should be_true
  end

  def create_config_yaml(text)
    File.open(Nesta::Config.yaml_path, 'w') { |f| f.puts(text) }
  end

  a 'new command' do
    def gemfile_source
      File.read(project_path('Gemfile'))
    end

    def rakefile_source
      File.read(project_path('Rakefile'))
    end

    that 'has no options' do
      before do
        Nesta::Commands::New.new(@project_path).execute
      end

      it 'should create the content directories' do
        should_exist('content/attachments')
        should_exist('content/pages')
      end

      it 'should create the home page' do
        should_exist('content/pages/index.haml')
      end

      it 'should create the rackup file' do
        should_exist('config.ru')
      end

      it 'should create the config.yml file' do
        should_exist('config/config.yml')
      end

      it 'should add a Gemfile' do
        should_exist('Gemfile')
        gemfile_source.should match(/gem 'nesta', '#{Nesta::VERSION}'/)
      end
    end

    that 'is called with --git' do
      before do
        @command = Nesta::Commands::New.new(@project_path, 'git' => '')
        @command.stubs(:system)
      end

      it 'should create a .gitignore file' do
        @command.execute
        File.read(project_path('.gitignore')).should match(/\.bundle/)
      end

      it 'should create a git repo' do
        @command.should_receive(:system).with('git', 'init')
        @command.execute
      end

      it 'should commit the blank project' do
        @command.should_receive(:system).with('git', 'add', '.')
        @command.should_receive(:system).with(
            'git', 'commit', '-m', 'Initial commit')
        @command.execute
      end
    end

    that 'is called with --vlad' do
      before do
        Nesta::Commands::New.new(@project_path, 'vlad' => '').execute
      end

      it 'should add vlad to Gemfile' do
        gemfile_source.should match(/gem 'vlad', '2.1.0'/)
        gemfile_source.should match(/gem 'vlad-git', '2.2.0'/)
      end

      it 'should configure the vlad rake tasks' do
        should_exist('Rakefile')
        rakefile_source.should match(/require 'vlad'/)
      end

      it 'should create deploy.rb' do
        should_exist('config/deploy.rb')
        deploy_source = File.read(project_path('config/deploy.rb'))
        deploy_source.should match(/set :application, 'mysite.com'/)
      end
    end
  end

  # the 'demo:content command' do
    # before do
      # @config_path = project_path('config/config.yml')
      # FileUtils.mkdir_p(File.dirname(@config_path))
      # Nesta::Config.stubs(:yaml_path).returns(@config_path)
      # create_config_yaml('content: path/to/content')
      # Nesta::App.stubs(:root).returns(@project_path)
      # @repo_url = 'git://github.com/gma/nesta-demo-content.git'
      # @demo_path = project_path('content-demo')
      # @command = Nesta::Commands::Demo::Content.new
      # @command.stubs(:system)
    # end

    # it 'should clone the repository' do
      # @command.should_receive(:system).with(
          # 'git', 'clone', @repo_url, @demo_path)
      # @command.execute
    # end

    # it 'should configure the content directory' do
      # @command.execute
      # File.read(@config_path).should match(/^content: content-demo/)
    # end

    # and_also 'when repository exists' do
      # before do
        # FileUtils.mkdir_p(@demo_path)
      # end

      # it 'should update the repository' do
        # @command.should_receive(:system).with('git', 'pull', 'origin', 'master')
        # @command.execute
      # end
    # end

    # and_also 'when site versioned with git' do
      # before do
        # @exclude_path = project_path('.git/info/exclude')
        # FileUtils.mkdir_p(File.dirname(@exclude_path))
        # File.open(@exclude_path, 'w') { |file| file.puts '# Excludes' }
      # end

      # it 'should tell git to ignore content-demo' do
        # @command.execute
        # File.read(@exclude_path).should match(/content-demo/)
      # end

      # and_also 'content-demo ignored' do
        # before do
          # File.open(@exclude_path, 'w') { |file| file.puts 'content-demo' }
        # end

        # it "shouldn't tell git to ignore it twice" do
          # @command.execute
          # File.read(@exclude_path).scan('content-demo').size.should == 1
        # end
      # end
    # end
  # end

  # the 'edit command' do
    # before do
      # Nesta::Config.stubs(:content_path).returns('content')
      # @page_path = 'path/to/page.mdown'
      # @command = Nesta::Commands::Edit.new(@page_path)
      # @command.stubs(:system)
    # end

    # it 'should launch the editor' do
      # ENV['EDITOR'] = 'vi'
      # full_path = File.join('content/pages', @page_path)
      # @command.should_receive(:system).with(ENV['EDITOR'], full_path)
      # @command.execute
    # end

    # it 'should not try and launch an editor if environment not setup' do
      # ENV.delete('EDITOR')
      # @command.should_not_receive(:system)
      # $stderr.stubs(:puts)
      # @command.execute
    # end
  # end

  # the 'plugin:create command' do
    # before do
      # @name = 'my-feature'
      # @gem_name = "nesta-plugin-#{@name}"
      # @plugins_path = temp_path('plugins')
      # @working_dir = Dir.pwd
      # Dir.mkdir(@plugins_path)
      # Dir.chdir(@plugins_path)
      # @command = Nesta::Commands::Plugin::Create.new(@name)
      # @command.stubs(:system)
    # end

    # after do
      # Dir.chdir(@working_dir)
      # FileUtils.rm_r(@plugins_path)
    # end

    # it 'should create a new gem prefixed with nesta-plugin' do
      # @command.should_receive(:system).with('bundle', 'gem', @gem_name)
      # begin
        # @command.execute
      # rescue Errno::ENOENT
        # # This test is only concerned with running bundle gem; ENOENT
        # # errors are raised because we didn't create a real gem.
      # end
    # end

    # and_also 'after gem created' do
      # def create_gem_file(*components)
        # path = File.join(@plugins_path, @gem_name, *components)
        # FileUtils.makedirs(File.dirname(path))
        # File.open(path, 'w') { |f| yield f if block_given? }
        # path
      # end

      # before do
        # @required_file = create_gem_file('lib', "#{@gem_name}.rb")
        # @init_file = create_gem_file('lib', @gem_name, 'init.rb')
        # @gem_spec = create_gem_file("#{@gem_name}.gemspec") do |file|
          # file.puts '  # specify any dependencies here; for example:'
          # file.puts 'end'
        # end
      # end

      # after do
        # FileUtils.rm(@required_file)
        # FileUtils.rm(@init_file)
      # end

      # it 'should create the ruby file loaded on require' do
        # @command.execute
        # File.read(@required_file).should include('Plugin.register(__FILE__)')
      # end

      # it 'should create a default init.rb file' do
        # @command.execute
        # init = File.read(@init_file)
        # boilerplate = <<-EOF
    # module My::Feature
      # module Helpers
        # EOF
        # init.should include(boilerplate)
        # init.should include('helpers Nesta::Plugin::My::Feature::Helpers')
      # end

      # it "should specify plugin gem's dependencies" do
        # @command.execute
        # text = File.read(@gem_spec)
        # text.should include('s.add_dependency("nesta", ">= 0.9.11")')
        # text.should include('s.add_development_dependency("rake")')
      # end
    # end
  # end

  # the 'theme:install command' do
    # before do
      # @repo_url = 'git://github.com/gma/nesta-theme-mine.git'
      # @theme_dir = 'themes/mine'
      # FileUtils.mkdir_p(File.join(@theme_dir, '.git'))
      # @command = Nesta::Commands::Theme::Install.new(@repo_url)
      # @command.stubs(:enable)
      # @command.stubs(:system)
    # end

    # after do
      # FileUtils.rm_r(@theme_dir)
    # end

    # it 'should clone the repository' do
      # @command.should_receive(:system).with(
          # 'git', 'clone', @repo_url, @theme_dir)
      # @command.execute
    # end

    # it "should remove the theme's .git directory" do
      # @command.execute
      # File.exist?(@theme_dir).should be_true
      # File.exist?(File.join(@theme_dir, '.git')).should be_false
    # end

    # it 'should enable the freshly installed theme' do
      # @command.should_receive(:enable)
      # @command.execute
    # end

    # the "theme URL doesn't match recommended pattern" do
      # before do
        # @repo_url = 'git://foobar.com/path/to/mytheme.git'
        # @other_theme_dir = 'themes/mytheme'
        # FileUtils.mkdir_p(File.join(@other_theme_dir, '.git'))
        # @command = Nesta::Commands::Theme::Install.new(@repo_url)
        # @command.stubs(:enable)
      # end

      # after do
        # FileUtils.rm_r(@other_theme_dir)
      # end

      # it "should use the basename as theme dir" do
        # @command.should_receive(:system).with(
            # 'git', 'clone', @repo_url, @other_theme_dir)
        # @command.execute
      # end
    # end
  # end

  # the 'theme:enable command' do
    # before do
      # config = temp_path('config.yml')
      # Nesta::Config.stubs(:yaml_path).returns(config)
      # @name = 'mytheme'
      # @command = Nesta::Commands::Theme::Enable.new(@name)
    # end

    # def self.should_enable_theme
      # it 'should enable the theme' do
        # @command.execute
        # File.read(Nesta::Config.yaml_path).should match(/^theme: #{@name}/)
      # end
    # end

    # and_also 'theme config is commented out' do
      # before do
        # create_config_yaml('  # theme: blah')
      # end

      # should_enable_theme
    # end

    # and_also 'another theme is configured' do
      # before do
        # create_config_yaml('theme: another')
      # end

      # should_enable_theme
    # end

    # and_also 'no theme config exists' do
      # before do
        # create_config_yaml('# I have no theme config')
      # end

      # should_enable_theme
    # end
  # end

  # and_also 'theme:create' do
    # def should_exist(file)
      # File.exist?(Nesta::Path.themes(@name, file)).should be_true
    # end

    # before do
      # Nesta::App.stubs(:root).returns(TempFileHelper::TEMP_DIR)
      # @name = 'my-new-theme'
      # Nesta::Commands::Theme::Create.new(@name).execute
    # end

    # it 'should create the theme directory' do
      # File.directory?(Nesta::Path.themes(@name)).should be_true
    # end

    # it 'should create a dummy README file' do
      # should_exist('README.md')
      # text = File.read(Nesta::Path.themes(@name, 'README.md'))
      # text.should match(/#{@name} is a theme/)
    # end

    # it 'should create a default app.rb file' do
      # should_exist('app.rb')
    # end

    # it 'should create public and view directories' do
      # should_exist("public/#{@name}")
      # should_exist('views')
    # end
  # end
end
