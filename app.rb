require "sinatra"
require "json"
require "thread"
require "net/http"
require "securerandom"

set :bind, "0.0.0.0"
set :port, 4567
set :host_authorization, {
  permitted_hosts: [
    "localhost",
    "127.0.0.1",
    "office-a",
    "office-b"
  ]
}

BOOKINGS = {}
BOOKING_LOCK = Mutex.new
OFFICE = ENV.fetch("OFFICE", "a")
AUTHORITY_URL = ENV.fetch("AUTHORITY_URL", "http://office-a:4567")
COORDINATION_MODE = ENV.fetch("COORDINATION_MODE", "authority")

unless %w[authority local].include?(COORDINATION_MODE)
  abort "COORDINATION_MODE must be authority or local"
end

before do
  content_type :json
end

helpers do
  def forward_to_authority
    uri = URI("#{AUTHORITY_URL}#{request.path_info}")

    upstream_request =
      if request.request_method == "POST"
        Net::HTTP::Post.new(uri).tap do |req|
          req["Content-Type"] = "application/json"
          req.body = request.body.read
        end
      else
        Net::HTTP::Get.new(uri)
      end

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      nil,
      open_timeout: 1,
      read_timeout: 2
    ) do |http|
      http.request(upstream_request)
    end

    halt response.code.to_i,
         { "Content-Type" => "application/json" },
         response.body
  rescue Timeout::Error, SocketError, SystemCallError, EOFError
    halt 503, {
      error: "Cannot reach authority",
      office: OFFICE,
      detail: "A booking may have completed before communication failed."
    }.to_json
  end
end

get "/health" do
  { status: "ok" }.to_json
end

get "/seat" do
  if COORDINATION_MODE == "authority" && OFFICE == "b"
    forward_to_authority
  end

  bookings = BOOKING_LOCK.synchronize { BOOKINGS.values.map(&:dup) }

  {
    seat: "A1",
    available: bookings.empty?,
    conflict: bookings.length > 1,
    bookings: bookings
  }.to_json
end

post "/book" do
  if COORDINATION_MODE == "authority" && OFFICE == "b"
    forward_to_authority
  end

  begin
    payload = JSON.parse(request.body.read)
  rescue JSON::ParserError
    halt 400, { error: "Send valid JSON" }.to_json
  end

  customer = payload.is_a?(Hash) ? payload["customer"] : nil

  unless customer.is_a?(String) && !customer.strip.empty?
    halt 400, { error: "Provide a nonempty customer name" }.to_json
  end

  BOOKING_LOCK.synchronize do
    if BOOKINGS.any?
      status 409

      {
        error: "Seat already booked",
        bookings: BOOKINGS.values
      }.to_json
    else
      booking = {
        id: SecureRandom.uuid,
        seat: "A1",
        customer: customer,
        office: OFFICE
      }

      BOOKINGS[booking[:id]] = booking

      status 201
      { confirmed: true, booking: booking }.to_json
    end
  end
end

post "/replicate" do
  unless COORDINATION_MODE == "local"
    halt 409, { error: "Replication requires local mode" }.to_json
  end

  begin
    records = JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError
    halt 400, { error: "Send valid JSON" }.to_json
  end

  valid = records.is_a?(Array) && records.all? do |record|
    record.is_a?(Hash) &&
      record[:id].is_a?(String) && !record[:id].empty? &&
      record[:seat] == "A1" &&
      record[:customer].is_a?(String) &&
      !record[:customer].strip.empty? &&
      %w[a b].include?(record[:office])
  end

  unless valid
    halt 400, { error: "Send an array of valid booking records" }.to_json
  end

  BOOKING_LOCK.synchronize do
    records.each do |record|
      BOOKINGS[record[:id]] ||= {
        id: record[:id],
        seat: record[:seat],
        customer: record[:customer],
        office: record[:office]
      }
    end

    {
      office: OFFICE,
      booking_count: BOOKINGS.length,
      conflict: BOOKINGS.length > 1
    }.to_json
  end
end
