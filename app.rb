require "sinatra"
require "json"
require "thread"

set :bind, "0.0.0.0"
set :port, 4567

BOOKING = { customer: nil }
BOOKING_LOCK = Mutex.new

before do
  content_type :json
end

get "/health" do
  { status: "ok" }.to_json
end

get "/seat" do
  customer = BOOKING_LOCK.synchronize { BOOKING[:customer] }

  {
    seat: "A1",
    available: customer.nil?,
    customer: customer
  }.to_json
end

post "/book" do
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
