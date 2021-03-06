# Calculates metrics and user analytics for the site.
class Metrics
  def request_pipeline
    calculate_metrics [
      {name: 'Active',   value: Request.active.count},
      {name: 'Granted',  value: Request.granted.count,   denominator_name: 'Active'},
      {name: 'Sent',     value: Donation.sent.count,     denominator_name: 'Granted'},
      {name: 'Received', value: Donation.received.count, denominator_name: 'Sent'},
      {name: 'Read',     value: Donation.read.count,     denominator_name: 'Received'},
      {name: 'Canceled', value: Request.canceled.count,  denominator_name: 'Total',   denominator_value: Request.count},
    ]
  end

  def send_money_pipeline
    calculate_metrics [
      {name: 'Paid',              value: Donation.paid.count,           denominator_name: 'Total granted', denominator_value: Donation.active.count},
      {name: 'Fulfilled',         value: Donation.fulfilled.count,      denominator_name: 'Paid'},
      {name: 'Sent by volunteer', value: Donation.fulfilled.sent.count, denominator_name: 'Fulfilled'},
    ]
  end

  def time_columns
    @time_columns ||= ["Total", "3 days", "1 wk", "2 wks", "3 wks", "1 mo", "2 mos", "3 mos"]
  end

  def times
    @times = time_columns.inject({}) do |hash,column|
      time = case column
      when /total/i then 0
      else
        number, unit = column.split
        method = case unit[0]
        when "d" then :days
        when "w" then :weeks
        when "m" then :months
        end
        number.to_i.send method
      end
      hash.merge(column => time)
    end
  end

  def now
    @now ||= Time.now
  end

  def breakdown_by_time(relation, timestamp_column = :created_at)
    time_columns.inject({}) do |hash,column|
      time = times[column]
      relation = relation.where("#{timestamp_column} < ?", now - time) if time > 0
      hash.merge(column => relation.count)
    end
  end

  def pipeline_breakdown
    rows = [
        {name: 'Open requests',              values: breakdown_by_time(Request.not_granted)},
        {name: 'Needs donor action',         values: breakdown_by_time(Donation.needs_donor_action, 'donations.created_at')},
        {name: 'Needs fulfillment',          values: breakdown_by_time(Donation.needs_fulfillment, 'donations.updated_at')},
        {name: 'Needs sending by volunteer', values: breakdown_by_time(Donation.fulfilled.needs_sending, 'donations.created_at')},
        {name: 'In transit',                 values: breakdown_by_time(Donation.in_transit, :status_updated_at)},
        {name: 'Reading',                    values: breakdown_by_time(Donation.reading, :status_updated_at)},
    ]
    Metrics::Table.new time_columns, rows
  end

  def daily_fulfillments
    Metrics::FulfillmentsTable.new group: :day, since: 10.days.ago
  end

  def weekly_fulfillments
    Metrics::FulfillmentsTable.new group: :week, since: 9.weeks.ago
  end

  def donation_metrics
    calculate_metrics [
      {name: 'Flagged',      value: Donation.flagged.count,      denominator_name: 'Not sent', denominator_value: Donation.not_sent.count},
      {name: 'Needs thanks', value: Donation.needs_thanks.count, denominator_name: 'Received', denominator_value: Donation.received.count},
      {name: 'Thanked',      value: Donation.thanked.count,      denominator_name: 'Active',   denominator_value: Donation.active.count},
      {name: 'Reviewed',     value: Review.count,                denominator_name: 'Read',     denominator_value: Donation.read.count},
      {name: 'Recommended',  value: Review.recommended.count,    denominator_name: 'Reviewed'},
      {name: 'Canceled',     value: Donation.canceled.count,     denominator_name: 'Total'},
      {name: 'Total',        value: Donation.count},
    ]
  end

  def pledge_metrics
    pledges = Pledge.active
    recurring = pledges.recurring

    calculate_metrics [
      {name: 'Active pledges',        value: pledges.count},
      {name: 'Books pledged',         value: pledges.sum(:quantity)},
      {name: 'Average pledge size',   value: pledges.average(:quantity)},
      {name: 'Donations so far',      value: Donation.active.joins(:pledge).merge(pledges).count, denominator_name: 'Books pledged'},
      {name: 'Recurring pledges',     value: recurring.count,                                     denominator_name: 'Active pledges'},
      {name: 'Books pledged monthly', value: recurring.sum(:quantity)},
    ]
  end

  def past_pledge_metrics
    pledges = Pledge.not_active

    calculate_metrics [
      {name: 'Past pledges',             value: pledges.count},
      {name: 'Ended pledges',            value: Pledge.ended.count,                                  denominator_name: 'Past pledges'},
      {name: 'Canceled pledges',         value: Pledge.canceled.count,                               denominator_name: 'Past pledges'},
      {name: 'Past books pledged',       value: pledges.sum(:quantity)},
      {name: 'Average past pledge size', value: pledges.average(:quantity)},
      {name: 'Past pledge donations',    value: Donation.active.joins(:pledge).merge(pledges).count, denominator_name: 'Past books pledged'},
    ]
  end

  def book_leaderboard
    request_counts = Request.unscoped.active.group(:book_id).count
    donation_counts = Donation.unscoped.active.joins(:request).group(:book_id).count
    rows = Book.all.map do |book|
      {
        name: book.title,
        values: {
          # Hit a weird case against a PostgreSQL db where the keys were coming out as ints for the request
          # counts but strings for the donations... going to be a little defensive here  -Jason 3 Nov 2012
          "Requested" => (request_counts[book.id] || request_counts[book.id.to_s] || 0),
          "Donated" => (donation_counts[book.id] || donation_counts[book.id.to_s] || 0),
        }
      }
    end
    rows.sort_by! {|row| -row[:values]["Requested"]}

    Metrics::Table.new ["Requested", "Donated"], rows
  end

  def referral_counts
    @referral_counts ||= Referral.unscoped.group(:source, :medium).count
  end

  def count_referrals(model)
    counts = model.unscoped.joins(:referral).group(:source, :medium).count
    counts.default = 0
    counts
  end

  def user_referrals
    @user_referrals ||= count_referrals User
  end

  def request_referrals
    @request_referrals ||= count_referrals Request
  end

  def pledge_referrals
    @pledge_referrals ||= count_referrals Pledge
  end

  def referral_metrics_keys
    keys = referral_counts.keys.map {|pair| {source: pair.first, medium: pair.second}}
    keys.sort_by {|key| "#{key[:source]}#{key[:medium]}"}
  end

  def referral_metrics(key)
    pair = [key[:source], key[:medium]]
    calculate_metrics [
      {name: 'Clicks',   value: referral_counts[pair]},
      {name: 'Signups',  value: user_referrals[pair],    denominator_name: 'Clicks'},
      {name: 'Requests', value: request_referrals[pair], denominator_name: 'Signups'},
      {name: 'Pledges',  value: pledge_referrals[pair],  denominator_name: 'Signups'},
    ]
  end

private
  def calculate_metrics(metrics)
    values = metrics.inject({}) {|hash,metric| hash.merge(metric[:name] => metric[:value])}

    metrics.each do |metric|
      value = metric[:value]
      denominator_name = metric[:denominator_name]
      denominator_value = metric[:denominator_value]
      denominator_value ||= values[denominator_name] if denominator_name
      metric[:percent] = value.to_f / denominator_value if denominator_value && denominator_value != 0
    end
  end
end
