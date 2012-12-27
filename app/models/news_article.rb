class NewsArticle < Announcement
  include Edition::RoleAppointments
  include Edition::FactCheckable
  include Edition::FirstImagePulledOut

  tire.index_name 'whitehall_announcements'

  def to_indexed_json
    {
      state: state,
      timestamp_for_sorting: timestamp_for_sorting,
      first_published_at: first_published_at,
      organisations: organisations.map(&:id),
      people: role_appointments.map(&:person_id),
      topics: topics.map(&:id),
      title: title,
      description: summary,
      content: indexable_content,
    }.to_json
  end
end
