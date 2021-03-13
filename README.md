# wspr2kml
Convert high altitude balloon data to KML file

Depends on Ham::Locator, you can get it from cpan:

$ cpan Ham::Locator

Usage:

go to http://wsprnet.org/drupal/wsprnet/spotquery

Enter call, Band to filter out.
Adjust limit.
Sort by timestamp, uncheck reverse order
Click Update button

Select all reported lines, paste it to data.tsv file.
Take a look at wspr2kml.pl, you may wish to adjust some options.

Launch wspr2kml.pl

output.kml will be generated. You can view it with Google Earth program or online http://earth.google.com

