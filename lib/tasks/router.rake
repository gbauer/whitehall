require 'router'
require 'logger'

namespace :router do
  task :router_environment => :environment do
    @logger = Logger.new STDOUT
    @logger.level = Logger::DEBUG
    @router = Router.new("http://router.cluster:8080/router", @logger)
    @slug = "whitehall"
  end

  task :register_application => :router_environment do
    platform = ENV['FACTER_govuk_platform']
    url = "whitehall.#{platform}.alphagov.co.uk"
    @logger.info "Registering application..."
    @router.update_application @slug, url
  end

  task :register_routes => :router_environment do
    @router.create_route @slug, "prefix", @slug
    VanityRedirector.new(Rails.root.join("app", "data", "vanity-redirects.csv")).each do |r, _|
      @router.create_route(r, "full", @slug)
      @router.create_route(r.upcase, "full", @slug)
    end
  end

  desc "Register whitehall application and routes with the router (run this task on server in cluster)"
  task :register => [ :register_application, :register_routes ]
end