class ErrsController < InheritedResources::Base

  before_filter :find_app, :except => [:index, :all]
  before_filter :find_err, :except => [:index, :all]
  respond_to :html, :only => [:index]
  respond_to :atom, :only => [:index]
  belongs_to :app, :optional => true
  has_scope :environment do |controller, scope, value|
    scope.where(:environment => value)
  end
  has_scope(:all_errs, :default => 'false') do |controller, scope, value|
    value.to_s != 'true' ? scope.unresolved : scope
  end

  def show
    page      = (params[:notice] || @err.notices_count)
    page      = 1 if page.to_i.zero?
    @notices  = @err.notices.ordered.paginate(:page => page, :per_page => 1)
    @notice   = @notices.first
    @comment = Comment.new
  end

  def create_issue
    set_tracker_params

    if @app.issue_tracker
      @app.issue_tracker.create_issue @err
    else
      flash[:error] = "This up has no issue tracker setup."
    end
    redirect_to app_err_path(@app, @err)
  rescue ActiveResource::ConnectionError => e
    Rails.logger.error e.to_s
    flash[:error] = "There was an error during issue creation. Check your tracker settings or try again later."
    redirect_to app_err_path(@app, @err)
  end

  def unlink_issue
    @err.update_attribute :issue_link, nil
    redirect_to app_err_path(@app, @err)
  end

  def resolve
    # Deal with bug in mongoid where find is returning an Enumberable obj
    @err = @err.first if @err.respond_to?(:first)

    @err.resolve!

    flash[:success] = 'Great news everyone! The err has been resolved.'

    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to app_path(@app)
  end


  def create_comment
    @comment = Comment.new(params[:comment].merge(:user_id => current_user.id))
    if @comment.valid?
      @err.comments << @comment
      @err.save
      flash[:success] = "Comment saved!"
    else
      flash[:error] = "I'm sorry, your comment was blank! Try again?"
    end
    redirect_to app_err_path(@app, @err)
  end

  def destroy_comment
    @comment = Comment.find(params[:comment_id])
    if @comment.destroy
      flash[:success] = "Comment deleted!"
    else
      flash[:error] = "Sorry, I couldn't delete your comment for some reason. I hope you don't have any sensitive information in there!"
    end
    redirect_to app_err_path(@app, @err)
  end


  protected

    def begin_of_association_chain
      current_user unless current_user.admin?
    end

    def collection
      @errs ||= begin
        collection = end_of_association_chain.ordered
        collection = collection.paginate(:page => params[:page], :per_page => current_user.per_page) unless request.format.atom?
        collection
      end
    end

    def find_app
      @app = App.find(params[:app_id])

      # Mongoid Bug: could not chain: current_user.apps.find_by_id!
      # apparently finding by 'watchers.email' and 'id' is broken
      raise(Mongoid::Errors::DocumentNotFound.new(App,@app.id)) unless current_user.admin? || current_user.watching?(@app)
    end

    def find_err
      @err = @app.errs.find(params[:id])
    end

    def set_tracker_params
      IssueTracker.default_url_options[:host] = request.host
      IssueTracker.default_url_options[:port] = request.port
      IssueTracker.default_url_options[:protocol] = request.scheme
    end

end

