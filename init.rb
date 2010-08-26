if RAILS_ENV.ends_with?("development")
  MAILROOM_DIR = "mailroom"
  
  class ActionMailer::Base
    alias_method :original_create!, :create!
  
    def create!(method_name, *parameters)
      mail = original_create!(method_name, *parameters)
      log_to_file(mail)
      purge_old_mails
      mail
    end

    def log_to_file(mail)
      dir = File.join(Rails.root, "public", MAILROOM_DIR)
      FileUtils.mkdir_p(dir)
      parts = mail.parts.empty? ? [mail] : mail.parts
      parts.each do |part|
        next unless part.content_type == "text/html" || part.content_type == "text/plain"
        path = case part.content_type
               when "text/html"
                 "#{mail.object_id}.html"
               when "text/plain"
                 "#{mail.object_id}.txt"
               end
        file = File.open(File.join(dir, path), "w")
        file.write(part.body)
        file.flush
        file.close
        url = ActionMailer::Base.default_url_options[:host].blank? ? "/#{MAILROOM_DIR}/#{path}" : "http://#{ActionMailer::Base.default_url_options[:host]}/#{MAILROOM_DIR}/#{path}"
        Rails.logger.info("Saved mail, viewable at #{url}")
      end
    end

    def purge_old_mails
      Dir.glob(File.join(Rails.root, "public", MAILROOM_DIR, "*")).select { |f| File.mtime(f) < 1.hour.ago }.each { |f| File.delete(f) }
    end
  end
end
