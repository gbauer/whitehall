require 'test_helper'

class CaseStudiesControllerTest < ActionController::TestCase
  should_be_a_public_facing_controller
  should_render_a_list_of :case_studies
  should_show_related_policies_for :case_study
  should_display_inline_images_for :case_study
  should_show_change_notes :case_study

  test "shows published case study" do
    case_study = create(:published_case_study)
    get :show, id: case_study.document
    assert_response :success
  end

  test "renders the summary from plain text" do
    case_study = create(:published_case_study, summary: 'plain text & so on')
    get :show, id: case_study.document

    assert_select ".summary", text: "plain text &amp; so on"
  end

  test "renders the body using govspeak" do
    case_study = create(:published_case_study, body: "body-in-govspeak")
    govspeak_transformation_fixture "body-in-govspeak" => "body-in-html" do
      get :show, id: case_study.document
    end

    assert_select ".body", text: "body-in-html"
  end

  test "shows when it was last updated" do
    case_study = create(:published_case_study, published_at: 10.days.ago)

    editor = create(:departmental_editor)
    updated_case_study = case_study.create_draft(editor)
    updated_case_study.change_note = "change-note"
    updated_case_study.publish_as(editor, force: true)

    get :show, id: updated_case_study.document

    assert_select ".meta .metadata" do
      assert_select ".published_at[title='#{updated_case_study.published_at.iso8601}']"
    end
  end
end