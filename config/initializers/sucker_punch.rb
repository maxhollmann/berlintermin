SuckerPunch.exception_handler { |ex| Rollbar.error(ex) }
