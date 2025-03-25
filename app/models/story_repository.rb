# typed: false

class StoryRepository
  def initialize(user = nil, params = {})
    @user = user
    @params = params
  end

  def categories(cats)
    tagged_story_ids = Tagging.select(:story_id).where(tag_id: Tag.where(category: cats).select(:id))

    Story.base(@user).positive_ranked.where(id: tagged_story_ids).order(created_at: :desc)
  end

  def hottest
    # Get base set of stories
    hottest = Story.base(@user).positive_ranked.not_hidden_by(@user)
    hottest = hottest.filter_tags(@params[:exclude_tags] || [])
    
    # Get promoted stories first, then other stories by hotness
    promoted_ids = Vote.where(comment_id: nil, vote: -1, reason: 'P').select(:story_id)
    hottest.order(Arel.sql("CASE WHEN stories.id IN (#{promoted_ids.to_sql}) THEN 0 ELSE 1 END, hotness"))
  end

  def hidden
    Story.base(@user).hidden_by(@user).filter_tags(@params[:exclude_tags] || []).order("hotness")
  end

  def newest
    Story.base(@user).filter_tags(@params[:exclude_tags] || []).order(id: :desc)
  end

  def active
    Story.base(@user)
      .where.not(id: Story.hidden_by(@user).select(:id))
      .filter_tags(@params[:exclude_tags] || [])
      .select('stories.*, (
        select max(comments.id)
        from comments
        where
          comments.story_id = stories.id and
          comments.created_at >= date_sub(now(), interval 3 day)
      ) as latest_comment_id')
      .order("latest_comment_id desc")
  end

  def promoted
    promoted_story_ids = Vote.where(comment_id: nil, vote: -1, reason: 'P').select(:story_id)
    Story.base(@user)
      .where(id: promoted_story_ids)
      .filter_tags(@params[:exclude_tags] || [])
      .order(created_at: :desc)
  end

  def newest_by_user(user)
    # Story.base without unmerged scope
    Story.where(user: user).includes(:tags).not_deleted(@user).mod_preload?(@user).order(id: :desc)
  end

  def saved
    Story.base(@user).saved_by(@user).filter_tags(@params[:exclude_tags] || []).order(:hotness)
  end

  def tagged(tags)
    tagged_story_ids = Tagging.select(:story_id).where(tag_id: tags.map(&:id))

    Story.base(@user).positive_ranked.where(id: tagged_story_ids).order(created_at: :desc)
  end

  def top(length)
    top = Story.base(@user).where("created_at >= (NOW() - INTERVAL " \
      "#{length[:dur]} #{length[:intv].upcase})")
    top.order("score DESC")
  end
end
