require 'json'
require 'net/http'
require 'byebug'
require 'csv'

DEPARTMENTS = %w(CSUS ANA ANT ARCLA FAR AST BCH CITA CSB CHM CINE CLAS COL CSC OISUT ASI CRIM DTS DRAMA ES EAS EEB ECO IRE ENG ENVMT ETHIC CERES FRE GGR GER HIS IHPST HMB IMM OTC ASABS INNIS ITA JSP LMP LIN MAT MST MEDGM MUSIC NMC NEW NUSCI GLAF PCL PHL PHY PSL POL PSY RLG COMPG SDST SLA SWK SOC SAS SPA SMC STAT TRIN UC VIC WGSI WDW)

def retrieve_course_info(department)
  api_url = "https://timetable.iit.artsci.utoronto.ca/api/20209/courses?org=#{department}&code=&section=&studyyear=&daytime=&weekday=&prof=&breadth=&deliverymode=&waitlist=&available=&title="
  body = Net::HTTP.get(URI(api_url))

  put_into_rows(body)
end

def put_into_rows(body)
  rows = []
  data = JSON.parse(body)
  data.each do |course, details|
    course_info = details.slice('code', 'org', 'section')

    lectures = details['meetings'].select do |_, detail|
      detail['teachingMethod'] == 'LEC' &&
        detail['enrollmentCapacity'] &&
        detail['enrollmentCapacity'] != '9999' &&
        detail['enrollmentControls'] &&
        detail['enrollmentControls'].any? { |control| control['yearOfStudy'] == '1' }
    end

    lectures.each do |_, details|
      lecture_info = course_info.merge(details.slice('enrollmentCapacity', 'actualEnrolment', 'deliveryMode'))
      rows << lecture_info
    end
  end

  rows
end

def write_to_csv(rows)
  columns = rows[0].keys
  CSV.open("uoft-first-year-data-#{Date.today}.csv", "w") do |csv|
    csv << columns
    rows.each do |row|
      csv << row.values_at(*columns)
    end
  end
end

all_rows = []
DEPARTMENTS.each do |department|
  puts "Retrieving info for #{department}"

  lectures_for_department = retrieve_course_info(department)
  puts "- Found #{lectures_for_department.length} year 1 lectures"

  all_rows += lectures_for_department
end

write_to_csv(all_rows)
