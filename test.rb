# before running the first time:
#   $ bundle install
#
# run with:
#   $ bundle exec ruby test.rb

require 'faker'
require 'influxdb'
require 'as-duration'

def query(db, qs)
  puts "Q: #{qs}"
  db.query(qs)[0]['values']
end

db = InfluxDB::Client.new('test', host: 'localhost', time_precision: 's')

db.delete_database
db.create_database
(0...Faker::Number.between(8, 20)).each do
  t = DateTime.now - (Faker::Number.between(1, 60).minutes)
  val = Faker::Number.between(1, 3)
  o = {
    values: { val: val },
    timestamp: t.to_i
  }

  puts "> #{val} @ #{t}"
  db.write_point('vals', o)
end

all = query(db, 'SELECT * FROM vals ORDER BY time')

st = Time.parse(all[0]['time'])
en = Time.parse(all[-1]['time'])
total_dur = en - st
puts "st: #{st}, en: #{en}"

# keep the first item
last = all[0]

# for tail of array inject/reduce to produce a map of "val" => "total
# duration at the value"
totals = all[1..-1].inject({}) do |o, vals|
  # get the value in o for the 'val', default to 0.0 if we've never
  # seen this 'val' yet
  prev = o.fetch(last['val'], 0.0)

  # duration in seconds from the current val to the previous
  dur = Time.parse(vals['time']) - Time.parse(last['time'])

  puts "= updating #{last['val']} to #{prev} + #{dur}"
  rv = o.merge(last['val'] => prev + dur)
  last = vals
  
  rv
end

puts "totals (over #{total_dur} seconds)"
totals.each do |val, dur|
  puts "#{val}: #{dur / total_dur}"
end
  
  
  
