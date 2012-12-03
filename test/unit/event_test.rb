require 'test_helper'

class EventTest < ActiveSupport::TestCase
  def setup
    super
    @new_flag = @dagny_donation.flag_events.build message: "Problem here"
    @new_fix = @hank_donation.fix_events.build detail: "updated shipping info", message: "Fixed"
    @new_message = @hank_donation.message_events.build user: @hank, message: "Info is correct"
    @new_thank = @quentin_donation.message_events.build user: @quentin, message: "Thanks!", is_thanks: true, public: false
    @new_cancel = @hank_donation.cancel_donation_events.build user: @cameron, message: "Sorry!"
    @new_student_cancel = @quentin_donation_unsent.cancel_donation_events.build user: @quentin, detail: "not_received"
  end

  # Associations

  test "request" do
    assert_equal @quentin_request, events(:hugh_grants_quentin).request
  end

  test "user" do
    assert_equal @hugh, events(:hugh_grants_quentin).user
    assert_equal @quentin, events(:quentin_adds_name).user
  end

  test "donor" do
    assert_equal @hugh, events(:hugh_grants_quentin).donor
  end

  test "donation" do
    assert_equal @quentin_donation, events(:hugh_grants_quentin).donation
  end

  # Scopes

  test "public thanks" do
    verify_scope(Event, :public_thanks) {|event| event.is_thanks? && event.public?}
  end

  # Validations

  test "valid flag" do
    assert @new_flag.valid?, @new_flag.errors.inspect
  end

  test "flag requires message" do
    @new_flag.message = ""
    assert @new_flag.invalid?
    assert @new_flag.errors[:message].any?
  end

  test "valid fix" do
    assert @new_fix.valid?, @new_fix.errors.inspect
  end

  test "flag with detail doesn't need message" do
    @new_fix.message = ""
    assert @new_fix.valid?, @new_fix.errors.inspect
  end

  test "flag with message doesn't need detail" do
    @new_fix.detail = nil
    assert @new_fix.valid?, @new_fix.errors.inspect
  end

  test "flag requires detail or message" do
    @new_fix.detail = nil
    @new_fix.message = ""
    assert @new_fix.invalid?
    assert @new_fix.errors[:message].any?
  end

  test "valid message" do
    assert @new_message.valid?, @new_message.errors.inspect
  end

  test "message requires message" do
    @new_message.message = ""
    assert @new_message.invalid?
    assert @new_message.errors[:message].any?
  end

  test "valid thank" do
    assert @new_thank.valid?, @new_thank.errors.inspect
  end

  test "thank requires explicit public bit" do
    @new_thank.public = nil
    assert @new_thank.invalid?
    assert @new_thank.errors[:public].any?
  end

  test "valid cancel" do
    assert @new_cancel.valid?, @new_cancel.errors.inspect
  end

  test "cancel requires message" do
    @new_cancel.message = ""
    assert @new_cancel.invalid?
    assert @new_cancel.errors[:message].any?
  end

  test "valid student cancel" do
    assert @new_student_cancel.valid?, @new_student_cancel.errors.inspect
  end

  test "validates type" do
    @new_flag.type = "random"
    assert @new_flag.invalid?
  end

  # Derived attributes

  test "book" do
    assert_equal @atlas, events(:cameron_grants_hank).book
  end

  test "student" do
    assert_equal @quentin, events(:hugh_grants_quentin).student
    assert_equal @quentin, events(:quentin_adds_name).student
  end

  test "from student?" do
    assert !events(:hugh_grants_quentin).from_student?
    assert events(:quentin_adds_name).from_student?
  end

  test "from donor?" do
    assert events(:hugh_grants_quentin).from_donor?
    assert !events(:quentin_adds_name).from_donor?
  end

  test "from fulfiller?" do
    @frisco_donation.fulfill @kira
    event = @frisco_donation.flag user: @kira, message: "Fix this"
    @frisco_donation.save!
    assert event.from_fulfiller?

    assert !events(:hugh_grants_quentin).from_fulfiller?
  end

  test "roles to notify" do
    assert_equal [], events(:howard_updates_info).roles_to_notify
    assert_equal [:student], events(:hugh_messages_quentin).roles_to_notify

    @frisco_donation.fulfill @kira
    event = @frisco_donation.flag user: @kira, message: "Fix this"
    @frisco_donation.save!
    assert_equal [:student, :donor], event.roles_to_notify
  end

  # Actions

  test "notify" do
    event = events :hugh_messages_quentin
    assert !event.notified?
    assert_difference("ActionMailer::Base.deliveries.count") { event.notify }
    assert event.notified?
  end

  test "notify to multiple recipients" do
    @frisco_donation.fulfill @kira
    event = @frisco_donation.flag user: @kira, message: "Fix this"
    @frisco_donation.save!

    assert !event.notified?
    assert_difference("ActionMailer::Base.deliveries.count", 2) { event.notify }
    assert event.notified?
  end

  test "notify is idempotent" do
    event = events :quentin_adds_name
    assert event.notified?
    assert_no_difference("ActionMailer::Base.deliveries.count") { event.notify }
  end

  test "notify is noop if no recipient" do
    event = events :howard_updates_info
    assert !event.notified?
    assert_no_difference("ActionMailer::Base.deliveries.count") { event.notify }
  end

  # Conversions

  test "to testimonial" do
    event = events :quentin_thanks_hugh
    testimonial = event.to_testimonial
    assert_equal event, testimonial.source
    assert_equal 'student', testimonial.type
    assert_equal "A thank-you", testimonial.title
    assert_equal event.message, testimonial.text
    assert_equal "Quentin Daniels, studying physics at MIT, to donor Hugh Akston", testimonial.attribution
  end
end
