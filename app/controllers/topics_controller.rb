class TopicsController < PublicFacingController
  def index
    @topics = Topic.all
    @featured_topics = Topic.featured.order("updated_at DESC").limit(3)
  end

  def show
    @topic = Topic.find(params[:id])
    @exemplary_topics = Topic.exemplars
    @policies = @topic.policies.published
    @related_topics = @topic.related_topics
    @recently_changed_documents = recently_changed_documents
    @featured_policies = @topic.featured_policies
  end

  private

  def recently_changed_documents
    (@topic.published_related_editions + @policies).sort_by(&:published_at).reverse
  end
end