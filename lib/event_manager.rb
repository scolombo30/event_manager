# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(phone)
  phone = phone.to_s.gsub(' ', '').gsub('-', '').gsub('(', '').gsub(')', '').gsub('.', '')
  phone_array = phone.split('')
  return phone if phone_array.size == 10
  return 'invalid phone number' if phone_array.size < 10 || phone_array.size > 11
  return 'invalid phone number' if phone_array.size == 11 && phone_array[0] != 1
  return phone_array[1..phone_array.size].join if phone_array.size == 11 && phone_array[0] == 1
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def find_best_hour(contents)
  hours = contents.reduce(Hash.new(0)) do |hash, row|
    hour = Time.parse(row[:regdate].split(' ')[1]).hour.to_s
    hash[hour] += 1
    hash
  end
  contents.rewind # rewind pointer to begin of file
  hours.select { |k, v| v == hours.values.max }
end

def find_best_days(contents)
  days = contents.reduce(Hash.new(0)) do |hash, row|
    date = (row[:regdate].split(' ')[0]).split('/').rotate(-1).reverse.join('-')
    day = Date.parse(date).strftime('%A')
    hash[day] += 1
    hash
  end
  contents.rewind # rewind pointer to begin of file
  days.select { |k, v| v == days.values.max }
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.html')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_numbers(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{id} #{name} #{zipcode} #{phone_number}"
end

contents.rewind # rewind pointer to begin of file

best_hours = find_best_hour(contents)
puts "#{best_hours.size == 1 ? 'The hour with the most registrations is: ' : 'The hours with the most registrations are: '}"
best_hours.each { |k,| puts k }

best_days = find_best_days(contents)
puts best_days
puts "#{best_days.size == 1 ? 'The day with the most registrations is: ' : 'The days with the most registrations are: '}"
best_days.each { |k,| puts k }
