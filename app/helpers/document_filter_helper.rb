module DocumentFilterHelper
  def topic_filter_options(topics, selected_topics = [])
    selected_values = selected_topics.any? ? selected_topics.map(&:slug) : ["all"]
    options_for_select([["All topics", "all"]] + topics.map{ |o| [o.name, o.slug] }, selected_values)
  end

  def organisation_filter_options(organisations, selected_organisations = [])
    selected_values = selected_organisations.any? ? selected_organisations.map(&:slug) : ["all"]
    options_for_select([["All departments", "all"]] + organisations.map{ |o| [o.name, o.slug] }, selected_values)
  end

  def publication_type_filter_options(publication_filter_options, selected_publication_filter_options = nil)
    selected_value = selected_publication_filter_options ? selected_publication_filter_options.slug : "all"
    options_for_select([["All publication types", "all"]] + publication_filter_options.map{ |pt| [pt.label, pt.slug] }, [selected_value])
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
end
