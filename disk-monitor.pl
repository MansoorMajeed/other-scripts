#!/usr/bin/perl


use warnings;
use Data::Dumper;



# Critical values
# To do :  use a conf file to read these values

# Alert if the disk space usage is > 80%
my $disk_usage_limit = 80;

# disk io usage : 50%
my $disk_io_limit = 3;
my $email = "mansoor\@digitz.org";





# Function to do logging
sub write_log{
	my $message = shift;
	
	my $log_file = 'disk-monitoring.log';
	open(my $file, '>>', $log_file) or die ("Could not open the log file for writing");
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year + 1900;
	$mon = $mon + 1;
	$timestamp = "$year-$mon-$mday $hour:$min:$sec ";
	$string = $timestamp . $message . "\n";
	print $file $string;
	close($file);

}

write_log("yeahh");
# Check health, usage, io usage

# Install the required packages if not installed

my $iostat_check = `which iostat 2>/dev/null`;
my $smartctl_check = `which smartctl 2>/dev/null`;

if ($iostat_check eq ''){
	write_log("Installing sysstat");
	system("apt-get update");
	system("apt install sysstat -y");
}
if ($smartctl_check eq ''){
	write_log("Installing smartmontools");
	system("apt-get update");
	system("apt install smartmontools -y");
}


# Get all the attached disks

my $disks = `/bin/lsblk -l | grep disk | awk '{ print \$1 }'`;
my @disks = split('\n', $disks);
chomp for(@disks);

# Check the overall Disk Space usage
my $disk_space_usage = `df -h | grep -v Filesystem |  awk '{ print \$1":"\$5":"\$6 }'`;
my @disk_space_usage = split('\n', $disk_space_usage);
for $line (@disk_space_usage){

	my @parts = split(':', $line);
	my $partition = $parts[0];
	my $usage = $parts[1];
	my $mount = $parts[2];
	# my $usage =~ s/%//g;  # It doesn't work. Need to check why
	# Gotcha!! that "my" would cause issues during substitution
	$usage =~ s/%//g;
	# my ($usage) =  ($usage =~ /(\d+)%/);
	# print "$partition==$usage==$mount\n";
	if ($usage > $disk_usage_limit){
		print "Sending email";
		my $host = `hostname`;
		system("echo \"Disk Usage Critical\n==============\nCurrent Usage: $usage\nMounted on: $mount\nPartition: $partition\n\" | mail -s \"Disk usage Alert from $host\" $email");
		write_log("Disk usage Critical [$usage % used] : Mounted on [$mount]");
	} else{
		write_log("Disk usage OK [$usage % used] : Mounted on [$mount]");
	}

}

# Loop through the disks and check the load on each
# also check the health.
for $disk (@disks){
	# print "$disk";
	write_log("------------------------------------------");
	write_log("Checking health and load of disk : [$disk]");
	write_log("------------------------------------------");
	my $disk_io_usage = `/usr/bin/iostat -dhx /dev/$disk | awk '\$13 ~ /^[0-9,\.]+\$/ { print \$13 }'`;
	chomp ($disk_io_usage);
	

	# Disk space usage
	# my $disk_space_usage;


	# Disk health
	my $disk_health = `smartctl -H /dev/$disk | grep overall-health | awk -F: '{ print \$2 }'`;
	# print $disk_health;		
	# my $(disk_health) = ($d_health =~ s/^\s+// );
	my $notify_flag;
	if ($disk_io_usage > $disk_io_limit){
		write_log("[WARN] Disk IO Critical. % Utilization :[$disk_io_usage]");
		$notify_flag = 1;
	} else {
		write_log("[OK] Disk IO Utilization OK [$disk_io_usage]%");
	}

	$disk_health =~ s/^\s+//;
	if ( $disk_health =~ /PASSED/){
		# Log
		write_log("[OK] Disk health OK");
		
	} else {
		# Log and send an alert
		write_log("[FATAL] Disk Health Not OK");
		$notify_flag = 1;
		$emergency_flag = 1;
	}

	if ($notify_flag){
		$host = `hostname`;
		write_log("Sending Alerts to the Team");
		if($emergency_flag){

			system("echo \"Disk Failure. Disk [$disk] on [$hostname] failed health test\" | mail -s \"[FATAL] Disk [$disk] Health Fatal on host [$hostname] \" $email");
		}
		system("echo \"Disk IO usage Critical on host [$hostname]\n--------------\n%Utilization: $disk_io_usage\n\" | mail -s \"[WARN] Disk IO usage critical on [$host]\" $email");
	}
	write_log("------------------------------------------");
}
