require 'hoptoad'
require 'recurse'

class Notice
  include Mongoid::Document
  include Mongoid::Timestamps

  field :message
  field :server_environment, :type => Hash
  field :request, :type => Hash
  field :notifier, :type => Hash
  field :user_attributes, :type => Hash
  field :customer_attributes, :type => Hash  
  field :current_user, :type => Hash
  field :framework
  field :error_class
  delegate :lines, :to => :backtrace, :prefix => true
  delegate :app, :problem, :to => :err

  belongs_to :err
  belongs_to :backtrace, :index => true
  index :created_at
  index(
    [
      [ :err_id, Mongo::ASCENDING ],
      [ :created_at, Mongo::ASCENDING ],
      [ :_id, Mongo::ASCENDING ]
    ]
  )

  after_create :cache_attributes_on_problem, :unresolve_problem
  before_save :sanitize
  before_destroy :decrease_counter_cache, :remove_cached_attributes_from_problem

  validates_presence_of :backtrace, :server_environment, :notifier

  scope :ordered, order_by(:created_at.asc)
  scope :reverse_ordered, order_by(:created_at.desc)
  scope :for_errs, lambda {|errs| where(:err_id.in => errs.all.map(&:id))}

  def user_agent
    agent_string = env_vars['HTTP_USER_AGENT']
    agent_string.blank? ? nil : UserAgent.parse(agent_string)
  end

  def user_agent_string
    if user_agent.nil? || user_agent.none?
      "N/A"
    else
      "#{user_agent.browser} #{user_agent.version} (#{user_agent.os})"
    end
  end

  def environment_name
    server_environment['server-environment'] || server_environment['environment-name']
  end

  def component
    request['component']
  end

  def action
    request['action']
  end

  def where
    where = component.to_s.dup
    where << "##{action}" if action.present?
    where
  end

  def request
    super || {}
  end

  def url
    request['url']
  end

  def host
    uri = url && URI.parse(url)
    uri.blank? ? "N/A" : uri.host
  rescue URI::InvalidURIError
    "N/A"
  end

  def env_vars
    request['cgi-data'] || {}
  end

  def params
    request['params'] || {}
  end

  def session
    request['session'] || {}
  end

  def in_app_backtrace_lines
    backtrace_lines.in_app
  end

  def similar_count
    problem.notices_count
  end

  def emailable?
    app.email_at_notices.include?(similar_count)
  end

  def should_email?
    app.emailable? && emailable?
  end

  def should_notify?
    app.notification_service.notify_at_notices.include?(0) || app.notification_service.notify_at_notices.include?(similar_count)
  end

  ##
  # TODO: Move on decorator maybe
  #
  def project_root
    if server_environment
      server_environment['project-root'] || ''
    end
  end

  protected

  def decrease_counter_cache
    problem.inc(:notices_count, -1) if err
  end

  def remove_cached_attributes_from_problem
    problem.remove_cached_notice_attributes(self) if err
  end

  def unresolve_problem
    problem.update_attributes!(:resolved => false, :resolved_at => nil, :notices_count => 1) if problem.resolved?
  end

  def cache_attributes_on_problem
    ProblemUpdaterCache.new(problem, self).update
  end

  def sanitize
    [:server_environment, :request, :notifier].each do |h|
      send("#{h}=",sanitize_hash(send(h)))
    end
  end


  def sanitize_hash(h)
    h.recurse do
      |h| h.inject({}) do |h,(k,v)|
        if k.is_a?(String)
          h[k.gsub(/\./,'&#46;').gsub(/^\$/,'&#36;')] = v
        else
          h[k] = v
        end
        h
      end
    end
  end

end

