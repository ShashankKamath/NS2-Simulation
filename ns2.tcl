global version, case, delay, ver
set delay =0
set version [lindex $argv 0]
set case [lindex $argv 1]

if {$case == 1} { 
	set delay "12.5ms" 
} elseif {$case == 2} { 
	set delay "20ms" 
} elseif {$case == 3} { 
	set delay "27.5ms" 
} else { 
	puts "Invalid Case"
	exit
}


if {$version == "SACK"} {
	set ver "Sack1"
} elseif {$version == "VEGAS"} {
	set ver "Vegas"
} else {
	puts "Invalid TCP Flavor $flavor"
	exit
}

set ns [new Simulator]

set out1 [open out1.tr w]
set out2 [open out2.tr w]
set out3 [open out3.tr w]
#set file "out_$flavor$case"
set nf [open out.tr w]
$ns trace-all $nf

set namf [open out.nam w]
$ns namtrace-all $namf

#NODE INTITIALIZING
set src1 [$ns node]
set src2 [$ns node]
set r1 [$ns node]
set r2 [$ns node]
set rcv1 [$ns node]
set rcv2 [$ns node]

#Define different colors for data flows
$ns color 1 Blue
$ns color 2 Red

set tcp1 [new Agent/TCP/$ver]
set tcp2 [new Agent/TCP/$ver]
$ns attach-agent $src1 $tcp1
$ns attach-agent $src2 $tcp2

set sink1 [new Agent/TCPSink]
set sink2 [new Agent/TCPSink]
$ns attach-agent $rcv1 $sink1
$ns attach-agent $rcv2 $sink2

$ns connect $tcp1 $sink1
$ns connect $tcp2 $sink2

#Createlinks between nodes
$ns duplex-link $r1 $r2 1.0Mb 5ms DropTail
$ns duplex-link $src1 $r1 10.0Mb 5ms DropTail  
$ns duplex-link $rcv1 $r2 10.0Mb 5ms DropTail  
$ns duplex-link $src2 $r1 10.0Mb $delay DropTail  
$ns duplex-link $rcv2 $r2 10.0Mb $delay DropTail  

#Give node position (for NAM)
$ns duplex-link-op $r1 $r2 orient right
$ns duplex-link-op $src1 $r1 orient right-down
$ns duplex-link-op $src2 $r1 orient right-up
$ns duplex-link-op $r2 $rcv1 orient right-up
$ns duplex-link-op $r2 $rcv2 orient right-down

#Creating FTP
set ftp1 [new Application/FTP]
set ftp2 [new Application/FTP]
$ftp1 attach-agent $tcp1
$ftp2 attach-agent $tcp2

#Initializing
set sum1 0
set sum2 0
set count 0

#Calculating
proc calc {} {
	global ns sink1 sink2 out1 out2 out3 sum1 sum2 count  
	set bandwidth1 [$sink1 set bytes_]
	set bandwidth2 [$sink2 set bytes_]
	
	set time 0.5
	
	set now [$ns now]
	
	#Initialization
	if {$now == 100} 	{
		$sink1 set bytes_ 0
		$sink2 set bytes_ 0
	}
	#Throughput between 100 and 400 seconds
	if {$now > 100 && $now<= 400 } {
		set throughput1 [expr $bandwidth1/$time *8/1000000]
		set throughput2 [expr $bandwidth2/$time *8/1000000]
		set sum1 [expr $sum1 + $throughput1]
		set sum2 [expr $sum2 + $throughput2]
		set count [expr $count + 1]
		set ratio [expr $throughput1/$throughput2]

		#Write values to output files
		puts $out1 "$now $throughput1"
		puts $out2 "$now $throughput2"
		puts $out3 "$ratio"
		$sink1 set bytes_ 0
		$sink2 set bytes_ 0
	}

	if { $now == 400.5 } {
		set averagethroughput1 [ expr $sum1/$count]
		set averagethroughput2 [ expr $sum2/$count]
		puts "Average throughput for src1 : $averagethroughput1 MBits/sec"
		puts "Average throughput for src2 : $averagethroughput2 MBits/sec"
		set ratio [expr $averagethroughput1/$averagethroughput2]
		puts "Ratio of throughputs : $ratio"
	}	
	#Recursion call
	$ns at [expr $now + $time] "calc"
}

#Terminating 
proc finish {} {
global ns nf namf
$ns flush-trace
close $nf
close $namf
exec xgraph out1.tr out2.tr -geometry 800x400 &
exit 0
}

#Activity
$ns at 0.5 "$ftp1 start"
$ns at 0.5 "$ftp2 start"

#Call calc
$ns at 100 "calc"
$ns at 401 "$ftp1 stop"
$ns at 401 "$ftp2 stop"

#Call Finish
$ns at 405 "finish"
$ns run
