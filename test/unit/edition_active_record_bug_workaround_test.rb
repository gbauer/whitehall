require "test_helper"

class EditionActiveRecordBugWorkaroundTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  test ".related_to avoids wierd bug in active record" do
    policy = create(:published_policy)
    publications = [
      create(:published_publication, related_policies: [policy]),
      create(:draft_publication, related_policies: [policy])
    ]

    # This has a side-effect of causing active-record to cache the
    # policy.related_to relation including the 'published' scope
    Edition.published.related_to(policy).all

    assert_equal publications, policy.related_editions
  end
end