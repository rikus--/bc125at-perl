package Bc125At::ProgressBar;

sub new {
    my ($package, @args) = @_;
    my $self = {
        value     => 0,
        max       => 100,
        redisplay => 5,
        @args
    };
    return bless $self;
}

sub more {
    my ($self, $newvalue) = @_;
    if (defined $newvalue) {
        $self->{value} = $newvalue;
    }
    else {
        $self->{value}++;
    }
    $self->display()
      if $self->{value} == 0
          or $self->{value} % $self->{redisplay} == 0
          or $self->{value} == $self->{max};
}

sub display {
    my $self = shift;
    local $| = 1;
    my $frac = $self->{value} / $self->{max};
    print "\r|" . ("-" x 50) . "|" . " $self->{value} / $self->{max}" . (" " x 10) . "\r" . "|" . ("#" x (50 * $frac));
    print "\n" if $self->{value} >= $self->{max};
}

1;
