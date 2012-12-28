class Whitehall::AnnouncementSearch
  attr_reader :page, :direction, :date

  def initialize(params = {})
    @params = params
    @per_page = params[:per_page] || 20
    @page = params[:page]
    @direction = params[:direction]
    @date = parse_date
    @announcement_type = params[:announcement_type]
    @keywords = params[:keywords]
  end

  def only_published(search)
    search.filter :term, state: "published"
  end

  def keyword_search(search)
    if @keywords.present?
      search.query do |query|
        query.string @keywords 
      end
    else
      search.query { all }
    end
  end

  def filter_topics(search)
    if selected_topics.any?
      search.filter :term, topics: selected_topics.map(&:id)
    end
  end

  def filter_organisations(search)
    if selected_organisations.any?
      search.filter :term, organisations: selected_organisations.map(&:id)
    end
  end

  def filter_by_type(search)
    if @announcement_type.present?
      search.filter :term, _type: @announcement_type
    end
  end

  def filter_date_and_sort(search)
    if @date.present? && @direction.present?
      case @direction
      when "before"
        search.filter :range, timestamp_for_sorting: {to: @date - 1.day}
        search.sort { by :timestamp_for_sorting, :desc }
      when "after"
        search.filter :range, timestamp_for_sorting: {from: @date }
        search.sort { by :timestamp_for_sorting}
      end
    end
  end

  def paginate(search)
    search.size @per_page
    search.from( @page.to_i <= 1 ? 0 : (@per_page.to_i * (@page.to_i-1)) )
  end

  def published_search
    @results ||= Tire.search "whitehall_announcements", load: {include: [:document, :organisations]} do |search|
      keyword_search(search)     
      only_published(search)      
      filter_by_type(search)
      filter_topics(search)
      filter_organisations(search)
      filter_date_and_sort(search)
      paginate(search)
    end
  end

  def selected_topics
    find_by_slug(Topic, @params[:topics])
  end

  def selected_organisations
    find_by_slug(Organisation, @params[:departments])
  end

  def selected_publication_filter_option
    filter_option = @params[:publication_filter_option] || @params[:publication_type]
    Whitehall::PublicationFilterOption.find_by_slug(filter_option)
  end

  def keywords
    if @params[:keywords].present?
      @params[:keywords].strip.split(/\s+/)
    else
      []
    end
  end

  def parse_date
    Date.parse(@params[:date]) if @params[:date].present?
    rescue ArgumentError => e
      if e.message[/invalid date/]
        return nil
      else
        raise e
    end
  end

  private

  def find_by_slug(klass, slugs)
    @selected ||= {}
    @selected[klass] ||= if slugs.present? && !slugs.include?("all")
      klass.where(slug: slugs)
    else
      []
    end
  end

end