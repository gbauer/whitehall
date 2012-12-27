class NewsArticle < Announcement
  include Edition::RoleAppointments
  include Edition::FactCheckable
  include Edition::FirstImagePulledOut

  tire.index_name 'announcements'
end
