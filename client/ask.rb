require "optparse"
require "net/http"
require "json"

options = {}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ask --office a|b --path PATH [--data JSON]"

  opts.on("-o", "--office OFFICE", %w[a b],
          "Office to contact: a or b") do |office|
    options[:office] = office
  end

  opts.on("-p", "--path PATH",
          "Endpoint: /health, /seat, or /book") do |path|
    options[:path] = path
  end

  opts.on("-d", "--data JSON",
          "Send POST with a JSON object; otherwise use GET") do |data|
    options[:data] = data
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit 0
  end
end

# Validate arguments before making a network request.
begin
  parser.parse!

  unless ARGV.empty?
    raise OptionParser::InvalidArgument,
          "unexpected arguments: #{ARGV.join(' ')}"
  end

  %i[office path].each do |name|
    unless options.key?(name)
      raise OptionParser::MissingArgument, "--#{name}"
    end
  end

  unless %w[/health /seat /book].include?(options[:path])
    raise OptionParser::InvalidArgument,
          "--path must be /health, /seat, or /book"
  end

  if options.key?(:data)
    body = JSON.parse(options[:data])

    unless body.is_a?(Hash)
      raise OptionParser::InvalidArgument,
            "--data must be a JSON object"
    end
  end
rescue OptionParser::ParseError, JSON::ParserError => error
  warn "Argument error: #{error.message}"
  warn parser
  exit 2
end

# Service names resolve inside the client's cap-lab namespace.
uri = URI(
  "http://office-#{options.fetch(:office)}:4567#{options.fetch(:path)}"
)

request =
  if options.key?(:data)
    Net::HTTP::Post.new(uri).tap do |req|
      req["Content-Type"] = "application/json"
      req.body = options[:data]
    end
  else
    Net::HTTP::Get.new(uri)
  end

begin
  # nil disables environment HTTP proxies for these cluster requests.
  http = Net::HTTP.new(uri.host, uri.port, nil)
  http.open_timeout = 2
  http.read_timeout = 10
  http.write_timeout = 5

  # Keep each invocation to one attempt for our experiments.
  http.max_retries = 0

  response = http.start { |connection| connection.request(request) }

  puts "HTTP #{response.code}"
  puts response.body

  # HTTP 409 and 503 are meaningful lab results, not client failures.
  exit 0
rescue SocketError, SystemCallError, Timeout::Error,
       EOFError, IOError, Net::HTTPBadResponse => error
  warn "Request failed: #{error.class}: #{error.message}"
  exit 1
end
