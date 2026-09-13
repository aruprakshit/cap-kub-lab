require "sinatra"
require "json"
require "thread"
require "net/http"

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

BOOKING = { customer: nil }
BOOKING_LOCK = Mutex.new
OFFICE = ENV.fetch("OFFICE", "a")
AUTHORITY_URL = ENV.fetch("AUTHORITY_URL", "http://office-a:4567")

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
  forward_to_authority if OFFICE == "b"

  customer = BOOKING_LOCK.synchronize { BOOKING[:customer] }

  {
    seat: "A1",
    available: customer.nil?,
    customer: customer
  }.to_json
end

post "/book" do
  forward_to_authority if OFFICE == "b"
  
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
    if BOOKING[:customer]
      status 409
      { error: "Seat already booked", customer: BOOKING[:customer] }.to_json
    else
      BOOKING[:customer] = customer
      status 201
      { seat: "A1", customer: customer, confirmed: true }.to_json
    end
  end
end
