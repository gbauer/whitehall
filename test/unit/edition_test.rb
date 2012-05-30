require "test_helper"

class EditionTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  test "adds a doc identity before validation if none provided" do
    edition = build(:edition)
    edition.valid?
    assert_not_nil edition.doc_identity
    assert_kind_of DocIdentity, edition.doc_identity
  end

  test "uses provided doc identity if available" do
    identity = build(:doc_identity)
    edition = build(:edition, doc_identity: identity)
    assert_equal identity, edition.doc_identity
  end

  test ".published_as returns edition if edition is published" do
    edition = create(:published_policy)
    assert_equal edition, Policy.published_as(edition.doc_identity.to_param)
  end

  test ".published_as returns latest published edition if several editions share identity" do
    edition = create(:published_policy)
    new_draft = create(:draft_policy, doc_identity: edition.doc_identity)
    assert_equal edition, Policy.published_as(edition.doc_identity.to_param)
  end

  test ".published_as returns nil if edition is not published" do
    edition = create(:submitted_edition)
    assert_nil Edition.published_as(edition.doc_identity.to_param)
  end

  test ".published_as returns nil if identity is unknown" do
    assert_nil Edition.published_as('unknown')
  end

  test ".latest_edition includes first edition of any edition" do
    edition = create(:published_edition)
    assert Edition.latest_edition.include?(edition)
  end

  test ".latest_edition includes only latest edition of a edition" do
    original_edition = create(:published_edition)
    new_draft = original_edition.create_draft(create(:policy_writer))
    refute Edition.latest_edition.include?(original_edition)
    assert Edition.latest_edition.include?(new_draft)
  end

  test ".latest_edition ignores deleted editions" do
    original_edition = create(:published_edition)
    new_draft = original_edition.create_draft(create(:policy_writer))
    new_draft.delete!
    assert Edition.latest_edition.include?(original_edition)
    refute Edition.latest_edition.include?(new_draft)
  end

  test ".latest_published_edition" do
    original_edition = create(:published_edition)
    new_draft = original_edition.create_draft(create(:policy_writer))
    new_draft.delete!
    assert Edition.latest_published_edition.include?(original_edition)
    refute Edition.latest_published_edition.include?(new_draft)
  end

  test "should return a list of editions in a policy topic" do
    policy_topic_1 = create(:policy_topic)
    policy_topic_2 = create(:policy_topic)
    draft_policy = create(:draft_policy, policy_topics: [policy_topic_1])
    published_policy = create(:published_policy, policy_topics: [policy_topic_1])
    published_in_second_policy_topic = create(:published_policy, policy_topics: [policy_topic_2])

    assert_equal [draft_policy, published_policy], Policy.in_policy_topic(policy_topic_1)
    assert_equal [published_policy], Policy.published.in_policy_topic(policy_topic_1)
    assert_equal [published_in_second_policy_topic], Policy.in_policy_topic(policy_topic_2)
  end

  test "should return a list of editions in an organisation" do
    organisation_1 = create(:organisation)
    organisation_2 = create(:organisation)
    draft_edition = create(:draft_edition, organisations: [organisation_1])
    published_edition = create(:published_edition, organisations: [organisation_1])
    published_in_second_organisation = create(:published_edition, organisations: [organisation_2])

    assert_equal [draft_edition, published_edition], Edition.in_organisation(organisation_1)
    assert_equal [published_edition], Edition.published.in_organisation(organisation_1)
    assert_equal [published_in_second_organisation], Edition.in_organisation(organisation_2)
  end

  test "should return a list of editions in a ministerial role" do
    ministerial_role_1 = create(:ministerial_role)
    ministerial_role_2 = create(:ministerial_role)
    draft_policy = create(:draft_policy, ministerial_roles: [ministerial_role_1])
    published_policy = create(:published_policy, ministerial_roles: [ministerial_role_1])
    published_publication = create(:published_publication, ministerial_roles: [ministerial_role_1])
    published_in_second_ministerial_role = create(:published_policy, ministerial_roles: [ministerial_role_2])

    assert_equal [draft_policy, published_policy], Policy.in_ministerial_role(ministerial_role_1)
    assert_equal [published_policy], Policy.published.in_ministerial_role(ministerial_role_1)
    assert_equal [published_in_second_ministerial_role], Policy.in_ministerial_role(ministerial_role_2)
  end

  test "return editions bi-directionally related to specific edition" do
    policy = create(:policy)
    publication_1 = create(:publication, related_policies: [policy])
    publication_2 = create(:publication, related_policies: [policy])

    assert_equal [publication_1, publication_2], policy.related_editions
    assert_equal [policy], publication_1.related_policies
    assert_equal [policy], publication_2.related_policies
  end

  test "return published editions bi-directionally related to specific policy" do
    policy = create(:published_policy)
    edition_1 = create(:published_publication, related_policies: [policy])
    edition_2 = create(:published_publication, related_policies: [policy])

    assert_equal [edition_1, edition_2], policy.published_related_editions
    assert_equal [policy], edition_1.published_related_policies
    assert_equal [policy], edition_2.published_related_policies
  end

  test "#first_edition? is true if published and first_published_at equals published_at" do
    policy = create(:published_policy)
    assert policy.first_edition?
  end

  test "#first_edition? is false if published and first_published_at doesn't equal published_at" do
    policy = create(:published_policy, first_published_at: 1.minute.ago)
    refute policy.first_edition?
  end

  test "#creator= builds an edition_author with the given creator for new records" do
    creator = create(:user)
    edition = build(:edition, creator: creator)
    assert_equal creator, edition.edition_authors.first.user
  end

  test "#creator= raises an exception if called for a persisted record" do
    edition = create(:edition)
    assert_raises RuntimeError do
      edition.creator = create(:user)
    end
  end

  test ".related_to includes editions related to edition" do
    policy = create(:policy)
    publication = create(:publication, related_policies: [policy])
    assert Edition.related_to(policy).include?(publication)
  end

  test ".related_to respects chained scopes" do
    policy = create(:policy)
    publication = create(:publication, related_policies: [policy])
    assert Publication.related_to(policy).include?(publication)
    refute Policy.related_to(policy).include?(publication)
  end

  test ".related_to excludes unrelated editions" do
    publication = create(:publication)
    policy = create(:policy)
    refute Edition.related_to(policy).include?(publication)
  end

  test ".authored_by includes editions created by the given user" do
    publication = create(:publication)
    assert Edition.authored_by(publication.creator).include?(publication)
  end

  test ".authored_by includes editions edited by given user" do
    publication = create(:publication)
    writer = create(:policy_writer)
    publication.edit_as(writer, {})
    assert Edition.authored_by(writer).include?(publication)
  end

  test ".authored_by includes editions only once no matter how many edits a user has made" do
    publication = create(:publication)
    writer = create(:policy_writer)
    publication.edit_as(writer, {})
    publication.edit_as(writer, {})
    publication.edit_as(writer, {})
    assert_equal 1, Edition.authored_by(writer).all.size
  end

  test ".authored_by excludes editions creatored by another user" do
    publication = create(:publication)
    refute Edition.authored_by(create(:policy_writer)).include?(publication)
  end

  test ".authored_by respects chained scopes" do
    publication = create(:publication)
    assert Edition.authored_by(publication.creator).include?(publication)
    assert Publication.authored_by(publication.creator).include?(publication)
    refute Policy.authored_by(publication.creator).include?(publication)
  end

  test ".rejected_by uses information from the audit trail" do
    publication = create(:submitted_publication)
    user = create(:policy_writer)
    PaperTrail.whodunnit = user
    publication.reject!
    assert_equal user, publication.rejected_by
  end

  test ".rejected_by should not be confused by editorial remarks" do
    publication = create(:submitted_publication)
    user = create(:policy_writer)
    PaperTrail.whodunnit = user
    create(:editorial_remark, edition: publication)
    assert_nil publication.reload.rejected_by
  end

  test ".by_published_at orders by published_at descending" do
    policy = create(:policy, published_at: 2.hours.ago)
    publication = create(:publication, published_at: 4.hours.ago)
    article = create(:news_article, published_at: 1.hour.ago)
    assert_equal [article, policy, publication], Edition.by_published_at
  end

  test ".latest_published_at returns the most recent published_at from published editions" do
    policy = create(:published_policy, published_at: 2.hours.ago)
    publication = create(:published_publication, published_at: 4.hours.ago)
    assert_equal policy.published_at, Edition.latest_published_at
  end

  test ".latest_published_at ignores unpublished editions" do
    policy = create(:draft_policy, published_at: 2.hours.ago)
    publication = create(:published_publication, published_at: 4.hours.ago)
    assert_equal publication.published_at, Edition.latest_published_at
  end

  test ".latest_published_at returns nil if no published editions exist" do
    assert_nil Edition.latest_published_at
  end

  test "should only return the submitted editions" do
    draft_edition = create(:draft_edition)
    submitted_edition = create(:submitted_edition)
    assert_equal [submitted_edition], Edition.submitted
  end

  test "should return all documents excluding those that are archived or deleted" do
    draft_document = create(:draft_edition)
    submitted_document = create(:submitted_edition)
    rejected_document = create(:rejected_edition)
    published_document = create(:published_edition)
    deleted_document = create(:deleted_edition)
    archived_document = create(:archived_edition)
    assert_same_elements [draft_document, submitted_document, rejected_document, published_document], Edition.active
  end

  test "should not be publishable when not submitted" do
    draft_edition = create(:draft_edition)
    refute draft_edition.publishable_by?(create(:departmental_editor))
  end

  test "should not return published editions in submitted" do
    edition = create(:submitted_edition)
    edition.publish_as(create(:departmental_editor))
    refute Edition.submitted.include?(edition)
  end

  test "should be invalid if has image but no alt text" do
    article = build(:news_article, images: [build(:image, alt_text: nil)])
    refute article.valid?
  end

  test "should still be valid if has no image and no alt text" do
    article = build(:news_article, images: [])
    assert article.valid?
  end

  test "should still be archivable if alt text validation would normally fail" do
    article = create(:published_news_article, images: [build(:image)])
    article.images.first.update_attribute(:alt_text, nil)
    NewsArticle.find(article.id).archive!
  end

  test "should still be deleteable if alt text validation would normally fail" do
    article = create(:submitted_news_article, images: [build(:image)])
    article.images.first.update_attribute(:alt_text, nil)
    NewsArticle.find(article.id).delete!
  end
  
  test "generate title for a draft edition" do
    draft_edition = create(:draft_edition, title: "Holding back")
    assert_equal "Holding back (draft)", draft_edition.title_with_state
  end

  test "generate title for a submitted edition" do
    submitted_edition = create(:submitted_edition, title: "Dog Eyes")
    assert_equal "Dog Eyes (submitted)", submitted_edition.title_with_state
  end

  test "generate title for a published edition" do
    published_edition = create(:published_edition, title: "Dog Eyes")
    assert_equal "Dog Eyes (published)", published_edition.reload.title_with_state
  end

  test "should use the edition title as the basis for the doc identity's slug" do
    edition = create(:edition, title: 'My Policy Title')
    assert_equal 'my-policy-title', edition.doc_identity.slug
  end

  test "should concatenate words containing apostrophes" do
    edition = create(:edition, title: "Bob's bike")
    assert_equal 'bobs-bike', edition.doc_identity.slug
  end

  test "is filterable by document type" do
    policy = create(:policy)
    publication = create(:publication)
    news = create(:news_article)
    speech = create(:speech)
    consultation_response = create(:consultation_response)
    consultation = consultation_response.consultation

    assert_equal [policy], Edition.by_type('Policy')
    assert_equal [publication], Edition.by_type('Publication')
    assert_equal [news], Edition.by_type('NewsArticle')
    assert_equal [speech], Edition.by_type('Speech')
    assert_equal [consultation], Edition.by_type('Consultation')
    assert_equal [consultation_response], Edition.by_type('ConsultationResponse')
  end

  test "should not be featurable" do
    refute build(:edition).featurable?
  end

  test "should have no lead image even if an associated image exists" do
    article = build(:edition, images: [build(:image)])
    assert_nil article.lead_image
  end

  test "should return search index suitable for Rummageable" do
    policy = create(:published_policy, title: "policy-title")
    slug = policy.doc_identity.slug

    assert_equal "policy-title", policy.search_index["title"]
    assert_equal "/government/policies/#{slug}", policy.search_index["link"]
    assert_equal policy.body, policy.search_index["indexable_content"]
    assert_equal "policy", policy.search_index["format"]
  end

  test "#indexable_content should return the body without markup by default" do
    policy = create(:published_policy, body: "# header\n\nsome text")
    assert_equal "header some text", policy.indexable_content
  end

  test "should use the result of #indexable_content for the content of #search_index" do
    policy = create(:published_policy, title: "policy-title")
    policy.stubs(:indexable_content).returns("some augmented searchable content")
    assert_equal "some augmented searchable content", policy.search_index["indexable_content"]
  end

  test "should return search index data for all published editions" do
    create(:published_policy, title: "policy-title", body: "this and that")
    create(:published_publication, title: "publication-title", body: "stuff and things")
    create(:draft_publication, title: "draft-publication-title", body: "bits and bobs")

    results = Edition.search_index

    assert_equal 2, results.length
    assert_equal({"title"=>"policy-title", "link"=>"/government/policies/policy-title",
                  "indexable_content"=>"this and that", "format" => "policy"}, results[0])
    assert_equal({"title"=>"publication-title", "link"=>"/government/publications/publication-title",
                  "indexable_content"=>"stuff and things", "format" => "publication"}, results[1])
  end

  test "should add edition to search index on publishing" do
    policy = create(:submitted_policy)

    Rummageable.expects(:index).with(policy.search_index)

    policy.publish_as(create(:departmental_editor))
  end

  test "should not remove edition from search index when a new edition is published" do
    policy = create(:published_policy)
    slug = policy.doc_identity.slug

    Rummageable.expects(:delete).with("/government/policies/#{slug}").never

    new_edition = policy.create_draft(create(:policy_writer))
    new_edition.change_note = "change-note"
    new_edition.publish_as(create(:departmental_editor), force: true)
  end

  test "should not remove edition from search index when a new draft of a published edition is deleted" do
    policy = create(:published_policy)
    new_draft_policy = policy.create_draft(create(:policy_writer))
    slug = policy.doc_identity.slug

    Rummageable.expects(:delete).with("/government/policies/#{slug}").never

    new_draft_policy.delete!
  end

  test "should remove published edition from search index when it's deleted" do
    policy = create(:published_policy)
    slug = policy.doc_identity.slug

    Rummageable.expects(:delete).with("/government/policies/#{slug}")

    policy.delete!
  end

  test "should remove published edition from search index when it's archived" do
    policy = create(:published_policy)
    slug = policy.doc_identity.slug

    Rummageable.expects(:delete).with("/government/policies/#{slug}")

    policy.archive!
  end

  test "should provide a list of all editions ever published in reverse chronological order by publication date" do
    original_edition = create(:archived_edition, published_at: 3.days.ago)
    doc_identity = original_edition.doc_identity
    new_edition_1 = create(:archived_edition, doc_identity: doc_identity, published_at: 2.days.ago)
    new_edition_2 = create(:published_edition, doc_identity: doc_identity, published_at: 1.day.ago)
    draft_edition = create(:draft_edition, doc_identity: doc_identity)

    assert_equal [new_edition_2, new_edition_1, original_edition], new_edition_2.editions_ever_published
    refute new_edition_2.editions_ever_published.include?(draft_edition)
  end

  test "#destroy should also remove the relationship to any authors" do
    edition = create(:draft_edition, creator: create(:policy_writer))
    relation = edition.edition_authors.first
    edition.destroy
    refute EditionAuthor.find_by_id(relation.id)
  end

  test "#destroy should also remove the relationship to any editorial remarks" do
    edition = create(:draft_edition, editorial_remarks: [create(:editorial_remark)])
    relation = edition.editorial_remarks.first
    edition.destroy
    refute EditorialRemark.find_by_id(relation.id)
  end

  test "can record editing intent" do
    user = create(:policy_writer)
    edition = create(:edition)
    edition.open_for_editing_as(user)
    Timecop.travel 1.minute.from_now
    assert_equal [user], edition.recent_edition_openings.map(&:editor)
  end

  test "recording editing intent for a user who's already editing just updates the timestamp" do
    user = create(:policy_writer)
    edition = create(:edition)
    edition.open_for_editing_as(user)
    Timecop.travel 1.minute.from_now
    assert_difference "edition.recent_edition_openings.count", 0 do
      edition.open_for_editing_as(user)
    end
    assert_equal user, edition.recent_edition_openings.first.editor
    assert_equal Time.zone.now.to_s(:rfc822), edition.recent_edition_openings.first.created_at.in_time_zone.to_s(:rfc822)
  end

  test "can check exclude a given editor from the list of recent edition openings" do
    user = create(:policy_writer)
    edition = create(:edition)
    edition.open_for_editing_as(user)
    Timecop.travel 1.minute.from_now
    user2 = create(:policy_writer)
    edition.open_for_editing_as(user2)
    assert_equal [user], edition.recent_edition_openings.except_editor(user2).map(&:editor)
  end

  test "editors considered active for up to 2 hours" do
    user = create(:policy_writer)
    edition = create(:edition)
    edition.open_for_editing_as(user)
    Timecop.travel 2.hours.from_now
    assert_equal [user], edition.active_edition_openings.map(&:editor)
    Timecop.travel 1.second.from_now
    assert_equal [], edition.active_edition_openings
  end

  test "#save_as removes all RecentEditionOpenings for the specified editor" do
    user = create(:policy_writer)
    edition = create(:edition)
    edition.open_for_editing_as(user)
    assert_difference "edition.recent_edition_openings.count", -1 do
      edition.save_as(user)
    end
  end

  test "RecentEditionOpening#expunge! deletes entries more than 2 hours old" do
    edition = create(:edition)
    create(:recent_edition_opening, editor: create(:author), edition: edition, created_at: 2.hours.ago + 1.second)
    create(:recent_edition_opening, editor: create(:author), edition: edition, created_at: 2.hours.ago)
    create(:recent_edition_opening, editor: create(:author), edition: edition, created_at: 2.hours.ago - 1.second)
    assert_equal 3, RecentEditionOpening.count
    RecentEditionOpening.expunge!
    assert_equal 2, RecentEditionOpening.count
  end
end