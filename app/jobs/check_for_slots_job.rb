# -*- coding: utf-8 -*-

class Page < SitePrism::Page
  class Error     < StandardError ; end
  class WrongPage < Error         ; end
end

class NoBookableDaysFound < StandardError; end

class DateSelectionPage < Page
  set_url "https://service.berlin.de/terminvereinbarung/termin/tag.php?termin=1&dienstleister[]=122210&dienstleister[]=122217&dienstleister[]=122219&dienstleister[]=122227&dienstleister[]=122231&dienstleister[]=122238&dienstleister[]=122243&dienstleister[]=122252&dienstleister[]=122260&dienstleister[]=122262&dienstleister[]=122254&dienstleister[]=122271&dienstleister[]=122273&dienstleister[]=122277&dienstleister[]=122280&dienstleister[]=122282&dienstleister[]=122284&dienstleister[]=122291&dienstleister[]=122285&dienstleister[]=122286&dienstleister[]=122296&dienstleister[]=150230&dienstleister[]=122301&dienstleister[]=122297&dienstleister[]=122294&dienstleister[]=122312&dienstleister[]=122314&dienstleister[]=122304&dienstleister[]=122311&dienstleister[]=122309&dienstleister[]=317869&dienstleister[]=324433&dienstleister[]=325341&dienstleister[]=324434&dienstleister[]=324435&dienstleister[]=122281&dienstleister[]=324414&dienstleister[]=122283&dienstleister[]=122279&dienstleister[]=122276&dienstleister[]=122274&dienstleister[]=122267&dienstleister[]=122246&dienstleister[]=122251&dienstleister[]=122257&dienstleister[]=122208&dienstleister[]=122226&anliegen[]=120686&herkunft=%2Fterminvereinbarung%2F"
  #set_url "https://service.berlin.de/terminvereinbarung/termin/tag.php?termin=1&dienstleister=326541&anliegen[]=121921&herkunft=1"

  elements :calendar_tables, ".calendar-month-table"
  elements :bookable_days, "td.buchbar"
  elements :unbookable_days, "td.nichtbuchbar"
  element :next_month_link, :xpath, "//a[contains(text(),'nächsten Monat')]"

  def verify_page!
    raise WrongPage, "no calendar tables found" unless has_calendar_tables?
  end

  def skip_to_month_with_bookable_day(tries = 1)
    return true if has_bookable_days?

    if has_unbookable_days? && tries > 0
      logger.info "No bookable days, trying next month (#{tries} tries left)"

      next_month_link.click
      verify_page!
      skip_to_month_with_bookable_day(tries - 1)
    else
      raise NoBookableDaysFound
    end
  end
end

class TimeSelectionPage < Page
  elements :time_slot_links, "th.buchbar > a, td.frei > a"

  def verify_page!
    raise WrongPage, "no time slots found" unless has_time_slot_links?
  end

  def goto_first_free_time_slot
    time_slot_links.first.click
  end
end

class BookingPage < Page
  element :name_field,    "#Nachname"
  element :email_field,   "#EMail"
  element :phone_field,   "#telefonnummer_fuer_rueckfragen"
  element :tos_checkbox,  "#agbbestaetigung"
  element :submit_button, "#sendbutton"

  def submit_form(request)
    name_field.set  request.name  if has_name_field?
    email_field.set request.email if has_email_field?
    phone_field.set request.phone if has_phone_field?
    tos_checkbox.set true

    accept_confirm do
      submit_button.click
    end
  end

  def verify_page!
    raise WrongPage, "no submit button found" unless has_submit_button?
  end
end

class BookingConfirmationPage < Page
  element :number,            :xpath, "//*[contains(text(), 'Ihre Vorgangsnummer')]/../*[@class='number-red-big']"
  element :cancellation_code, :xpath, "//*[contains(text(), 'Code zur Absage')]/../span"

  def verify_page!
    raise WrongPage, "no number found" unless has_number?
    raise WrongPage, "no cancellation code found" unless has_cancellation_code?
  end
end


class CheckForSlotsJob < ActiveJob::Base
  queue_as :default

  class NoMatchingRequest < StandardError; end

  def perform
    logger.info "Visiting date selection page"

    p = DateSelectionPage.new
    p.load
    p.verify_page!

    logger.info "Skip to month with bookable day"

    p.skip_to_month_with_bookable_day

    logger.info "Go to first bookable day"

    p.bookable_days.first.click

    p = TimeSelectionPage.new
    p.verify_page!

    logger.info "Go to first free time slot"

    p.goto_first_free_time_slot

    p = BookingPage.new
    p.verify_page!

    request = AppointmentRequest.outstanding.first
    raise NoMatchingRequest unless request

    logger.info "Submitting form for #{request.email}"

    p.submit_form(request)
    request.update!(appointment_made_at: Time.now)

    logger.info "Appointment made #{request.appointment_made_at}, updating booking info"

    p = BookingConfirmationPage.new
    p.verify_page!

    request.update!(
      appointment_number: p.number.text,
      appointment_cancellation_code: p.cancellation_code.text,
    )


  rescue NoBookableDaysFound
    logger.info "No bookable days, retrying in 15 seconds"
    sleep 15; retry

  rescue NoMatchingRequest
    logger.info "No matching request for time slot"
    sleep 15; retry

  rescue Page::WrongPage => e
    if p.status_code == 429
      logger.info "Got 429! Retrying in 60 seconds"
      sleep 60; retry
    else
      logger.error "Not on right page (#{e}), status: #{p.status_code}, page: #{p.save_page}, screenshot: #{p.save_screenshot}"
      sleep 60; retry
    end

  rescue => e
    logger.error "Unknown error #{e.class} #{e.message}"
    logger.error "status: #{p.status_code}, page: #{p.save_page}, screenshot: #{p.save_screenshot}"
    Rollbar.error e
    sleep 60; retry
  end
end
