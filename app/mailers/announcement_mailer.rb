class AnnouncementMailer < ApplicationMailer
  def self.send_announcements(announcement, targets)
    targets.each {|target| send_announcement announcement, target}
  end

  def self.send_announcement(announcement, target)
    mail = self.send announcement, target
    Rails.logger.info "Sending #{announcement} to #{mail.to}"
    mail.deliver
  end

  def announcement(subject)
    mail_to_user @user, subject: subject
  end

  def thank_your_donor(request)
    @request = request
    @user = @request.user
    announcement "Thank your donor for #{@request.book}"
  end
end
