class Whitehall::AnnouncementSearch
  def initialize(params = {})
    Tire.search 'whitehall_announcements' do
      
    end
  end
end