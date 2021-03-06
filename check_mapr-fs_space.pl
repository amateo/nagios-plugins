#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date:   2014-02-19 22:00:59 +0000 (Wed, 19 Feb 2014)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  vim:ts=4:sts=4:sw=4:et

$DESCRIPTION = "Nagios Plugin to check the MapR-FS space used in a MapR Hadoop cluster via the MapR Control System REST API

Tested on MapR 3.1.0 and 4.0.1";

# Uses rlimit API endpoint, only disk resource is supported as of MapR 3.1, appears to be the same in 4.0

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils qw/:DEFAULT :regex/;
use HariSekhon::MapR;

$ua->agent("Hari Sekhon $progname version $main::VERSION");

set_threshold_defaults(75, 85);

%options = (
    %mapr_options,
    %mapr_option_cluster,
    %thresholdoptions,
);

get_options();

validate_mapr_options();
list_clusters();
$cluster = validate_cluster $cluster;
validate_thresholds(1, 1, { "simple" => "upper", "integer" => 1, "positive" => 1, "min" => 0, "max" => 100});

vlog2;
set_timeout();

$status = "OK";

$json = curl_mapr "/rlimit/get?resource=disk&cluster=$cluster", $user, $password;

my @data = get_field_array("data");
# XXX: This shouldn't list more than 1 cluster otherwise output will look weird / doubled
if(scalar @data > 1){
    quit "UNKNOWN", "more than one data element returned. $nagios_plugins_support_msg_api";
}

my $item = $data[0];
my $currentUsage  = get_field2($item, "currentUsage");
my $limit         = get_field2($item, "limit");
my $clusterSize   = get_field2($item, "clusterSize");
my $pc_space_used = sprintf("%.2f", expand_units($currentUsage) / expand_units($limit) * 100);
$msg .= "$pc_space_used% space used";
check_thresholds($pc_space_used);
$msg .= " [$currentUsage/$limit], total cluster size = $clusterSize, usable limit = $limit, currently used  = $currentUsage";
$msg .= " | '% space used'=$pc_space_used%";
msg_perf_thresholds();
$msg .= " 'current space usage'=$currentUsage 'usable space limit'=$limit 'total cluster size'=$clusterSize";

vlog2;
quit $status, $msg;
