class NewsArticle < Announcement
  include Edition::RoleAppointments
  include Edition::FactCheckable
  include Edition::FirstImagePulledOut

  tire.index_name 'whitehall_announcements'

  mapping do
    indexes :id,                    index: :not_analyzed
    indexes :title,                 analyzer: 'snowball', boost: 10
    indexes :summary,               analyzer: 'snowball', boost: 5
    indexes :indexable_content,     analyzer: 'snowball'
    indexes :state,                 analyzer: 'keyword'
    indexes :timestamp_for_sorting, type: 'date'
    indexes :first_published_at,    type: 'date'
    indexes :organisations,         type: 'string', 
                                    analyzer: 'keyword', 
                                    as: 'organisations.map(&:id)'
    indexes :topics,                type: 'string', 
                                    analyzer: 'keyword', 
                                    as: 'topics.map(&:id)'
    indexes :people,                type: 'string',
                                    analyzer: 'keyword',
                                    as: 'role_appointments.map(&:person_id)'
  end  
end
