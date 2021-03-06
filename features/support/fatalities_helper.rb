module FatalitiesHelper
  def draft_fatality_notice(title, field)
    create(:operational_field, name: field)
    begin_drafting_document type: "fatality_notice", title: title
    fill_in "Summary", with: "fatality notice summary"
    select field, from: "Field of operation"
    click_button "Save"
  end
end

World(FatalitiesHelper)
