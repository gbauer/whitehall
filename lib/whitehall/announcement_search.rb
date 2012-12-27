class Whitehall::AnnouncementSearch
  def initialize(params = {})
    Tire.search ["news_article", "speech", "fatality_notice"], :load => true do
      query { string 'title' }
    end
  end
end

# bundle exec rake environment tire:import CLASS='NewsArticle'
# bundle exec rake environment tire:import CLASS='Speech'
# bundle exec rake environment tire:import CLASS='FatalityNotice'