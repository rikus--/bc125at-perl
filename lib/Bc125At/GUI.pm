package Bc125At::GUI;

# Copyright (c) 2013, Rikus Goodell.
#
# All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

use strict;
use warnings;

use Bc125At::Detect;
use Bc125At::Command;
use Bc125At::GUI::ProgressWindow;
use Bc125At::GUI::ErrorDialog;
use Bc125At::GUI::AboutDialog;

BEGIN {
    eval {
        require Gtk2;
        Gtk2->init;
    };
    if ($@) {
        die "Gtk2 is not available. Please install Gtk2-perl in order to use the GUI.\n";
    }
}

sub new {
    my ($package) = @_;
    my $window = Gtk2::Window->new('toplevel');
    my $self   = {
        window  => $window,
    };
    bless $self;
    $self->_setup_widgets();
    return $self;
}

sub main {
    my $self = shift;
    $self->{window}->show_all();
    $self->{splash}->done if $self->{splash};
    $self->device_check;
    $self->setup_command_obj_if_not_ready;
    $SIG{ALRM} = sub {
        $self->spare_time;
        alarm 1;
    };
    alarm 1;
    Gtk2->main;
}

sub _setup_widgets {
    my $self = shift;

    my $window = $self->{window};

    $window->signal_connect(destroy => sub { $self->quit });

    # This window has a lot of widgets in it, so resizing is likely to be horribly sluggish.
    $window->set_resizable(0);

    my $scroll = Gtk2::ScrolledWindow->new();
    {
        no strict 'subs';
        $scroll->set_policy(GTK_POLICY_NEVER, GTK_POLICY_ALWAYS);
    }

    my $vbox   = Gtk2::VBox->new(0);
    my $hbox   = Gtk2::HBox->new();
    $self->{status} = Gtk2::Label->new();

    for (
        _button('About...', sub { Bc125At::GUI::AboutDialog::show_about_box($self->{window}) }),
        _button('Reload driver', sub { $self->reload }),
        _button(
            "Read from scanner",
            sub {
                $self->setup_command_obj_if_not_ready || return;
                my $progress_window = Bc125At::GUI::ProgressWindow->new("Reading from scanner...", $self->{window});
                eval {
                    $self->{scanner}->begin_program;
                    $self->populate_table($self->{scanner}->get_all_channel_info(undef, sub { $progress_window->set(@_) }));
                    $self->{scanner}->end_program;
                };
                my $err = $@;
                $progress_window->done;
                if ($err) {
                    Bc125At::GUI::ErrorDialog->new('Error while reading from scanner', $err, $self->{window})->main;
                }
            }
        ),
        _button(
            "Write to scanner",
            sub {
                $self->setup_command_obj_if_not_ready || return;
                $self->_confirm_dialog || return;
                my $progress_window = Bc125At::GUI::ProgressWindow->new("Writing to scanner...", $self->{window});
                eval {
                    $self->{scanner}->begin_program;
                    $self->{scanner}->write_channels(undef, $self->harvest_table(), sub { $progress_window->set(@_) });
                    $self->{scanner}->end_program;
                };
                my $err = $@;
                $progress_window->done;
                if ($err) {
                    Bc125At::GUI::ErrorDialog->new('Error while writing to scanner', $err, $self->{window})->main;
                }
            }
        ),
        _button(
            "Load file...",
            sub {
                my $filename = $self->_load_dialog() || return;
                my $info = Bc125At::Command::undumper($filename) || die;
                $self->populate_table($info);
                print "Loaded channels from $filename\n";
            }
        ),
        _button(
            "Save file...",
            sub {
                my $filename = $self->_save_dialog() || return;
                my $info = $self->harvest_table();
                Bc125At::Command::dumper($filename, $info, 'channel');
                print "Saved channels to $filename\n";
            }
        ),
        _button(
            "Check for duplicates",
            sub { $self->_check_for_duplicates }
        ),
        _button(
            "Quit",
            sub { $self->quit }
        )
      )
    {
        $hbox->add($_);
    }

    $vbox->add($hbox);

    $vbox->add($self->{status});

    my $table = Gtk2::Table->new(501, 8, 1);

    $scroll->add_with_viewport($table);

    $scroll->set_size_request(720, 600);

    my @head = qw(name frq mod ctcss_dcs dly lout pri);

    my @entries;

    my $splash_label = Gtk2::Label->new(
        <<END
bc125at-perl
Copyright (c) 2013, Rikus Goodell.

building interface...
END
    );
    $splash_label->set_justify('center');
    $self->{splash} = Bc125At::GUI::ProgressWindow->new(
        'bc125at-perl',
        $self->{window},
        sub {
            $_[0]->get_content_area->add($splash_label);
        }
    );
    for my $row (-1 .. 499) {
        if ($row >= 0) {
            my $label = _button($row + 1, sub { $self->{scanner}->jump_to_channel($row + 1) });
            $table->attach_defaults($label, 0, 1, 1 + $row, 2 + $row);
        }
        for my $col (0 .. 6) {

            my $widget;

            if ($row == -1) {
                $widget = Gtk2::Label->new($head[$col]);
            }
            elsif ($head[$col] eq 'lout') {
                $entries[$row][$col] = $widget = Gtk2::CheckButton->new_with_label('L/O');
            }
            else {
                $entries[$row][$col] = $widget = Gtk2::Entry->new_with_max_length(16);
            }
            $widget->set_size_request(50, 25);

            my $width = $col == 0 ? 2 : 1;
            my $hoff  = $col == 0 ? 0 : 1;
            $table->attach_defaults($widget, $hoff + 1 + $col, $hoff + $width + 1 + $col, 1 + $row, 2 + $row);
            $widget->show;
            $self->{splash}->set(($row + 2), 501);
        }
    }

    # splash window is cleaned up in main

    $vbox->add($scroll);
    $window->add($vbox);

    $self->{entries} = \@entries;
}

sub _button {
    my ($text, $sub) = @_;
    my $button = Gtk2::Button->new($text);
    $button->signal_connect(clicked => $sub);
    return $button;
}

sub populate_table {
    my ($self, $info) = @_;
    for my $row (0 .. $#$info) {
        _populate_row($self->{entries}[$row] || die, $info->[$row]);
    }
}

sub _populate_row {
    my ($row_widgets, $rowinfo) = @_;
    my @ri = @$rowinfo{qw(name frq mod ctcss_dcs dly lout pri)};
    for my $col (0 .. $#ri) {
        if ($row_widgets->[$col]->isa('Gtk2::CheckButton')) {
            $row_widgets->[$col]->set_active($ri[$col]);
        }
        else {
            $row_widgets->[$col]->set_text($ri[$col]);
        }
    }
}

sub harvest_table {
    my $self = shift;
    my @info;
    for my $row (0 .. 499) {
        $info[$row] = _harvest_row($self->{entries}[$row] || die, $row);
    }
    return \@info;
}

sub _harvest_row {
    my ($row_widgets, $row_n) = @_;
    my @ri;
    for my $col (0 .. 6) {
        if ($row_widgets->[$col]->isa('Gtk2::CheckButton')) {
            $ri[$col] = $row_widgets->[$col]->get_active() ? 1 : 0;
        }
        else {
            $ri[$col] = $row_widgets->[$col]->get_text();
        }
    }
    unshift @ri, 'CIN', $row_n + 1;
    my $rowinfo = {};
    @$rowinfo{qw(cmd index name frq mod ctcss_dcs dly lout pri)} = @ri;
    return $rowinfo;
}

sub _clear_row {
    my ($self, $row_n) = @_;
    my $row_widgets = $self->{entries}[$row_n];
    my @data = (' ' x 16, '000.000', 'AUTO', '0', '0', '1', '0');
    for my $col (0 .. $#data) {

        if ($row_widgets->[$col]->isa('Gtk2::CheckButton')) {
            $row_widgets->[$col]->set_active($data[$col]);
        }
        else {
            $row_widgets->[$col]->set_text($data[$col]);
        }
    }
}

sub _load_dialog {
    my $self = shift;
    no strict;
    my $open = Gtk2::FileChooserDialog->new("Load channels",
        $self->{window}, GTK_FILE_CHOOSER_ACTION_OPEN, 'Cancel', GTK_RESPONSE_CANCEL, 'Open', GTK_RESPONSE_ACCEPT);
    $open->show;
    my $resp = $open->run;
    $open->hide;
    return $open->get_filename if $resp =~ /accept/i;
    return;
}

sub _save_dialog {
    my $self = shift;
    no strict;
    my $save = Gtk2::FileChooserDialog->new("Save channels",
        $self->{window}, GTK_FILE_CHOOSER_ACTION_SAVE, 'Cancel', GTK_RESPONSE_CANCEL, 'Save', GTK_RESPONSE_ACCEPT);
    $save->show;
    my $resp = $save->run;
    $save->hide;
    return $save->get_filename if $resp =~ /accept/i;
    return;
}

sub _confirm_dialog {
    my $self = shift;
    no strict;
    my $confirm = Gtk2::Dialog->new("Confirm", $self->{window}, GTK_DIALOG_MODAL);
    for ([ 'Cancel', GTK_RESPONSE_CANCEL ], [ 'Yes, write channels to scanner', GTK_RESPONSE_OK ]) {
        my ($text, $response_type) = @$_;
        $confirm->add_button($text, $response_type);
    }
    $confirm->show;
    my $resp = $confirm->run;
    $confirm->hide;
    return 1 if $resp =~ /^ok/i;
    return;
}

# TODO: Move rowinfo-related bits of this into Bc125At::Command and write
# unit tests for duplicate detection and removal.
sub _check_for_duplicates {
    my $self = shift;
    my %seen;
    my $info = $self->harvest_table();
    my @dups;
    for my $ch (@$info) {
        my ($frq, $index) = @$ch{qw(frq index)};
        if ($frq =~ /[1-9]/ && $seen{$frq}) {
            push @dups, [ $ch->{'index'}, "DUPLICATE: [$ch->{index}] $ch->{name} $ch->{frq}    already exists as $seen{$frq}" ];
            no strict 'subs';
            $self->{entries}[ $index - 1 ][0]->modify_base(GTK_STATE_NORMAL, Gtk2::Gdk::Color->new(62000, 20000, 20000));
        }
        else {
            $seen{$frq} = "[$ch->{index}] $ch->{name} $ch->{frq}";
            no strict 'subs';
            $self->{entries}[ $index - 1 ][0]->modify_base(GTK_STATE_NORMAL, undef);
        }
    }
    my $dup_scroll = Gtk2::ScrolledWindow->new;
    {
        no strict 'subs';
        $dup_scroll->set_policy(GTK_POLICY_NEVER, GTK_POLICY_ALWAYS);
    }
    $dup_scroll->add_with_viewport(Gtk2::Label->new(join("\n", map { $_->[1] } @dups) || "No duplicates were found."));
    $dup_scroll->set_size_request(768, 400);
    my $dialog = Bc125At::GUI::ErrorDialog->new('Duplicates', $dup_scroll, $self->{window});
    my $choices_hbox = Gtk2::HBox->new();
    $choices_hbox->add($_) for _button(
        'Remove duplicates and leave gaps',
        sub {
            for (@dups) {
                $self->_clear_row($_->[0] - 1);
            }
            $dialog->destroy;
            $self->_check_for_duplicates;    # recheck
        }
      ),
      _button(
        'Remove duplicates and slide channels to fill gaps',
        sub {
            for (sort { $b <=> $a } map { $_->[0] } @dups) {    # splice backwards from end so as not to disrupt known dup offsets
                splice @$info, $_ - 1, 1;
                push @$info, Bc125At::Command::_empty_rowinfo(500);

            }
            @$info == 500 or die;
            for (0 .. $#$info) {
                $info->[$_]{'index'} = $_ + 1;                  # renumber
            }
            $self->populate_table($info);
            $dialog->destroy;
            $self->_check_for_duplicates;                       # recheck
        }
      );
    $dialog->get_content_area->add($choices_hbox);
    $dialog->main;
}

sub setup_command_obj_if_not_ready {
    my $self = shift;
    return 1 if $self->{scanner};
    my $scanner = eval { Bc125At::Command->new() };
    if ($@){
        Bc125At::GUI::ErrorDialog->new('Error', $@)->main;
        return;
    }
    $self->{scanner} = $scanner;
    return 1;
}

sub status {
    my ($self, $text) = @_;
    $self->{status}->set_text($text);
}

sub spare_time {
    my $self = shift;
    my $t = time;
    if ($t > ($self->{last_device_check} || 0) ){
        $self->{last_device_check} = $t;
        $self->device_check;
    }
}

sub quit { Gtk2->main_quit };

sub reload {
    my $self = shift;
    eval {
        $self->{scanner} = undef; # close existing filehandle(s), if any
        Bc125At::Detect::setup_driver() || die "setup_driver() failed\n";
        $self->{scanner} = Bc125At::Command->new();
    };
    Bc125At::GUI::ErrorDialog->new('Driver setup', sprintf("Driver was %ssuccessfully loaded%s", !$@ ? ('', '') : ('NOT ', ": $@")), $self->{window})->main;
}

sub device_check {
   my $self = shift;
   my ($devinfo, $product, $vendor) = Bc125At::Detect::detect();
   if ($devinfo){
       my ($bus_n, $dev_n) = $devinfo =~ /Bus=\s*(\d+).*?Dev#=\s*(\d+)/;
       $self->status(sprintf 'BC125AT connected at bus %s device %s', $bus_n // '?', $dev_n // '?');
       if (!$self->{connected}){
           $self->reload;
           $self->{connected} = 1;
       }
   }
   else {
       $self->{connected} = 0;
       $self->status('No device detected');
   }
}

1;
