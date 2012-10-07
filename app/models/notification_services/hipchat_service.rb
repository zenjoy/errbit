if defined? HipChat
  class NotificationServices::HipchatService < NotificationService
    Label = 'hipchat'
    Fields = [
      [:api_token, {
        :placeholder => "API Token"
      }],
      [:room_id, {
        :placeholder => "Room ID",
        :label       => "Room ID"
      }],
    ]

    def check_params
      if Fields.any? { |f, _| self[f].blank? }
        errors.add :base, 'You must specify your Hipchat API token and Room ID'
      end
    end

    def create_notification(problem)
      url = app_problem_url problem.app, problem
      
      last_error = problem.errs.last
      last_notice = last_error.notices.last if last_error
      error_url = last_notice.request['url'] if last_notice && last_notice.request

      message = <<-MSG.strip_heredoc
        <b>#{ERB::Util.html_escape problem.app.name}</b>
        (<a href='#{url}'>view error</a>)
        <br>&nbsp;-&nbsp;<b>#{problem.message.to_s.truncate(100)} [#{ problem.environment }] [#{ problem.where }]</b>
      MSG

      message << "triggered at <a href='#{CGI::escapeHTML(error_url)}'>#{CGI::escapeHTML(error_url)}</a>" if error_url

      client = HipChat::Client.new(api_token)
      client[room_id].send('Errbit', message, :color => 'red')
    end
  end
end