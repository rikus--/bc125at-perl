package Bc125At::Interactive;

# Copyright (c) 2013 Rikus Goodell. All Rights Reserved.
# This software is distributed free of charge and comes with NO WARRANTY.

use Bc125At::Serial;

run() unless caller;

sub run(){
	my $scanner = Bc125At::Serial->new();
        local $| = 1;
        {
            print '> ';
            my $line = <STDIN> or last;
            chomp $line;
	    my $result = $scanner->cmd($line);
            $result =~ s/([^a-zA-Z0-9,. ])/'['.ord($1).']'/e;
	    print "$result\n";
            redo;
	}
}

1;
