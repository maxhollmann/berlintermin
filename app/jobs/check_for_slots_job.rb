# -*- coding: utf-8 -*-

class Bot
  class NoFreeSlot < StandardError; end

  include Capybara::DSL

  attr_reader :logger

  def initialize(concern_id = 326541, logger: Rails.logger)
    @concern_id = concern_id
    @logger = logger
  end

  def wait(min = 1, max = 5)
    sleep min + rand * (max - min)
  end

  def goto_day_selection
    logger.info "Going to day selection"
    visit "https://service.berlin.de/terminvereinbarung/termin/tag.php?termin=1&dienstleister[]=122210&dienstleister[]=122217&dienstleister[]=122219&dienstleister[]=122227&dienstleister[]=122231&dienstleister[]=122238&dienstleister[]=122243&dienstleister[]=122252&dienstleister[]=122260&dienstleister[]=122262&dienstleister[]=122254&dienstleister[]=122271&dienstleister[]=122273&dienstleister[]=122277&dienstleister[]=122280&dienstleister[]=122282&dienstleister[]=122284&dienstleister[]=122291&dienstleister[]=122285&dienstleister[]=122286&dienstleister[]=122296&dienstleister[]=150230&dienstleister[]=122301&dienstleister[]=122297&dienstleister[]=122294&dienstleister[]=122312&dienstleister[]=122314&dienstleister[]=122304&dienstleister[]=122311&dienstleister[]=122309&dienstleister[]=317869&dienstleister[]=324433&dienstleister[]=325341&dienstleister[]=324434&dienstleister[]=324435&dienstleister[]=122281&dienstleister[]=324414&dienstleister[]=122283&dienstleister[]=122279&dienstleister[]=122276&dienstleister[]=122274&dienstleister[]=122267&dienstleister[]=122246&dienstleister[]=122251&dienstleister[]=122257&dienstleister[]=122208&dienstleister[]=122226&anliegen[]=120686&herkunft=%2Fterminvereinbarung%2F"
    #"https://service.berlin.de/terminvereinbarung/termin/tag.php?termin=1&dienstleister=326541&anliegen[]=121921&herkunft=1"
  end

  def goto_first_free_date
    months_ahead = 0

    begin
      day = first("td.buchbar")
      logger.info (day.present? ? "Found a free day!!!" : "No free days") + " (#{months_ahead} ahead)"

      raise NoFreeSlot, "no free day found" unless day

      logger.info "Going to day"
      wait(0.5, 2)
      raise NoFreeSlot, "couldn't click on day" unless day.click
    rescue NoFreeSlot
      if months_ahead < 1 && first("td.nichtbuchbar").present?
        logger.info "Trying next month"
        wait
        find("a", text: "nächsten Monat").click
        months_ahead += 1
        retry
      else
        logger.info "No more months to try"
        raise
      end
    end
  end

  def goto_first_free_time(retries = 2)
    time = first("th.buchbar")

    logger.info "Found time: #{time.present?}"

    raise NoFreeSlot, "no free time found" unless time

    logger.info "Going to time"
    wait(0.5, 2)
    raise NoFreeSlot, "couldn't click on time" unless time.click

  rescue NoFreeSlot
    binding.pry

    if retries > 0
      logger.info "Retrying going to time"
      retries -= 1
      sleep 1
      retry
    else
      raise
    end
  end

  def submit_form(request)
    logger.info "Filling in and submitting form for #{request.name} #{request.email}"

    fill_in "Nachname", with: request.name
    fill_in "EMail", with: request.email
    fill_in "telefonnummer_fuer_rueckfragen", with: request.phone
    check "agbbestaetigung"
    accept_confirm do
      first("#sendbutton").click
    end

    request.update!(appointment_made_at: Time.now)
    logger.info "Appointment made #{request.appointment_made_at}"
  end

  def update_request(request)
    sleep 10

    number            = first(".number-red-big").text
    cancellation_code = find(:xpath, find(".title", text: "Code zur Absage").path + "/../span").text

    logger.info "Appointment number = #{number}, cancellation code = #{cancellation_code}"

    request.update!(
      appointment_number: number,
      appointment_cancellation_code: cancellation_code,
    )
  end
end

class CheckForSlotsJob < ActiveJob::Base
  queue_as :default

  def perform
    bot = Bot.new(logger: logger)

    bot.goto_day_selection
    bot.goto_first_free_date
    bot.goto_first_free_time

    request = AppointmentRequest.outstanding.first
    unless request
      Rails.logger.info "No outstanding request, exiting."
      return
    end


    bot.submit_form(request)
    bot.update_request(request)

  rescue Bot::NoFreeSlot
    if bot.status_code == 429
      Rails.logger.info "Got 429 calm down, retrying in 3 minutes"
      sleep 60*3
    else
      Rails.logger.info "No free slot, retrying in 15 seconds"
      sleep 15
    end

    retry
  rescue => e
    Rails.logger.info bot.status_code

    Rails.logger.info "Unknown error #{e.class} #{e.message}, retrying in 60 seconds"
    Rollbar.error e
    sleep 60
    retry
  end
end
