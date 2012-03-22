require File.expand_path('test_helper', File.dirname(__FILE__))
require File.expand_path('model_factory', File.dirname(__FILE__))

module SharedPageBehaviour
  include ModelFactory
  include ModelMatchers

  def create_page(options)
    super(options.merge(:ext => @extension))
  end

  def page_in_category?(page, category)
    page.categories.map { |c| c.path }.include?(category)
  end

  before do
    stub_configuration
  end
  
  after do
    remove_temp_directory
    Nesta::FileModel.purge_cache
  end
  
  a 'page' do
    it 'should be returned by #find_all' do
      create_page(:heading => 'Apple', :path => 'the-apple')
      assert_equal 1, Nesta::Page.find_all.size
    end

    it 'should be findable by path' do
      create_page(:heading => 'Banana', :path => 'banana')
      # TODO: compare page objects
      assert_equal 'Banana', Nesta::Page.find_by_path('banana').heading
    end

    it 'should find index page by path' do
      create_page(:heading => 'Banana', :path => 'banana/index')
      # TODO: compare page objects
      assert_equal 'Banana', Nesta::Page.find_by_path('banana').heading
    end

    it 'should respond to #parse_metadata, returning hash of key/value' do
      page = create_page(:heading => 'Banana', :path => 'banana')
      metadata = page.parse_metadata('My key: some value')
      assert_equal 'some value', metadata['my key']
    end

    it 'should be parseable if metadata is invalid' do
      dodgy_metadata = "Key: value\nKey without value\nAnother key: value"
      create_page(:heading => 'Banana', :path => 'banana') do |path|
        text = File.read(path)
        File.open(path, 'w') do |file|
          file.puts(dodgy_metadata)
          file.write(text)
        end
      end
      Nesta::Page.find_by_path('banana')
    end
  end

  the 'home page' do
    it 'should set title to heading and site title' do
      create_page(:heading => 'Home', :path => 'index')
      assert_equal 'Home - My blog', Nesta::Page.find_by_path('/').title
    end

    it 'should respect title metadata' do
      create_page(:path => 'index', :metadata => { 'title' => 'Specific title' })
      assert_equal 'Specific title', Nesta::Page.find_by_path('/').title
    end

    it 'should set title to site title by default' do
      create_page(:path => 'index')
      assert_equal 'My blog', Nesta::Page.find_by_path('/').title
    end

    it 'should set permalink to empty string' do
      create_page(:path => 'index')
      assert_equal '', Nesta::Page.find_by_path('/').permalink
    end

    it 'should set abspath to /' do
      create_page(:path => 'index')
      assert_equal '/', Nesta::Page.find_by_path('/').abspath
    end
  end

    it 'should not find nonexistent page' do
      assert Nesta::Page.find_by_path('no-such-page').nil?, 'should be nil'
    end

    it 'should ensure file exists on instantiation' do
      assert_raises(Sinatra::NotFound) { Nesta::Page.new('no-such-file') }
    end

    it 'should reload cached files when modified' do
      create_page(:path => 'a-page', :heading => 'Version 1')
      File.stub!(:mtime).and_return(Time.new - 1)
      Nesta::Page.find_by_path('a-page')
      create_page(:path => 'a-page', :heading => 'Version 2')
      File.stub!(:mtime).and_return(Time.new)
      assert_equal 'Version 2', Nesta::Page.find_by_path('a-page').heading
    end

    it 'should have default priority of 0 in category' do
      page = create_page(:metadata => { 'categories' => 'some-page' })
      assert_equal 0, page.priority('some-page')
      assert page.priority('another-page').nil?, 'should be nil'
    end

    it 'should read priority from category metadata' do
      page = create_page(:metadata => {
        'categories' => ' some-page:1, another-page , and-another :-1 '
      })
      assert_equal 1, page.priority('some-page')
      assert_equal 0, page.priority('another-page')
      assert_equal -1, page.priority('and-another')
    end

    the 'with assigned pages' do
      before do
        @category = create_category
        create_article(:heading => 'Article 1', :path => 'article-1')
        create_article(
          :heading => 'Article 2',
          :path => 'article-2',
          :metadata => {
          'date' => '30 December 2008',
          'categories' => @category.path
        }
        )
        @article = create_article(
          :heading => 'Article 3',
          :path => 'article-3',
          :metadata => {
          'date' => '31 December 2008',
          'categories' => @category.path
        }
        )
        @category1 = create_category(
          :path => 'category-1',
          :heading => 'Category 1',
          :metadata => { 'categories' => @category.path }
        )
        @category2 = create_category(
          :path => 'category-2',
          :heading => 'Category 2',
          :metadata => { 'categories' => @category.path }
        )
        @category3 = create_category(
          :path => 'category-3',
          :heading => 'Category 3',
          :metadata => { 'categories' => "#{@category.path}:1" }
        )
      end

      it "should find articles" do
        assert_equal 2, @category.articles.size
      end

      it "should order articles by reverse chronological order" do
        assert_equal @article.path, @category.articles.first.path
      end

      it "should find pages" do
        assert_equal 3, @category.pages.size
      end

      it "should sort pages by priority" do
        assert_equal 0, @category.pages.index(@category3)
      end

      it "should order pages by heading if priority not set" do
        pages = @category.pages
        assert pages.index(@category1) < pages.index(@category2)
      end

      it "should not find pages scheduled in the future" do
        future_date = (Time.now + 172800).strftime("%d %B %Y")
        article = create_article(:heading => "Article 4",
                                 :path => "foo/article-4",
                                 :metadata => { "date" => future_date })
        found = Nesta::Page.find_articles.detect{|a| a == article}
        assert found.nil?, 'should be nil'
      end
    end

    the "with pages in draft" do
      before do
        @category = create_category
        @draft = create_page(:heading => 'Forthcoming content',
                             :path => 'foo/in-draft',
                             :metadata => {
          'categories' => @category.path,
          'flags' => 'draft'
        })
        Nesta::App.stub!(:production?).and_return(true)
      end

      it_eventually "should not find assigned drafts" do
        refute_includes @category.pages, @draft
      end

      it "should not find drafts by path" do
        assert_nil Nesta::Page.find_by_path('foo/in-draft')
      end
    end

    the "when finding articles" do
      before do
        create_article(:heading => "Article 1", :path => "article-1")
        create_article(:heading => "Article 2",
                       :path => "article-2",
                       :metadata => { "date" => "31 December 2008" })
        create_article(:heading => "Article 3",
                       :path => "foo/article-3",
                       :metadata => { "date" => "30 December 2008" })
      end

      it "should only find pages with dates" do
        articles = Nesta::Page.find_articles
        assert articles.size > 0
        Nesta::Page.find_articles.each { |page| refute_nil page.date }
      end

      it "should return articles in reverse chronological order" do
        article1, article2 = Nesta::Page.find_articles[0..1]
        assert article1.date > article2.date
      end
    end

    it "should be able to find parent page" do
      category = create_category(:path => 'parent')
      article = create_article(:path => 'parent/child')
      assert_equal category, article.parent
    end

    the "(with deep index page)" do
      it "should be able to find index parent" do
        home = create_category(:path => 'index', :heading => 'Home')
        category = create_category(:path => 'parent')
        assert_equal home, category.parent
        assert home.parent.nil?, 'should be nil'
      end

      it "should be able to find parent of index" do
        category = create_category(:path => "parent")
        index = create_category(:path => "parent/child/index")
        assert_equal category, index.parent
      end

      it "should be able to find permalink of index" do
        index = create_category(:path => "parent/child/index")
        assert_equal 'child', index.permalink
      end
    end

    the "(with missing nested page)" do
      it "should consider grandparent to be parent" do
        grandparent = create_category(:path => 'grandparent')
        child = create_category(:path => 'grandparent/parent/child')
        assert_equal grandparent, child.parent
      end

      it "should consider grandparent home page to be parent" do
        home = create_category(:path => 'index')
        child = create_category(:path => 'parent/child')
        assert_equal home, child.parent
      end
    end

    and_also 'assigned to categories' do
      before do
        create_category(:heading => 'Apple', :path => 'the-apple')
        create_category(:heading => 'Banana', :path => 'banana')
        @article = create_article(
          :metadata => { 'categories' => 'banana, the-apple' })
      end

      it 'should be possible to list the categories' do
        assert_equal 2, @article.categories.size
        assert page_in_category?(@article, 'the-apple')
        assert page_in_category?(@article, 'banana')
      end

      it 'should sort categories by heading' do
        assert_equal "Apple", @article.categories.first.heading
      end

      it "should not be assigned to non-existant category" do
        delete_page(:category, "banana", @extension)
        flunk 'should not be in category' if page_in_category?(@article, 'banana')
      end
    end

    it "should set parent to nil when at root" do
      assert create_category(:path => "top-level").parent.nil?, 'should be nil'
    end

    the "when not assigned to category" do
      it "should have empty category list" do
        article = create_article
        categories = Nesta::Page.find_by_path(article.path).categories
        assert categories.empty?, 'should be empty'
      end
    end

    the "with no content" do
      it "should produce no HTML output" do
        create_article do |path|
          file = File.open(path, 'w')
          file.close
        end
        html = Nesta::Page.find_all.first.to_html
        assert_match /^\s*$/, html, 'should match /^\s*$/'
      end
    end

    the "without metadata" do
      before do
        create_article
        @article = Nesta::Page.find_all.first
      end

      it "should use default layout" do
        assert_equal :layout, @article.layout
      end

      it "should use default template" do
        assert_equal :page, @article.template
      end

      it_eventually "should parse heading correctly" do
        @article.to_html.should have_tag("h1", "My article")
      end

      it "should have default read more link text" do
        assert_equal "Continue reading", @article.read_more
      end

      it "should not have description" do
        assert @article.description.nil?, 'should be nil'
      end

      it "should not have keywords" do
        assert @article.keywords.nil?, 'should be nil'
      end
    end

    the "with metadata" do
      before do
        @layout = 'my_layout'
        @template = 'my_template'
        @date = '07 September 2009'
        @keywords = 'things, stuff'
        @description = 'Page about stuff'
        @summary = 'Multiline\n\nsummary'
        @read_more = 'Continue at your leisure'
        @skillz = 'ruby, guitar, bowstaff'
        @article = create_article(:metadata => {
          'date' => @date.gsub('September', 'Sep'),
          'description' => @description,
          'flags' => 'draft, orange',
          'keywords' => @keywords,
          'layout' => @layout,
          'read more' => @read_more,
          'skillz' => @skillz,
          'summary' => @summary,
          'template' => @template
        })
      end

      it "should override default layout" do
        assert_equal @layout.to_sym, @article.layout
      end

      it "should override default template" do
        assert_equal @template.to_sym, @article.template
      end

      it "should set permalink to basename of filename" do
        assert_equal 'my-article', @article.permalink
      end

      it "should set path from filename" do
        assert_equal 'article-prefix/my-article', @article.path
      end

      it "should retrieve heading" do
        assert_equal 'My article', @article.heading
      end

      it_eventually "should be possible to convert an article to HTML" do
        @article.to_html.should have_tag("h1", "My article")
      end

      it_eventually "should not include metadata in the HTML" do
        @article.to_html.should_not have_tag("p", /^Date/)
      end

      it_eventually "should not include heading in body markup" do
        refute_includes @article.body_markup, "My article"
      end

      it_eventually "should not include heading in body" do
        @article.body.should_not have_tag("h1", "My article")
      end

      it "should retrieve description from metadata" do
        assert_equal @description, @article.description
      end

      it "should retrieve keywords from metadata" do
        assert_equal @keywords, @article.keywords
      end

      it "should retrieve date published from metadata" do
        assert_equal @date, @article.date.strftime("%d %B %Y")
      end

      it "should retrieve read more link from metadata" do
        assert_equal @read_more, @article.read_more
      end

      it "should retrieve summary text from metadata" do
        assert_match /#{@summary.split('\n\n').first}/, @article.summary
      end

      it "should treat double newline chars as paragraph break in summary" do
        assert_match /#{@summary.split('\n\n').last}/, @article.summary
      end

      it "should allow access to metadata" do
        assert_equal @skillz, @article.metadata('skillz')
      end

      it "should allow access to flags" do
        assert @article.flagged_as?('draft')
        assert @article.flagged_as?('orange')
      end

      it "should know whether or not it's a draft" do
        assert @article.draft?, 'should be draft'
      end
    end

    the "when checking last modification time" do
      before do
        create_article
        @article = Nesta::Page.find_all.first
      end

      it "should check filesystem" do
        mock_file_stat(:should_receive, @article.filename, "3 January 2009")
        assert_equal Time.parse("3 January 2009"), @article.last_modified
      end
    end
  end
end

class AllTypesOfPageTest < MiniTest::Unit::TestCase
  include ModelFactory

  before do
    stub_configuration
  end
  
  after do
    remove_temp_directory
    Nesta::FileModel.purge_cache
  end
  
  it 'should still return top level menu items' do
    # Page.menu_items is deprecated; we're keeping it for the moment so
    # that we don't break themes or code in a local app.rb (just yet).
    page1 = create_category(:path => 'page-1')
    page2 = create_category(:path => 'page-2')
    create_menu([page1.path, page2.path].join("\n"))
    assert_equal [page1, page2], Nesta::Page.menu_items
  end
end

class MarkdownPageTest < MiniTest::Unit::TestCase
  include SharedPageBehaviour

  before do
    @extension = :mdown
  end

  it 'should set heading from first h1 tag' do
    page = create_page(
      :heading => 'First heading', :content => '# Second heading')
    assert_equal 'First heading', page.heading
  end

  it 'should ignore trailing # characters in headings' do
    article = create_article(:heading => 'With trailing #')
    assert_equal 'With trailing', article.heading
  end
end

class HamlPageTest < MiniTest::Unit::TestCase
  include SharedPageBehaviour

  before do
    @extension = :haml
  end

  it 'should set heading from first h1 tag' do
    page = create_page(
      :path => 'a-page',
      :heading => 'First heading',
      :content => '%h1 Second heading'
    )
    assert_equal 'First heading', page.heading
  end

  it 'should wrap <p> tags around one line summary text' do
    page = create_page(
      :path => 'a-page',
      :heading => 'First para',
      :metadata => { 'Summary' => 'Wrap me' }
    )
    assert_includes page.summary, '<p>Wrap me</p>'
  end

  it 'should wrap <p> tags around multiple lines of summary text' do
    page = create_page(
      :path => 'a-page',
      :heading => 'First para',
      :metadata => { 'Summary' => 'Wrap me\nIn paragraph tags' }
    )
    assert_includes page.summary, '<p>Wrap me</p>'
    assert_includes page.summary, '<p>In paragraph tags</p>'
  end
end

class TextilePageTest < MiniTest::Unit::TestCase
  include SharedPageBehaviour

  before do
    @extension = :textile
  end

  it 'should set heading from first h1 tag' do
    page = create_page(
      :path => 'a-page',
      :heading => 'First heading',
      :content => 'h1. Second heading'
    )
    assert_equal 'First heading', page.heading
  end
end

class MenuTest < MiniTest::Unit::TestCase
  include ModelFactory

  before do
    stub_configuration
    @page = create_page(:path => 'page-1')
  end

  after do
    remove_temp_directory
    Nesta::FileModel.purge_cache
  end

  it 'should find top level menu items' do
    text = [@page.path, 'no-such-page'].join("\n")
    create_menu(text)
    assert_equal [@page], Nesta::Menu.top_level
  end

  it 'should find all items in the menu' do
    create_menu(@page.path)
    assert_equal [@page], Nesta::Menu.full_menu
    assert_equal [@page], Nesta::Menu.for_path('/')
  end

  the 'with nested sub menus' do
    before do
      (2..6).each do |i|
        instance_variable_set("@page#{i}", create_page(:path => "page-#{i}"))
      end
      text = <<-EOF
#{@page.path}
  #{@page2.path}
    #{@page3.path}
    #{@page4.path}
#{@page5.path}
  #{@page6.path}
      EOF
      create_menu(text)
    end

    it 'should return top level menu items' do
      assert_equal [@page, @page5], Nesta::Menu.top_level
    end

    it 'should return full tree of menu items' do
      expected = [@page, [@page2, [@page3, @page4]], @page5, [@page6]]
      assert_equal expected, Nesta::Menu.full_menu
    end

    it 'should return part of the tree of menu items' do
      assert_equal [@page2, [@page3, @page4]], Nesta::Menu.for_path(@page2.path)
    end

    it "should deem menu for path that isn't in menu to be nil" do
      assert Nesta::Menu.for_path('wibble').nil?, 'should be nil'
    end
  end
end
