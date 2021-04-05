#!/usr/bin/perl
#
# WSPR data to KML generator
# LY3FF, 2021 m. kovo 13 d. 18:52:18
# HAB Mission LKB-2, LY1BWB
#
# dependencies:
# cpan Ham::Locator
#

use strict;
use DateTime::Duration;
use Ham::Locator;
use lib '.';
use latlon_distance;

my %config = do 'config.pl';

# if not used, filter values must be empty
my $call_filter = $config{'callsign'};
my $pwr_filter  = $config{'power'};
my $dupe_filter = 1;
if (defined $config{'dupe_filter'}) { $dupe_filter = $config{'dupe_filter'}; }
my $height  = $config{'default_altitude'}; # in meters
my $speed_filter = 0;
if (defined $config{'max_speed'}) { $speed_filter = $config{'max_speed'}; }

my $DEBUG = $config{'DEBUG'};	# will print some data to STDERR if set to 1

my $pointScale = 3;
#my $altitudeMode = "clampToGround"; #absolute, clampToSeaFloor, relativeToSeaFloor
my $altitudeMode = "absolute"; #absolute, clampToSeaFloor, relativeToSeaFloor
my $lineAltitudeMode = "clampToGround"; #absolute, clampToSeaFloor, relativeToSeaFloor
my $pointExtrude = 1; 
my $lineExtrude = 1; 
my $lineTessellate = 1; 

my $source = "/dev/stdin";
if (defined $config{'source_file'}) { $source = $config{'source_file'}; }

my $output = "/dev/stdout";
#my $output = "./output.kml";
if (defined $config{'output_file'}) { $output = $config{'output_file'}; }

my $converter = new Ham::Locator;
my @lines;

open(IN, "<", $source) or die "can't open $source";

# data filter
	    if ($DEBUG == 1) {
		print STDERR " Timestamp        Grid  \tPower\tDistance \tHours \tSpeed (km/h)\n";
	    }
my $last_grid;
my $last_timestamp;
my $total_kilometers=0;
my $total_time=0;
foreach(<IN>){
    next if m/^[ ]*#/;
    chomp;
    # if tsv copy/paste from web page
    my ($timestamp, $call, $mhz, $snr, $drift, $grid, $pwr, $reporter, $rgrid, $km, $az, $mode) = split(/ \t /, $_);
    my $valid = 1;
    if (($dupe_filter) && ($grid eq $last_grid))   { $valid = 0;}
    if (($pwr_filter)  && ($pwr  ne $pwr_filter))  { $valid = 0;}
    if (($call_filter) && ($call ne $call_filter)) { $valid = 0;}

    if ($valid == 1) {
	my $distance =  sprintf("%.2f",(get_grid_distance($last_grid, $grid)));
	my $ts1 = get_dateTime($last_timestamp);
	my $ts2 = get_dateTime($timestamp);
	my $hours = 0;
	my $time_delta_minutes = 0;
	my $speed_kmh = 0;
	if ($ts1 ne "" && $ts2 ne ""){
	    my $dur = $ts2->subtract_datetime($ts1);
	    $time_delta_minutes = $dur->in_units('minutes'); 
	    my $days = $dur->in_units('days');
	    my $h = ($days * 24) + ($time_delta_minutes / 60);
	    $hours = sprintf("%.2f", $h);
	}
	if ($hours != 0){
	    $speed_kmh = sprintf("%.2f", ($distance / $hours));
	}

	if ($speed_filter == 0 || $speed_kmh <= $speed_filter) {
	    if ($DEBUG == 1) {
		print STDERR "$timestamp $grid  \t$pwr \t$distance      \t$hours \t$speed_kmh\n";
	    }
	    push @lines, [($timestamp, $call, $mhz, $snr, $drift, $grid, $pwr, $reporter, $rgrid, $km, $az, $mode, $distance, $hours, $speed_kmh)];
	    $total_kilometers += $distance;
	    $total_time += $hours;
	    $last_grid = $grid;
	    $last_timestamp = $timestamp;
	}
    }

}
close(IN);

my $totals = "\nDistance: $total_kilometers km\n".
	     "Time:\t  $total_time h\n".
	     "Speed:\t  " . int($total_kilometers / $total_time) . " km/h\n";

	    if ($DEBUG == 1) {
		print STDERR $totals;
	    }
# 0                      1               2               3       4        5       6     7         8               9       10    11	12				13			    14
# Timestamp<---><------>  Call<><------>  MHz<-><------>  SNR<->Drift<->  Grid<>  Pwr<->Reporter  RGrid><------>  km<-->  az<-->Mode	Distance_from_previous_point	time_delta_since_last_point speed_kmh
# 2021-03-13 04:08 	 LY1BWB 	 14.097210 	 -21 	 0 	  QO05	  0.01	KH6KR 	  BL10ts 	  6407 	  100 	 2	2048				23.27			    89.90

open(OUT, ">", $output) or die "can't open $output";
print_kml_header("$call_filter WSPR track");
print OUT "  <Folder>\n    <name>WSPR Points</name>\n";
# generate points
foreach my $i (0..$#lines){
    my $name = $lines[$i][1];
    my $grid = $lines[$i][5];
    my $description = "Time: $lines[$i][0]\n".
                      "Locator:$grid\n".
                      "Power: $lines[$i][6] W\n".
                      "&#916; Distance: $lines[$i][12] km\n".
                      "&#916; Time: $lines[$i][13] h\n".
                      "Speed: $lines[$i][14] km/h\n".
                      "Reported by: $lines[$i][7]\n".
                      "SNR: $lines[$i][3] dB\n".
                      "Rep. distance: $lines[$i][9] km\n";
    if ($i == $#lines) {
	$description .= ("\nTotal:" .  $totals);
    }
    put_placemark($name, $description, $grid, $height);
}
print OUT "  </Folder>\n";

# generate track
print OUT "  <Folder>\n    <name>Track</name>\n";
print_line_string_header("track");
foreach my $i (0..$#lines){
    my $grid = $lines[$i][5];
    print_coordinates($grid, $height);
}

print_line_string_footer();
print OUT "  </Folder>\n";
print_kml_footer();
close(OUT);

# calculate distance between two grid locations
sub get_grid_distance(){
    my $grid1 = shift;
    my $grid2 = shift;
    if ($grid1 eq "" || $grid2 eq "") { return 0; }
    if ($grid1 eq $grid2) { return 0; }
    $converter->set_loc($grid1);
    my ($latitude1, $longitude1) = $converter->loc2latlng;
    $converter->set_loc($grid2);
    my ($latitude2, $longitude2) = $converter->loc2latlng;
    my $dist = distance($latitude1, $longitude1,$latitude2, $longitude2, "K");
    return $dist;
}

# generate DateTime object from timestamp
sub get_dateTime{
    my $timestamp = shift;
    $timestamp =~ s/^\s+//; # strip space(s) from left
    if ($timestamp eq "") {return;}
    my ($ymd, $time) = split(/ /, $timestamp);
    my ($year, $month, $day) = split(/\-/,$ymd);
    my ($h, $m) = split(/:/,$time);
#    print STDERR "'$ymd' '$time' --- $year, $month, $day, $h, $m\n";  return;
    my $dt = DateTime->new(
	year=>$year,
	month=>$month,
	day=>$day,
	hour=>$h,
	minute=>$m,
	second=>0,
	time_zone=>'UTC'
    );
    return $dt;
}


sub put_placemark(){
my $name = shift;
my $description = shift;
my $locator = shift;
my $height = shift;

$converter->set_loc($locator);
my ($latitude, $longitude) = $converter->loc2latlng;
 
    print OUT "<Placemark>\n";
    print OUT "  <name>$name</name>\n";
    print OUT "  <description>$description</description>\n";
    print OUT "  <styleUrl>#msn_blu-blank</styleUrl>\n";
    print OUT "  <Point>\n";
    print OUT "  <altitudeMode>$altitudeMode</altitudeMode>\n";
    print OUT "  <extrude>$pointExtrude</extrude>\n";
    print OUT "  <coordinates>$longitude,$latitude,$height</coordinates>\n";
    print OUT "  </Point>\n";
    print OUT "</Placemark>\n";
}

sub put_placemark_header(){
my $name = shift;
    print OUT "<Placemark id=\"$name\">\n";
    print OUT "  <name>$name</name>\n";
}

sub put_placemark_footer(){
    print OUT "</Placemark>\n";
}


sub print_kml_header(){
my $name = shift;
print OUT 
'<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<!-- generated with wspr2kml, https://github.com/vilisas/wspr2kml -->
<Document>
';
print_kml_styles();
print OUT '
  <Folder>
   <name>'. $name .'</name>
   <LineStyle id="line">
   <color>ff0000ff</color>
   <width>3</width>
   </LineStyle>
';


}

sub print_kml_footer(){
    print OUT "\n</Folder>\n</Document>\n</kml>\n";
}

sub print_line_string_header(){
my $id = shift;
print OUT "
<Placemark>
  <name>Track</name>\n
  <styleUrl>#track</styleUrl>\n
<LineString id=\"$id\">
  <gx:altitudeOffset>0</gx:altitudeOffset>
  <extrude>$lineExtrude</extrude>
  <tessellate>$lineTessellate</tessellate>
  <gx:altitudeMode>$lineAltitudeMode</gx:altitudeMode>
  <gx:drawOrder>0</gx:drawOrder>
  <coordinates>
";
#  <coordinates>...</coordinates>            <!-- lon,lat[,alt] -->
}

sub print_line_string_footer(){
print OUT "  </coordinates>
</LineString></Placemark>
";
}

sub print_coordinates(){
my $grid   = shift;
my $height = shift;
$converter->set_loc($grid);
my ($latitude, $longitude) = $converter->loc2latlng;

print OUT "    $longitude,$latitude,$height\n";

}

sub print_kml_styles(){
print OUT '
        <Style id="sn_blu-blank">
                <IconStyle>
                        <scale>'. $pointScale . '</scale>
                        <Icon>
                                <href>http://maps.google.com/mapfiles/kml/paddle/blu-blank.png</href>
                        </Icon>
                        <hotSpot x="32" y="1" xunits="pixels" yunits="pixels"/>
                </IconStyle>
                <BalloonStyle>
                </BalloonStyle>
                <ListStyle>
                        <ItemIcon>
                                <href>http://maps.google.com/mapfiles/kml/paddle/blu-blank-lv.png</href>
                        </ItemIcon>
                </ListStyle>
        </Style>
        <StyleMap id="msn_blu-blank">
                <Pair>
                        <key>normal</key>
                        <styleUrl>#sn_blu-blank</styleUrl>
                </Pair>
                <Pair>
                        <key>highlight</key>
                        <styleUrl>#sh_blu-blank</styleUrl>
                </Pair>
        </StyleMap>
        <Style id="sh_blu-blank">
                <IconStyle>
                        <scale>'. ($pointScale + 1) .'</scale>
                        <Icon>
                                <href>http://maps.google.com/mapfiles/kml/paddle/blu-blank.png</href>
                        </Icon>
                        <hotSpot x="32" y="1" xunits="pixels" yunits="pixels"/>
                </IconStyle>
                <BalloonStyle>
                </BalloonStyle>
                <ListStyle>
                        <ItemIcon>
                                <href>http://maps.google.com/mapfiles/kml/paddle/blu-blank-lv.png</href>
                        </ItemIcon>
                </ListStyle>
        </Style>
        <Style id="track">
                <LineStyle>
                        <color>ff0400ff</color>
                        <width>6</width>
                </LineStyle>
        </Style>
';
}

