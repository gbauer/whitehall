class Whitehall::AnnouncementSearch
  attr_reader :page

  def initialize(params = {})
    @params = params
    @per_page = params[:per_page] || 20
    @page = params[:page]
  end
  def published_search
    Tire.search "whitehall_announcements", load: true, per_page: @per_page, page: @page do
      query { all }
     
      filter :term, state: "published"
      sort { by :timestamp_for_sorting, "desc" }
    end
  end

  def all_topics
    Topic.with_content.order(:name)
  end

  def all_topics_with(type)
    case type
    when :publication
      Topic.with_related_publications.sort_by(&:name)
    when :detailed_guide
      Topic.with_related_detailed_guides.order(:name)
    when :announcement
      Topic.with_related_announcements.order(:name)
    when :policy
      Topic.with_related_policies.order(:name)
    end
  end

  def all_organisations_with(type)
    Organisation.joins(:"published_#{type.to_s.pluralize}").group(:name).ordered_by_name_ignoring_prefix
  end

  def publication_types_for_filter
    Whitehall::PublicationFilterOption.all
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

  def direction
    @params[:direction]
  end

  def date
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

# bundle exec rake environment tire:import CLASS='NewsArticle'
# bundle exec rake environment tire:import CLASS='Speech'
# bundle exec rake environment tire:import CLASS='FatalityNotice'