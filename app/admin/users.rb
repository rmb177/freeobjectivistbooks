ActiveAdmin.register User do
  actions :all, except: [:new, :destroy]

  member_action :spoof, method: :post do
    @user = User.find params[:id]
    set_current_user @user
    redirect_to profile_url
  end

  action_item only: :show do
    link_to "Spoof user", spoof_admin_user_path(user), method: :post
  end

  filter :name
  filter :email
  filter :studying
  filter :school
  filter :location_name, as: :string
  filter :blocked, as: :check_boxes

  index do
    selectable_column
    column :name
    column :email
    column :location
    default_actions
  end

  show do |user|
    attributes_table do
      row :name
      row :email
      row :studying if user.studying.present?
      row :school if user.school.present?
      row :location
      row :address if user.address.present?
      row(:balance) {humanized_money_with_symbol user.balance} if user.balance > 0
      row :roles if user.roles.any?
      row :blocked if user.blocked?
      row :created_at
      row :updated_at
    end

    if user.requests.any?
      panel "Requests" do
        table_for user.requests do
          column :book
          column :reason
          column :donor
          column(:status) {|request| status_headline request}
          column(:view) {|request| link_to "View", admin2_request_path(request)}
        end
      end
    end

    if user.pledges.any?
      panel "Pledges" do
        table_for user.pledges do
          column :quantity
          column(:recurring?) {|pledge| pledge.recurring? ? "every month" : "this month"}
          column(:active?) {|pledge| pledge.ended? ? "ended" : pledge.canceled? ? "canceled" : "active"}
          column(:status) {|pledge| pledge.status}
          column(:view) {|pledge| link_to "View", admin2_pledge_path(pledge)}
        end
      end
    end

    if user.donations.any?
      panel "Donations" do
        table_for user.donations do
          column :student
          column :book
          column(:status) {|donation| donation.status.humanize}
          column(:paid) {|donation| donation.paid? if donation.can_send_money?}
          column(:view_request) {|donation| link_to "View request", admin2_request_path(donation.request)}
        end
      end
    end

    if user.orders.any?
      panel "Orders" do
        table_for user.orders do
          column :description
          column :total
          column :paid?
          column(:view) {|order| link_to "View", admin2_order_path(order)}
        end
      end
    end

    panel "Contributions" do
      table_for user.contributions do
        column :created_at
        column :order
        column(:amount) {|contribution| contribution.amount.format}
        column(:view) {|contribution| link_to "View", admin2_contribution_path(contribution)}
      end
      div do
        link_to "Add contribution", new_admin2_user_contribution_path(user), class: "button"
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :email
      f.input :studying
      f.input :school
      f.input :location_name
      f.input :address
      f.input :is_volunteer, as: :boolean
      f.input :is_admin, as: :boolean
      f.input :blocked
    end
    f.actions
  end
end
