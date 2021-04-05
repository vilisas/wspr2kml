#
# don't forget commas in the end of line
#
# filters:
# callsign to use
#
callsign	=>'LY1BWB',
#
# use only reports with this power level. Comment out if not used
power		=>0.01,
#
# dupe_filter is based on locator report. Default is on.
#dupe_filter	=>1,
#
# use only those reports, where calculated speed is less than max_speed
# if disabled, you may see balloon flying weird speeds
# *FIXME* Though it may be still valid when reports are 4 sign locator value and balloon is passing their edges in short time
# max_speed	=>350,
#
# DEBUG: if enabled, it will print some info to STDERR
DEBUG		=>1,

# source_file 
# copy/paste data from http://wsprnet.org/drupal/wsprnet/spotquery to this file
# default: STDIN
source_file	=>'./data.tsv',

# output_file
# default: STDOUT
output_file	=>'./output.kml',

# default_altitude: in meters
default_altitude	=>13000,
