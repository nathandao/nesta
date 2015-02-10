require File.expand_path('../spec_helper', File.dirname(__FILE__))
require File.expand_path('../../lib/nesta/commands', File.dirname(__FILE__))

describe "nesta:theme" do
  include_context "temporary working directory"

  describe "install" do
    before(:each) do
      @repo_url = 'git://github.com/gma/nesta-theme-mine.git'
      @theme_dir = 'themes/mine'
      FileUtils.mkdir_p(File.join(@theme_dir, '.git'))
      @command = Nesta::Commands::Theme::Install.new(@repo_url)
      @command.stub(:enable)
      @command.stub(:run_process)
    end

    after(:each) do
      FileUtils.rm_r(@theme_dir)
    end

    it "should clone the repository" do
      @command.should_receive(:run_process).with(
          'git', 'clone', @repo_url, @theme_dir)
      @command.execute
    end

    it "should remove the theme's .git directory" do
      @command.execute
      File.exist?(@theme_dir).should be_true
      File.exist?(File.join(@theme_dir, '.git')).should be_false
    end

    it "should enable the freshly installed theme" do
      @command.should_receive(:enable)
      @command.execute
    end

    describe "when theme URL doesn't match recommended pattern" do
      before(:each) do
        @repo_url = 'git://foobar.com/path/to/mytheme.git'
        @other_theme_dir = 'themes/mytheme'
        FileUtils.mkdir_p(File.join(@other_theme_dir, '.git'))
        @command = Nesta::Commands::Theme::Install.new(@repo_url)
        @command.stub(:enable)
      end

      after(:each) do
        FileUtils.rm_r(@other_theme_dir)
      end

      it "should use the basename as theme dir" do
        @command.should_receive(:run_process).with(
            'git', 'clone', @repo_url, @other_theme_dir)
        @command.execute
      end
    end
  end

  describe "enable" do
    before(:each) do
      config = temp_path('config.yml')
      Nesta::Config.stub(:yaml_path).and_return(config)
      @name = 'mytheme'
      @command = Nesta::Commands::Theme::Enable.new(@name)
    end

    shared_examples_for "command that configures the theme" do
      it "should enable the theme" do
        @command.execute
        File.read(Nesta::Config.yaml_path).should match(/^theme: #{@name}/)
      end
    end

    describe "when theme config is commented out" do
      before(:each) do
        create_config_yaml('  # theme: blah')
      end

      it_should_behave_like "command that configures the theme"
    end

    describe "when another theme is configured" do
      before(:each) do
        create_config_yaml('theme: another')
      end

      it_should_behave_like "command that configures the theme"
    end

    describe "when no theme config exists" do
      before(:each) do
        create_config_yaml('# I have no theme config')
      end

      it_should_behave_like "command that configures the theme"
    end
  end

  describe "create" do
    def should_exist(file)
      File.exist?(Nesta::Path.themes(@name, file)).should be_true
    end

    before(:each) do
      Nesta::App.stub(:root).and_return(TempFileHelper::TEMP_DIR)
      @name = 'my-new-theme'
      Nesta::Commands::Theme::Create.new(@name).execute
    end

    it "should create the theme directory" do
      File.directory?(Nesta::Path.themes(@name)).should be_true
    end

    it "should create a dummy README file" do
      should_exist('README.md')
      text = File.read(Nesta::Path.themes(@name, 'README.md'))
      text.should match(/#{@name} is a theme/)
    end

    it "should create a default app.rb file" do
      should_exist('app.rb')
    end

    it "should create public and views directories" do
      should_exist("public/#{@name}")
      should_exist('views')
    end

    it "should copy the default view templates into views" do
      %w(layout.haml page.haml master.sass).each do |file|
        should_exist("views/#{file}")
      end
    end
  end
end
