module ErrsHelper

  def last_notice_at err
    err.last_notice_at || err.created_at
  end

  def err_confirm
    Errbit::Config.confirm_resolve_err === false ? nil : 'Seriously?'
  end

  def link_to_github app, line, text=nil
    file_name   = line['file'].split('/').last
    file_path   = line['file'].gsub('[PROJECT_ROOT]', '')
    line_number = line['number']
    link_to(text || file_name, "#{app.github_url_to_file(file_path)}#L#{line_number}", :target => '_blank')
  end

  def errs_page_title
    @app ? @app.name : (show_resolved_errs? ? 'All Errs' : 'Unresolved Errs')
  end

  def show_resolved_errs?
    params[:all_errs] == 'true'
  end

  def errs_atom_link
    @app ?
      auto_discovery_link_tag(:atom, app_url(@app, User.token_authentication_key => current_user.authentication_token, :format => "atom"), :title => "Errbit notices for #{@app.name} at #{root_url}") :
      auto_discovery_link_tag(:atom, errs_url(User.token_authentication_key => current_user.authentication_token, :format => "atom"), :title => "Errbit notices at #{root_url}")
  end
end
