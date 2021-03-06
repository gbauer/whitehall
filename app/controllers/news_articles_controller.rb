class NewsArticlesController < DocumentsController
  before_filter :set_analytics_format, only:[:show]

  def show
    @related_policies = @document.published_related_policies
    @document = NewsArticlePresenter.decorate(@document)
    set_slimmer_organisations_header(@document.organisations)
  end

  private

  def document_class
    NewsArticle
  end

  def analytics_format
    :news
  end
end
