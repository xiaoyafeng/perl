package Testing;
use 5.006_001;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(_dumptostr);
use Carp;

sub _dumptostr {
    my ($obj) = @_;
    my $dumpstr;
    open my $T, '>', \$dumpstr or croak "Unable to open for writing to string";
    print $T $obj->Dump;
    close $T or croak "Unable to close after writing to string";
    return $dumpstr;
}

1;
