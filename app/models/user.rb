require 'bcrypt'

# Represents a user, either student or donor.
class User < ActiveRecord::Base
  class AuthTokenInvalid < StandardError; end
  class AuthTokenExpired < StandardError; end

  include ActiveModel::Validations

  AUTH_TOKEN_EXPIRATION = 24.hours
  DONOR_MODES = %w{send_books send_money}

  attr_reader :password

  monetize :balance_cents
  serialize :roles, JSON

  #--
  # Associations
  #++

  belongs_to :location
  has_many :requests
  has_many :pledges
  has_many :donations
  has_many :orders
  has_many :contributions
  has_many :fulfillments
  has_many :reviews
  belongs_to :referral
  has_many :reminders

  #--
  # Validations
  #++

  validates_presence_of :name, :location, :email
  validates_uniqueness_of :email, case_sensitive: false, message: "There is already an account with this email."
  validates_inclusion_of :donor_mode, in: DONOR_MODES

  validate :name_must_have_proper_format, on: :create, if: lambda {|user| user.name.present? }
  validates :email, email: {message: "is not a valid email address"}, allow_nil: true

  validates_presence_of :password, unless: "password_digest.present?"
  validates_presence_of :password_confirmation, if: :password_digest_changed?
  validates_confirmation_of :password, message: "didn't match confirmation"

  def name_must_have_proper_format
    has_upper = name =~ /[A-Z]/
    has_lower = name =~ /[a-z]/

    if has_upper && !has_lower
      self.name = name.titleize
      errors.add :name, "don't use ALL CAPS"
    end

    if has_lower && !has_upper
      self.name = name.titleize
      errors.add :name, "please use proper capitalization"
    end

    errors.add(:name, "please include full first and last name") if (!has_upper && !has_lower) || name.words.size < 2
  end

  #--
  # Scopes and finders
  #++

  default_scope order("created_at desc")

  scope :with_email, lambda {|email| where("lower(email) = ?", email.downcase)}

  def self.find_by_email(email)
    with_email(email).first
  end

  def self.find_by_auth_token(token, expiration = AUTH_TOKEN_EXPIRATION)
    begin
      id, seconds = verifier.verify token
      timestamp = Time.at seconds
      raise AuthTokenExpired if Time.since(timestamp) > expiration
      find id
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise AuthTokenInvalid
    end
  end

  def self.search(query)
    pattern = "%#{query.downcase}%"
    where('lower(name) like :pattern or lower(email) like :pattern', pattern: pattern)
  end

  def self.login(email, password)
    user = find_by_email email
    return user if user && user.authenticate(password)
  end

  def self.donors_with_unsent_books
    donations = Donation.send_books.needs_sending
    donations.map {|donation| donation.user}.uniq
  end

  def self.donors_with_unpaid_donations
    donations = Donation.needs_payment.includes(:user)
    donations.map {|donation| donation.user}.uniq
  end

  #--
  # Callbacks
  #++

  after_initialize do |user|
    user.roles ||= []
  end

  before_validation do |user|
    [:name, :email, :school, :studying].each do |attribute|
      value = user.send attribute
      value.strip! if value
      value.squeeze! " " if value
    end
  end

  after_create do |user|
    Rails.logger.info "New user: #{@user.inspect}"
  end

  #--
  # Derived attributes
  #++

  def location_name
    location && location.name
  end

  def location_name=(name)
    self.location = if name.present?
      name = name.strip.squeeze " "
      Location.find_or_create_by_name name
    else
      nil
    end
  end

  def donor_mode
    ActiveSupport::StringInquirer.new(self[:donor_mode])
  end

  def is_duplicate?
    query = User.with_email(email)
    query = query.where('id != ?', id) if id
    query.any?
  end

  def update_detail
    if address_was.blank? && address.present?
      "added a shipping address"
    elsif name_was.words.size < 2 && name.words.size >= 2
      "added their full name"
    elsif name_changed? || address_changed?
      "updated shipping info"
    end
  end

  def can_request?
    requests.not_granted.empty?
  end

  def new_request
    requests.build book: Book.default_book
  end

  def is_volunteer?
    is_volunteer
  end

  def is_volunteer
    roles.include? "volunteer"
  end

  def is_volunteer=(is_volunteer)
    if is_volunteer.to_bool
      self.roles << "volunteer" unless self.is_volunteer?
    else
      self.roles -= ["volunteer"]
    end
  end

  #--
  # Actions
  #++

  def password=(password)
    @password = password
    self.password_digest = password.present? ? BCrypt::Password.create(password) : nil
  end

  def authenticate(password)
    password_digest.present? && BCrypt::Password.new(password_digest) == password
  end

  def auth_token(timestamp = Time.now)
    User.verifier.generate [id, timestamp.to_i]
  end

  def self.verifier
    @@verifier ||= ActiveSupport::MessageVerifier.new Rails.application.config.secret_token
  end

  #--
  # Conversions
  #++

  def to_s
    name
  end

  def as_json(options = {})
    hash_from_methods :id, :name, :location, :school, :studying
  end
end
