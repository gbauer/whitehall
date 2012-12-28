class Announcement < Edition
  include Edition::Images
  include Edition::RelatedPolicies
  include Edition::Countries
  include Edition::TopicalEvents

  def can_have_summary?
    true
  end

  def self.sti_names
    ([self] + descendants).map { |model| model.sti_name }
  end

  include Tire::Model::Search
  include Tire::Model::Callbacks

  tire.index_name 'whitehall_announcements'

  settings index: {
    mapper: {
      dynamic: false
    }
  }

end

require_relative 'news_article'
require_relative 'speech'
require_relative 'fatality_notice'
