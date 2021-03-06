# encoding: UTF-8
require 'test_helper'

class GovspeakHelperTest < ActionView::TestCase
  include PublicDocumentRoutesHelper

  setup do
    @request  = ActionController::TestRequest.new
    ActionController::Base.default_url_options = {}
  end
  attr_reader :request

  test "should not alter urls to other sites" do
    html = govspeak_to_html("no [change](http://external.example.com/page.html)")
    assert_select_within_html html, "a[href=?]", "http://external.example.com/page.html", text: "change"
  end

  test "should not alter mailto urls" do
    html = govspeak_to_html("no [change](mailto:dave@example.com)")
    assert_select_within_html html, "a[href=?]", "mailto:dave@example.com", text: "change"
  end

  test "should not alter invalid urls" do
    html = govspeak_to_html("no [change](not a valid url)")
    assert_select_within_html html, "a[href=?]", "not a valid url", text: "change"
  end

  test "should not alter partial urls" do
    html = govspeak_to_html("no [change](http://)")
    assert_select_within_html html, "a[href=?]", "http://", text: "change"
  end

  test "should wrap output with a govspeak class" do
    html = govspeak_to_html("govspeak-text")
    assert_select_within_html html, ".govspeak", text: "govspeak-text"
  end

  test "should mark the govspeak output as html safe" do
    html = govspeak_to_html("govspeak-text")
    assert html.html_safe?
  end

  test "should produce UTF-8 for HTML entities" do
    html = govspeak_to_html("a ['funny'](/url) thing")
    assert_select_within_html html, "a", text: "‘funny’"
  end

  test "should not mark admin links as 'external'" do
    request.host = public_preview_host
    speech = create(:published_speech)
    url = admin_speech_url(speech, host: request.host)
    govspeak = "this and [that](#{url}) yeah?"
    html = govspeak_to_html(govspeak)
    refute_select_within_html html, "a[rel='external']", text: "that"
  end

  test "should not mark public preview links as 'external'" do
    speech = create(:published_speech)
    url = admin_speech_url(speech, host: public_preview_host)
    govspeak = "this and [that](#{url}) yeah?"
    html = govspeak_to_html(govspeak)
    refute_select_within_html html, "a[rel='external']", text: "that"
  end

  test "should not mark main site links as 'external'" do
    speech = create(:published_speech)
    url = admin_speech_url(speech, host: public_production_host)
    govspeak = "this and [that](#{url}) yeah?"
    html = govspeak_to_html(govspeak)
    refute_select_within_html html, "a[rel='external']", text: "that"
  end

  test "should allow attached images to be embedded in public html" do
    images = [OpenStruct.new(alt_text: "My Alt", url: "http://example.com/image.jpg")]
    html = govspeak_to_html("!!1", images)
    assert_select_within_html html, ".govspeak figure.image.embedded img"
  end

  test "should only extract level two headers by default" do
    text = "# Heading 1\n\n## Heading 2\n\n### Heading 3"
    headers = govspeak_headers(text)
    assert_equal [Govspeak::Header.new("Heading 2", 2, "heading-2")], headers
  end

  test "should extract header hierarchy from level 2+3 headings" do
    text = "# Heading 1\n\n## Heading 2a\n\n### Heading 3a\n\n### Heading 3b\n\n#### Ignored heading\n\n## Heading 2b"
    headers = govspeak_header_hierarchy(text)
    assert_equal [
      {
        header: Govspeak::Header.new("Heading 2a", 2, "heading-2a"),
        children: [
          Govspeak::Header.new("Heading 3a", 3, "heading-3a"),
          Govspeak::Header.new("Heading 3b", 3, "heading-3b")
        ]
      },
      {
        header: Govspeak::Header.new("Heading 2b", 2, "heading-2b"),
        children: []
      }
    ], headers
  end

  test "should raise exception when extracting header hierarchy with orphaned level 3 headings" do
    e = assert_raises(OrphanedHeadingError) { govspeak_header_hierarchy("### Heading 3") }
    assert_equal "Heading 3", e.heading
  end

  test "should convert single document to govspeak" do
    document = create(:published_policy, body: "## test")
    html = govspeak_edition_to_html(document)
    assert_select_within_html html, "h2"
  end

  test "should optionally not wrap output in a govspeak class" do
    document = create(:published_policy, body: "govspeak-text")
    html = bare_govspeak_edition_to_html(document)
    assert_select_within_html html, ".govspeak", false
    assert_select_within_html html, "p", "govspeak-text"
  end

  test "should add inline attachments" do
    text = "#Heading\n\n!@1\n\n##Subheading"
    document = create(:published_detailed_guide, :with_attachment, body: text)
    html = govspeak_edition_to_html(document)
    assert_select_within_html html, "h1"
    assert_select_within_html html, ".attachment.embedded"
    assert_select_within_html html, "h2"
  end

  test "should ignore missing attachments" do
    text = "#Heading\n\n!@2\n\n##Subheading"
    document = create(:published_detailed_guide, :with_attachment, body: text)
    html = govspeak_edition_to_html(document)
    assert_select_within_html html, "h1"
    refute_select_within_html html, ".attachment.embedded"
    assert_select_within_html html, "h2"
  end

  test "should not convert documents with no attachments" do
    text = "#Heading\n\n!@2"
    document = create(:published_detailed_guide, body: text)
    html = govspeak_edition_to_html(document)
    refute_select_within_html html, ".attachment.embedded"
  end

  test "should convert multiple attachments" do
    text = "#heading\n\n!@1\n\n!@2"
    attachment_1 = create(:attachment)
    attachment_2 = create(:attachment)
    document = create(:published_detailed_guide, :with_attachment, body: text, attachments: [attachment_1, attachment_2])
    html = govspeak_edition_to_html(document)
    assert_select_within_html html, "#attachment_#{attachment_1.id}"
    assert_select_within_html html, "#attachment_#{attachment_2.id}"
  end

  test "should not escape embedded attachment when attachment embed code only separated by one newline from a previous paragraph" do
    text = "para\n!@1"
    document = create(:published_detailed_guide, :with_attachment, body: text)
    html = govspeak_edition_to_html(document)
    refute html.include?("&lt;div"), "should not escape embedded attachment"
    assert_select_within_html html, ".attachment.embedded"
  end

  test "should identify internal admin links" do
    assert is_internal_admin_link?( [Whitehall.router_prefix, "admin", "test"].join("/") )
    refute is_internal_admin_link?( 'http://www.google.com/' )
    refute is_internal_admin_link?( nil )
  end

  test "prefixes embedded image urls with asset host if present" do
    Whitehall.stubs(:asset_host).returns("https://some.cdn.com")
    edition = build(:published_news_article, body: "!!1")
    edition.stubs(:images).returns([OpenStruct.new(alt_text: "My Alt", url: "/image.jpg")])
    html = govspeak_edition_to_html(edition)
    assert_select_within_html html, ".govspeak figure.image.embedded img[src=https://some.cdn.com/image.jpg]"
  end

  test "does not prefix embedded attachment urls with asset host so that access to them can be authenticated when previewing draft documents" do
    Whitehall.stubs(:asset_host).returns("https://some.cdn.com")
    edition = build(:published_publication, :with_attachment, body: "!@1")
    html = govspeak_edition_to_html(edition)
    assert_select_within_html html, ".govspeak .attachment.embedded a[href^='/'][href$='greenpaper.pdf']"
  end

  test "should remove extra quotes from blockquote text" do
    remover = stub("remover");
    remover.expects(:remove).returns("remover return value")
    Whitehall::ExtraQuoteRemover.stubs(:new).returns(remover)
    edition = build(:published_publication, body: %{He said:\n> "I'm not sure what you mean!"\nOr so we thought.})
    assert_match /remover return value/, govspeak_edition_to_html(edition)
  end

  private

  def internal_preview_host
    "whitehall.preview.alphagov.co.uk"
  end

  def public_preview_host
    "www.preview.alphagov.co.uk"
  end

  def internal_production_host
    "whitehall.production.alphagov.co.uk"
  end

  def public_production_host
    "www.gov.uk"
  end
end
