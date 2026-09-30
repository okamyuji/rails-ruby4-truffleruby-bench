module Api
  class ArticlesController < ActionController::API
    def index
      articles = Article.published.includes(:author).order(id: :desc).limit(50)
      render json: articles.as_json(
        only: %i[id title score published_at],
        include: { author: { only: %i[id name] } }
      )
    end

    def create
      article = Article.new(params.expect(article: %i[author_id title body score]))
      if article.save
        render json: { id: article.id }, status: :created
      else
        render json: { errors: article.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
