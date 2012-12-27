class Whitehall::AnnouncementSearch
  attr_reader :page, :direction, :date

  def initialize(params = {})
    @params = params
    @per_page = params[:per_page] || 20
    @page = params[:page]
    @direction = params[:direction]
    @date = parse_date
  end

  def published_search
    Tire.search "whitehall_announcements", load: true, per_page: @per_page, page: @page do |search|

      search.query { all }
     
      search.filter :term, state: "published"
      if @date.present? && @direction.present?
        case @direction
        when "before"
          search.filter :range, timestamp_for_sorting: {to: @date - 1.day}
          search.sort { by :timestamp_for_sorting, :desc }
        when "after"
          search.filter :range, timestamp_for_sorting: {from: @date + 1.month}
          search.sort { by :timestamp_for_sorting}
        end
      end
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