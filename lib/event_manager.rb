require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

# This class can parse EventAttendee csv files, create thank you letters for attendees, and determine popular sign-up dates.
class ParseEvent
  # Defining days of the week for output of Time#wday()  
  WEEKDAYS = {0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday'}.freeze

  # Open and read file
  def initialize(csv_filename)
    @contents = CSV.open(csv_filename,headers: true,header_converters: :symbol)
    @formatted = false 
    @weekday = []
    @hour = []
  end

  # Delete extra characters in zipcodes and return clean zipcode
  def clean_zipcode(zipcode)
    zipcode.to_s.rjust(5,"0")[0..4]
  end

  # Delete extra characters in phone numbers and return clean phone number
  def clean_phone(phone_num)
    phone_num = phone_num.to_s
    phone_num.gsub!('-', '')
    phone_num.gsub!(' ', '')
    phone_num.gsub!('.', '')
    phone_num.gsub!('(', '')
    phone_num.gsub!(')', '')
    phone_num.gsub!('+', '')
    evaluate_phone(phone_num)
  end

  #Evaluate if phone number is valid
  def evaluate_phone(phone_num)
    if phone_num.length == 11 && phone_num[0] == 1
        phone_num[1..10]
      elsif phone_num.length < 10 || phone_num.length > 10
        'Invalid Phone Number'
      else
        phone_num
      end
  end

  # Reformat time into standard format
  def format_time(input)
    @formatted = true
    time = input.split # => ["11/12/08", "10:47"]
    dmyy = time[0].split('/') # => ["11", "12", "08"]
    hhss = time[1].split(':') # => ["10", "47"]
    date = Time.new("20" + dmyy[2], dmyy[0], dmyy[1], hhss[0], hhss[1]) # => 2008-11-12 10:47:00 -0500
    push_time(date)
    return date
  end

  # Adds hours and weekdays to their own arrays 
  def push_time(date)
    @hour.push(date.hour)
    @weekday.push(WEEKDAYS[date.wday])
  end

  # If dates aren't formatted, formats them. Collects count of each hour of registration in a hash and outputs.
  def peak_hours 
    unless @formatted == true
      @weekday = []
      @hour = []
      @contents.each do |row|
        format_time(row[:regdate])
      end
    end
    hours = @hour.reduce(Hash.new(0)) do |hash, result|
      hash[result] += 1
      hash
    end
    puts 'Format: HOUR => NUMBER OF REGISTRATIONS'
    puts hours
  end

  # If dates aren't formatted, formats them. Collects count of each weekday of registration in a hash and outputs.
  def peak_days
    unless @formatted == true
      @weekday = []
      @hour = []
      @contents.each do |row|
        format_time(row[:regdate])
      end
    end
    days = @weekday.reduce(Hash.new(0)) do |hash, result|
      hash[result] += 1
      hash
    end
    puts "Format: DAY OF WEEK => NUMBER OF REGISTRATIONS"
    puts days
  end

  # Finds legislators by zipcode using GoogleCivicAPI
  def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
    begin
      civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
      ).officials
    rescue
      'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
    end
  end

  def save_thank_you_letter(id,form_letter)
    Dir.mkdir('output') unless Dir.exist?('output')
    filename = "output/thanks_#{id}.html"
    File.open(filename, 'w') do |file|
      file.puts form_letter
    end
  end

  def create_thank_you
    template_letter = File.read('form_letter.erb')
    erb_template = ERB.new template_letter
    @contents.each do |row|
      id = row[0]
      name = row[:first_name]
      phone = clean_phone(row[:homephone])
      zipcode = clean_zipcode(row[:zipcode])
      legislators = legislators_by_zipcode(zipcode)
      time = format_time(row[:regdate])
      form_letter = erb_template.result(binding)
      save_thank_you_letter(id,form_letter)
      p time
      p phone
    end
  end
end

# Uncomment the below to create thank you letters based off of name/zipcode/phone number and determine the time at which event registrations most frequently occured on.
# Event = ParseEvent.new('event_attendees.csv')
# Event.create_thank_you
# Event.peak_hours
# Event.peak_days