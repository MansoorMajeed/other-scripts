#!/usr/bin/perl


use warnings;
use Data::Dumper;



# Critical values
# To do :  use a conf file to read these values

# Alert if the disk space usage is > 80%
my $disk_usage_limit = 20;

# disk io usage : 50%
my $disk_io_limit = 50;
my $email = "mansoor@digitz.org";





# Function to do logging
sub log(){
	my $message = shift;
	my $log_file = 'disk-monitoring.log';
	open(my $file, '>>', $log_file) or die ("Could not open the log file for writing");
	
}

# Check health, usage, io usage

# Install the required packages if not installed

my $iostat_check = `which iostat 2>/dev/null`;
my $smartctl_check = `which smartctl 2>/dev/null`;

if ($iostat_check eq ''){
	print "Installing sysstat\n";
	system("apt-get update");
	system("apt install sysstat -y");
}
if ($smartctl_check eq ''){
	print "Installing smartmontools\n";
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
	}

}

# Loop through the disks and check the load on each
# also check the health.
for $disk (@disks){
	# print "$disk";
	my $disk_io_usage = `/usr/bin/iostat -dhx /dev/$disk | awk '\$13 ~ /^[0-9,\.]+\$/ { print \$13 }'`;
	chomp ($disk_io_usage);
	print "Disk IO usage : $disk_io_usage\n";

	# Disk space usage
	# my $disk_space_usage;


	# Disk health
	my $disk_health = `smartctl -H /dev/$disk | grep overall-health | awk -F: '{ print \$2 }'`;
	# print $disk_health;		
	# my $(disk_health) = ($d_health =~ s/^\s+// );
	$disk_health =~ s/^\s+//;
	if ( $disk_health eq 'PASSED'){
		# Log

		
	} else {
		# Log and send an alert
	}

}
