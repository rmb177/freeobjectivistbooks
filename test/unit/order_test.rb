require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  def setup
    @user = build :donor
    @donations = build_list :donation, 3, user: @user
  end

  test "populate" do
    order = Order.new user: @user, donations: @donations
    assert_equal Money.parse(30), order.subtotal
    assert_equal Money.parse(0), order.balance_applied
    assert_equal Money.parse(30), order.total
  end

  test "populate with balance" do
    @user.balance = 10
    order = Order.new user: @user, donations: @donations
    assert_equal Money.parse(30), order.subtotal
    assert_equal Money.parse(10), order.balance_applied
    assert_equal Money.parse(20), order.total
  end

  test "populate with full balance" do
    @user.balance = 30
    order = Order.new user: @user, donations: @donations
    assert_equal Money.parse(30), order.subtotal
    assert_equal Money.parse(30), order.balance_applied
    assert_equal Money.parse(0), order.total
  end

  test "populate with excess balance" do
    @user.balance = 50
    order = Order.new user: @user, donations: @donations
    assert_equal Money.parse(30), order.subtotal
    assert_equal Money.parse(30), order.balance_applied
    assert_equal Money.parse(0), order.total
  end

  test "populate with negative balance" do
    @user.balance = -10 # should never happen, but just in case...
    order = Order.new user: @user, donations: @donations
    assert_equal Money.parse(30), order.subtotal
    assert_equal Money.parse(-10), order.balance_applied
    assert_equal Money.parse(40), order.total
  end

  test "description" do
    order = Order.new user: @user, donations: @donations
    assert_match /Book \d+ to Student \d+ in Anytown, USA and 2 more books/, order.description
  end
end