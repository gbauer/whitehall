# encoding: utf-8

require "test_helper"

class PublicationsControllerTest < ActionController::TestCase
  include ActionDispatch::Routing::UrlFor
  include PublicDocumentRoutesHelper
  default_url_options[:host] = 'test.host'

  should_be_a_public_facing_controller
  should_display_attachments_for :publication
  should_show_the_world_locations_associated_with :publication
  should_display_inline_images_for :publication
  should_show_change_notes :publication
  should_show_inapplicable_nations :publication
  should_show_related_policies_for :publication
  should_be_previewable :publication
  should_paginate :publication, timestamp_key: :publication_date
  should_paginate :consultation, timestamp_key: :opening_on
  should_return_json_suitable_for_the_document_filter :publication
  should_return_json_suitable_for_the_document_filter :consultation

  test 'show displays published publications' do
    published_publication = create(:published_publication)
    get :show, id: published_publication.document
    assert_response :success
  end

  test "renders the publication summary from plain text" do
    publication = create(:published_publication, summary: 'plain text & so on')
    get :show, id: publication.document

    assert_select ".extra-description", text: "plain text &amp; so on"
  end

  test "show renders the publication body using govspeak" do
    publication = create(:published_publication, body: "body-in-govspeak")
    govspeak_transformation_fixture "body-in-govspeak" => "body-in-html" do
      get :show, id: publication.document
    end

    assert_select ".body", text: "body-in-html"
  end

  test "show should not explicitly say that publication applies to the whole of the UK" do
    published_publication = create(:published_publication)

    get :show, id: published_publication.document

    refute_select inapplicable_nations_selector
  end

  test "show should display publication metadata" do
    publication = create(:published_publication,
      publication_date: Date.parse("1916-05-31"),
      publication_type_id: PublicationType::Form.id
    )

    get :show, id: publication.document

    assert_select ".label", text: /Form/
    assert_select ".change-notes .published-at", text: "31 May 1916"
  end

  def assert_featured(doc)
    assert_select "#{record_css_selector(doc)}.featured"
  end

  test "show should display a National Statistic badge on the appropriate documents" do
    publication = create(:published_publication, publication_type_id: PublicationType::NationalStatistics.id)
    get :show, id: publication.document

    assert_match /National Statistic/, response.body
  end

  test "show not link policies to national statistics publications" do
    publication = create(:published_publication, publication_type_id: PublicationType::NationalStatistics.id, related_policies: [create(:published_policy)])
    get :show, id: publication.document

    refute_select ".policies"
  end

  test "show not link policies to general statistics publications" do
    publication = create(:published_publication, publication_type_id: PublicationType::Statistics.id, related_policies: [create(:published_policy)])
    get :show, id: publication.document

    refute_select ".policies"
  end

  test "show should show ministers linked to publications" do
    minister = create(:ministerial_role)
    publication = create(:published_publication, ministerial_roles: [minister])
    get :show, id: publication.document

    assert_select_object minister
  end

  test "show not link ministers to national statistics publications" do
    minister = create(:ministerial_role)
    publication = create(:published_publication, publication_type_id: PublicationType::NationalStatistics.id, ministerial_roles: [minister])
    get :show, id: publication.document

    refute_select_object minister
  end

  test "show not link ministers to general statistics publications" do
    minister = create(:ministerial_role)
    publication = create(:published_publication, publication_type_id: PublicationType::Statistics.id, ministerial_roles: [minister])
    get :show, id: publication.document

    refute_select_object minister
  end

  test "index only displays *published* publications" do
    archived_publication = create(:archived_publication)
    published_publication = create(:published_publication)
    draft_publication = create(:draft_publication)
    get :index

    assert_select_object(published_publication)
    refute_select_object(archived_publication)
    refute_select_object(draft_publication)
  end

  test "index only displays *published* consultations" do
    archived_consultation = create(:archived_consultation)
    published_consultation = create(:published_consultation)
    draft_consultation = create(:draft_consultation)
    get :index

    assert_select_object(published_consultation)
    refute_select_object(archived_consultation)
    refute_select_object(draft_consultation)
  end

  test 'index should not use n+1 selects for publications' do
    15.times { create(:published_publication) }
    number_of_queries = count_queries { get :index }
    assert number_of_queries < 15
  end

  test "index sets Cache-Control: max-age to the time of the next scheduled publication" do
    user = login_as(:departmental_editor)
    publication = create(:draft_publication, scheduled_publication: Time.zone.now + Whitehall.default_cache_max_age * 2)
    publication.schedule_as(user, force: true)

    Timecop.freeze(Time.zone.now + Whitehall.default_cache_max_age * 1.5) do
      get :index
    end

    assert_cache_control("max-age=#{Whitehall.default_cache_max_age/2}")
  end

  test 'index should not use n+1 selects for consultations with outcomes' do
    15.times do
      consultation = create(:published_consultation, opening_on: Date.new(2011, 5, 1), closing_on: Date.new(2011, 7, 1))
      response = consultation.create_response!
      response.attachments << build(:attachment)
    end
    number_of_queries = count_queries { get :index }
    assert number_of_queries < 17
  end

  test "index highlights selected topic filter options" do
    given_two_documents_in_two_topics

    get :index, topics: [@topic_1, @topic_2]

    assert_select "select[name='topics[]']" do
      assert_select "option[selected='selected']", text: @topic_1.name
      assert_select "option[selected='selected']", text: @topic_2.name
    end
  end

  test "index highlights selected organisation filter options" do
    given_two_documents_in_two_organisations

    get :index, departments: [@organisation_1, @organisation_2]

    assert_select "select[name='departments[]']" do
      assert_select "option[selected='selected']", text: @organisation_1.name
      assert_select "option[selected='selected']", text: @organisation_2.name
    end
  end

  test "index highlights selected publication type filter options" do
    get :index, publication_filter_option: "forms"

    assert_select "select[name='publication_filter_option']" do
      assert_select "option[selected='selected']", text: Whitehall::PublicationFilterOption::Form.label
    end
  end

  test "index displays filter keywords" do
    get :index, keywords: "olympics 2012"

    assert_select "input[name='keywords'][value=?]", "olympics 2012"
  end

  test "index displays selected date filter" do
    get :index, direction: "before", date: "2010-01-01"

    assert_select "input#direction_before[name='direction'][checked=checked]"
    assert_select "select[name='date']" do
      assert_select "option[selected='selected'][value=?]", "2010-01-01"
    end
  end

  test "index orders publications by publication date by default" do
    publications = 5.times.map {|i| create(:published_publication, publication_date: (10 - i).days.ago) }

    get :index

    assert_equal "publication_#{publications.last.id}", css_select(".filter-results .document-row").first['id']
    assert_equal "publication_#{publications.first.id}", css_select(".filter-results .document-row").last['id']
  end

  test "index orders consultations by first_published_at date by default" do
    consultations = 5.times.map {|i| create(:published_consultation, opening_on: (10 - i).days.ago) }

    get :index

    assert_equal "consultation_#{consultations.last.id}", css_select(".filter-results .document-row").first['id']
    assert_equal "consultation_#{consultations.first.id}", css_select(".filter-results .document-row").last['id']
  end

  test "index orders documents by appropriate timestamp by default" do
    documents = [
      consultation = create(:published_consultation, opening_on: 5.days.ago),
      publication = create(:published_publication, publication_date: 4.days.ago)
    ]

    get :index

    assert_equal "publication_#{publication.id}", css_select(".filter-results .document-row").first['id']
    assert_equal "consultation_#{consultation.id}", css_select(".filter-results .document-row").last['id']
  end

  test "index highlights all topics filter option by default" do
    given_two_documents_in_two_topics

    get :index

    assert_select "select[name='topics[]']" do
      assert_select "option[selected='selected']", text: "All topics"
    end
  end

  test "index highlights all organisations filter options by default" do
    given_two_documents_in_two_organisations

    get :index

    assert_select "select[name='departments[]']" do
      assert_select "option[selected='selected']", text: "All departments"
    end
  end

  test "index shows filter keywords placeholder by default" do
    get :index

    assert_select "input[name='keywords'][placeholder=?]", "keywords"
  end

  test "index does not select a date filter by default" do
    get :index

    assert_select "select[name='date']" do
      refute_select "option[selected='selected']"
    end
  end

  test "index should show a helpful message if there are no matching publications" do
    get :index

    assert_select "h2", text: "There are no matching publications."
  end

  test "index requested as JSON includes data for publications" do
    org = create(:organisation, name: "org-name")
    org2 = create(:organisation, name: "other-org")
    publication = create(:published_publication, title: "publication-title",
                         organisations: [org, org2],
                         publication_date: Date.parse("2012-03-14"),
                         publication_type: PublicationType::CorporateReport)

    get :index, format: :json

    results = ActiveSupport::JSON.decode(response.body)["results"]
    assert_equal 1, results.length
    json = results.first
    assert_equal "publication", json["type"]
    assert_equal "publication-title", json["title"]
    assert_equal publication.id, json["id"]
    assert_equal publication_path(publication.document), json["url"]
    assert_equal "org-name and other-org", json["organisations"]
    assert_equal %{<abbr class="publication_date" title="2012-03-14">14 March 2012</abbr>}, json["publication_date"]
    assert_equal "Corporate report", json["publication_type"]
  end

  test "index requested as JSON includes data for consultations" do
    org = create(:organisation, name: "org-name")
    org2 = create(:organisation, name: "other-org")
    consultation = create(:published_consultation, title: "consultation-title",
                         organisations: [org, org2],
                         opening_on: Time.zone.parse("2012-03-14"),
                         closing_on: Time.zone.parse("2012-03-15"))

    get :index, format: :json

    results = ActiveSupport::JSON.decode(response.body)["results"]
    assert_equal 1, results.length
    json = results.first
    assert_equal "consultation", json["type"]
    assert_equal "consultation-title", json["title"]
    assert_equal consultation.id, json["id"]
    assert_equal consultation_path(consultation.document), json["url"]
    assert_equal "org-name and other-org", json["organisations"]
    assert_equal %{<abbr class="timestamp_for_sorting" title="2012-03-14T00:00:00+00:00">14 March 2012</abbr>}, json["publication_date"]
    assert_equal "Consultation", json["publication_type"]
  end

  test "index requested as JSON includes URL to the atom feed including any filters" do
    create(:topic, name: "topic-1")
    create(:organisation, name: "organisation-1")

    get :index, format: :json, topics: ["topic-1"], departments: ["organisation-1"]

    json = ActiveSupport::JSON.decode(response.body)

    assert_equal json["atom_feed_url"], publications_url(format: "atom", topics: ["topic-1"], departments: ["organisation-1"])
  end

  test "index requested as JSON includes atom feed URL without date parameters" do
    create(:topic, name: "topic-1")

    get :index, format: :json, date: "2012-01-01", direction: "before", topics: ["topic-1"]

    json = ActiveSupport::JSON.decode(response.body)

    assert_equal json["atom_feed_url"], publications_url(format: "atom", topics: ["topic-1"])
  end

  test 'index has atom feed autodiscovery link' do
    get :index
    assert_select_autodiscovery_link publications_url(format: "atom")
  end

  test 'index atom feed autodiscovery link includes any present filters' do
    topic = create(:topic)
    organisation = create(:organisation)

    get :index, topics: [topic], departments: [organisation]

    assert_select_autodiscovery_link publications_url(format: "atom", topics: [topic], departments: [organisation])
  end

  test 'index atom feed autodiscovery link does not include date filter' do
    topic = create(:topic)

    get :index, topics: [topic], date: "2012-01-01", direction: "after"

    assert_select_autodiscovery_link publications_url(format: "atom", topics: [topic])
  end

  test 'index shows a link to the atom feed including any present filters' do
    topic = create(:topic)
    organisation = create(:organisation)

    get :index, topics: [topic], departments: [organisation]

    feed_url = ERB::Util.html_escape(publications_url(format: "atom", topics: [topic], departments: [organisation]))
    assert_select "a.feed[href=?]", feed_url
  end

  test 'index shows a link to the atom feed without any date filters' do
    organisation = create(:organisation)

    get :index, date: "2012-01-01", direction: "before", departments: [organisation]

    feed_url = ERB::Util.html_escape(publications_url(format: "atom", departments: [organisation]))
    assert_select "a.feed[href=?]", feed_url
  end

  test "index generates an atom feed for the current filter" do
    org = create(:organisation, name: "org-name")

    get :index, format: :atom, departments: [org.to_param]

    assert_select_atom_feed do
      assert_select 'feed > id', 1
      assert_select 'feed > title', 1
      assert_select 'feed > author, feed > entry > author'
      assert_select 'feed > updated', 1
      assert_select 'feed > link[rel=?][type=?][href=?]', 'self', 'application/atom+xml',
                    publications_url(format: :atom, departments: [org.to_param]), 1
      assert_select 'feed > link[rel=?][type=?][href=?]', 'alternate', 'text/html', root_url, 1
    end
  end

  test "index generates an atom feed entries for publications matching the current filter" do
    org = create(:organisation, name: "org-name")
    other_org = create(:organisation, name: "other-org")
    p1 = create(:published_publication, organisations: [org], publication_date: 2.days.ago)
    c1 = create(:published_consultation, organisations: [org], opening_on: 1.day.ago)
    p2 = create(:published_publication, organisations: [other_org])

    get :index, format: :atom, departments: [org.to_param]

    assert_select_atom_feed do
      assert_select 'feed > entry', count: 2 do |entries|
        entries.zip([c1, p1]).each do |entry, document|
          assert_select entry, 'entry > id', 1
          assert_select entry, 'entry > published', count: 1, text: document.timestamp_for_sorting.iso8601
          assert_select entry, 'entry > updated', count: 1, text: document.timestamp_for_update.iso8601
          assert_select entry, 'entry > link[rel=?][type=?][href=?]', 'alternate', 'text/html', public_document_url(document)
          assert_select entry, 'entry > title', count: 1, text: document.title
          assert_select entry, 'entry > summary', count: 1, text: document.summary
          assert_select entry, 'entry > category', count: 1, text: document.display_type
          assert_select entry, 'entry > content[type=?]', 'html', count: 1, text: /#{document.body}/
        end
      end
    end
  end

  test "index generates an atom feed with sumamry content and prefixed title entries for publications matching the current filter when requested" do
    org = create(:organisation, name: "org-name")
    other_org = create(:organisation, name: "other-org")
    p1 = create(:published_publication, organisations: [org], publication_date: 2.days.ago)
    c1 = create(:published_consultation, organisations: [org], opening_on: 1.day.ago)
    p2 = create(:published_publication, organisations: [other_org])

    get :index, format: :atom, departments: [org.to_param], govdelivery_version: 'yes'

    assert_select_atom_feed do
      assert_select 'feed > entry', count: 2 do |entries|
        entries.zip([c1, p1]).each do |entry, document|
          assert_select entry, 'entry > id', 1
          assert_select entry, 'entry > published', count: 1, text: document.timestamp_for_sorting.iso8601
          assert_select entry, 'entry > updated', count: 1, text: document.timestamp_for_update.iso8601
          assert_select entry, 'entry > link[rel=?][type=?][href=?]', 'alternate', 'text/html', public_document_url(document)
          assert_select entry, 'entry > title', count: 1, text: "#{document.display_type}: #{document.title}"
          assert_select entry, 'entry > summary', count: 1, text: document.summary
          assert_select entry, 'entry > category', count: 1, text: document.display_type
          assert_select entry, 'entry > content[type=?]', 'text', count: 1, text: document.summary
        end
      end
    end
  end

  test "index generates an atom feed entries for consultations matching the current filter" do
    org = create(:organisation, name: "org-name")
    other_org = create(:organisation, name: "other-org")
    create(:published_consultation, organisations: [org])
    create(:published_consultation, organisations: [other_org])

    get :index, format: :atom, departments: [org.to_param]

    assert_select_atom_feed do
      assert_select 'feed > entry', count: 1 do |entries|
        entries.each do |entry|
          assert_select entry, 'entry > id', 1
          assert_select entry, 'entry > published', 1
          assert_select entry, 'entry > updated', 1
          assert_select entry, 'entry > link[rel=?][type=?]', 'alternate', 'text/html', 1
          assert_select entry, 'entry > title', 1
          assert_select entry, 'entry > content[type=?]', 'html', 1
        end
      end
    end
  end

  test 'index atom feed orders publications according to publication_date (newest first)' do
    oldest = create(:published_publication, published_at: 1.days.ago, publication_date: 5.days.ago, title: "oldest")
    newest = create(:published_publication, published_at: 5.days.ago, publication_date: 1.days.ago, title: "newest")
    middle = create(:published_publication, published_at: 8.days.ago, publication_date: 3.days.ago, title: "middle")

    get :index, format: :atom

    assert_select_atom_feed do
      assert_select 'feed > entry' do |entries|
        entries.zip([newest, middle, oldest]).each do |entry, document|
          assert_select entry, 'entry > title', text: document.title
        end
      end
    end
  end

  test 'index atom feed orders consultations according to opening_on (newest first)' do
    oldest = create(:published_consultation, published_at: 1.days.ago, opening_on: 5.days.ago, title: "oldest")
    newest = create(:published_consultation, published_at: 5.days.ago, opening_on: 1.days.ago, title: "newest")
    middle = create(:published_consultation, published_at: 8.days.ago, opening_on: 3.days.ago, title: "middle")

    get :index, format: :atom

    assert_select_atom_feed do
      assert_select 'feed > updated', newest.timestamp_for_update.iso8601
      assert_select 'feed > entry' do |entries|
        entries.zip([newest, middle, oldest]).each do |entry, document|
          assert_select entry, 'entry > title', text: document.title
          assert_select entry, 'entry > published', text: document.timestamp_for_sorting.iso8601
        end
      end
    end
  end

  test 'index atom feed orders mixed publications and consultations according to publication_date or opening_on (newest first)' do
    oldest = create(:published_publication, published_at: 1.days.ago, publication_date: 5.days.ago, title: "oldest")
    newest = create(:published_consultation, published_at: 5.days.ago, opening_on: 1.days.ago, title: "newest")
    middle = create(:published_publication, published_at: 8.days.ago, publication_date: 3.days.ago, title: "middle")

    get :index, format: :atom

    assert_select_atom_feed do
      assert_select 'feed > entry' do |entries|
        entries.zip([newest, middle, oldest]).each do |entry, document|
          assert_select entry, 'entry > title', text: document.title
        end
      end
    end
  end

  test 'index atom feed should return a valid feed if there are no matching documents' do
    get :index, format: :atom

    assert_select_atom_feed do
      assert_select 'feed > updated', text: Time.zone.now.iso8601
      assert_select 'feed > entry', count: 0
    end
  end

  test 'index atom feed should include links to download attachments' do
    publication = create(:published_publication, :with_attachment, title: "publication-title",
                         body: "include the attachment:\n\n!@1")

    get :index, format: :atom

    assert_select_atom_feed do
      assert_select 'feed > entry' do
        assert_select "content" do |content|
          assert content[0].to_s.include?(publication.attachments.first.url), "escaped publication body should include link to attachment"
        end
      end
    end
  end

  test 'index should show relevant document series information' do
    organisation = create(:organisation)
    series = create(:document_series, organisation: organisation)
    publication = create(:published_publication, document_series: series)

    get :index

    assert_select_object(publication) do
      assert_select ".publication_series a[href=?]", organisation_document_series_path(organisation, series)
    end
  end

  test 'index requested as JSON includes document series information' do
    organisation = create(:organisation)
    series = create(:document_series, organisation: organisation)
    publication = create(:published_publication, document_series: series)

    get :index, format: :json

    json = ActiveSupport::JSON.decode(response.body)

    result = json['results'].first

    assert_equal "Part of a series: <a href=\"#{organisation_document_series_path(organisation, series)}\">#{series.name}</a>", result['publication_series']
  end

  test "show displays the ISBN of the attached document" do
    attachment = create(:attachment, isbn: '0099532816')
    edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

    get :show, id: edition.document

    assert_select_object(attachment) do
      assert_select ".isbn", "0099532816"
    end
  end

  test "show doesn't display an empty ISBN if none exists for the attachment" do
    [nil, ""].each do |isbn|
      attachment = create(:attachment, isbn: isbn)
      edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

      get :show, id: edition.document

      assert_select_object(attachment) do
        refute_select ".isbn"
      end
    end
  end

  test "show displays the Unique Reference Number of the attached document" do
    attachment = create(:attachment, unique_reference: 'unique-reference')
    edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

    get :show, id: edition.document

    assert_select_object(attachment) do
      assert_select ".unique_reference", "unique-reference"
    end
  end

  test "show doesn't display an empty Unique Reference Number if none exists for the attachment" do
    [nil, ""].each do |unique_reference|
      attachment = create(:attachment, unique_reference: unique_reference)
      edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

      get :show, id: edition.document

      assert_select_object(attachment) do
        refute_select ".unique_reference"
      end
    end
  end

  test "show displays the Command Paper number of the attached document" do
    attachment = create(:attachment, command_paper_number: 'Cm. 1234')
    edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

    get :show, id: edition.document

    assert_select_object(attachment) do
      assert_select ".command_paper_number", "Cm. 1234"
    end
  end

  test "show doesn't display an empty Command Paper number if none exists for the attachment" do
    [nil, ""].each do |command_paper_number|
      attachment = create(:attachment, command_paper_number: command_paper_number)
      edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

      get :show, id: edition.document

      assert_select_object(attachment) do
        refute_select ".command_paper_number"
      end
    end
  end

  test "show links to the url that the attachment can be ordered from" do
    attachment = create(:attachment, order_url: 'http://example.com/order-path')
    edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

    get :show, id: edition.document

    assert_select_object(attachment) do
      assert_select ".order_url", /order a copy/i
    end
  end

  test "show doesn't display an empty order url if none exists for the attachment" do
    [nil, ""].each do |order_url|
      attachment = create(:attachment, order_url: order_url)
      edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

      get :show, id: edition.document

      assert_select_object(attachment) do
        refute_select ".order_url"
      end
    end
  end

  test "show displays the price of the purchasable attachment" do
    attachment = create(:attachment, price: "1.23", order_url: 'http://example.com')
    edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

    get :show, id: edition.document

    assert_select_object(attachment) do
      assert_select ".price", text: "£1.23"
    end
  end

  test "show doesn't display an empty price if none exists for the attachment" do
    [nil, ""].each do |price|
      attachment = create(:attachment, price_in_pence: price)
      edition = create("published_publication", :with_attachment, body: "!@1", attachments: [attachment])

      get :show, id: edition.document

      assert_select_object(attachment) do
        refute_select ".price"
      end
    end
  end

  private

  def given_two_documents_in_two_organisations
    @organisation_1, @organisation_2 = create(:organisation), create(:organisation)
    create(:published_publication, organisations: [@organisation_1])
    create(:published_consultation, organisations: [@organisation_2])
  end

  def given_two_documents_in_two_topics
    @topic_1, @topic_2 = create(:topic), create(:topic)
    policy_1 = create(:published_policy, topics: [@topic_1])
    create(:published_publication, related_policies: [policy_1])
    policy_2 = create(:published_policy, topics: [@topic_2])
    create(:published_consultation, related_policies: [policy_2])
  end

  def create_publications_in(*topics)
    topics.map do |topic|
      policy = create(:published_policy, topics: [topic])
      create(:published_publication, related_policies: [policy])
    end
  end

end
