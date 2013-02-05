package IO::Socket::INET;

use base qw( IO::Socket::IP );
use Socket qw( PF_INET );

sub new
{
  my $class = shift;
  return $class->SUPER::new(Family => PF_INET, PeerAddr => shift) if @_ == 1;
  return $class->SUPER::new(@_);
}

1;

