class Err
  include Mongoid::Document
  include Mongoid::Timestamps

  field :klass
  field :component
  field :action
  field :environment
  field :fingerprint
  field :notices_count, :type => Integer, :default => 0
  field :message

  has_many :notices, :dependent => :destroy
  has_many :comments, :inverse_of => :err, :dependent => :destroy

  validates_presence_of :klass, :environment

  belongs_to :problem, :inverse_of => :errs
  
  delegate :app, :resolved?, :unresolved?, :issue_link, :to => :problem
 
  def where
    where = component.dup
    where << "##{action}" if action.present?
    where
  end

  def message
    super || klass
  end

end
