class ArticlesController < ActionController::Base
  def index
    @articles = Article.published.includes(:author, :comments).order(id: :desc).limit(50)
  end
end
