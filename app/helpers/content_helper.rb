module ContentHelper
  def time_in_words(time)
    if time.today?
      "#{time_ago_in_words time} ago"
    elsif time > 1.week.ago
      "last #{Date::DAYNAMES[time.wday]}"
    elsif time.year == Date.today.year
      l time, format: :day_and_month
    else
      l time, format: :day_month_and_year
    end
  end

  def icon_text(icon, text = nil)
    [
      "<i class='fa fa-#{icon}'></i>",
      text
    ].compact.join("&nbsp;").html_safe
  end

  def show_if_changed(scope, text = nil, &block)
    RequestStore.store[:show_if_changed_last] ||= {}

    content = if text
                text
              else
                capture(&block)
              end

    if RequestStore.store[:show_if_changed_last][scope] != content
      RequestStore.store[:show_if_changed_last][scope] = content

      return content
    end
  end
end
