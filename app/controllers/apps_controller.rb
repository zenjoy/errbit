class AppsController < InheritedResources::Base

  before_filter :require_admin!, :except => [:index, :show]
  before_filter :parse_email_at_notices_or_set_default, :only => [:create, :update]
  respond_to :html, :except => [:show]

  def new
    plug_params build_resource
    new!
  end

  def edit
    plug_params resource
    edit!
  end

  protected
    def begin_of_association_chain
      current_user unless current_user.admin?
    end

    def interpolation_options
      {:app_name => resource.name}
    end

    def plug_params app
      app.watchers.build if app.watchers.none?
      app.issue_tracker = IssueTracker.new if app.issue_tracker.nil?
    end

    # email_at_notices is edited as a string, and stored as an array.
    def parse_email_at_notices_or_set_default
      if params[:app] && val = params[:app][:email_at_notices]
        # Sanitize negative values, split on comma,
        # strip, parse as integer, remove all '0's.
        # If empty, set as default and show an error message.
        email_at_notices = val.gsub(/-\d+/,"").split(",").map{|v| v.strip.to_i }.reject{|v| v == 0}
        if email_at_notices.any?
          params[:app][:email_at_notices] = email_at_notices
        else
          default_array = params[:app][:email_at_notices] = Errbit::Config.email_at_notices
          flash[:error] = "Couldn't parse your notification frequency. Value was reset to default (#{default_array.join(', ')})."
        end
      end
    end
end

