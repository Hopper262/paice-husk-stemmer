package Lingua::Stem::PaiceHusk;
use strict;
use warnings;

=head1 NAME

Lingua::Stem::PaiceHusk - Stem words with the Paice/Husk stemming algorithm.

=head1 SYNOPSIS

  use Lingua::Stem::PaiceHusk qw(stem);

  # simple syntax with default rules
  my @stems = stem(@words);

  # object-oriented syntax allows for different rulesets
  my $stemmer = Lingua::Stem::PaiceHusk->new('rules' => 'rules.txt');
  my @stems2 = $stemmer->stem(@words);

=head1 DESCRIPTION

This module provides an implementation of the Paice/Husk word stemming
algorithm. The algorithm is described at Dr. Christopher Paice's website:

  http://www.comp.lancs.ac.uk/computing/research/stemming/
  
The module is an alternative to stemmers like Lingua::Stem::Snowball.

=cut

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
  $VERSION = '1.01';
  
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw(stem);
  %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
}
our @EXPORT_OK;

=head1 METHODS / FUNCTIONS

=head2 new

  my $stemmer = Lingua::Stem::PaiceHusk->new('rules' => 'rules.txt');
  
Create a Lingua::Stem::PaiceHusk object. For now, the only option allowed
is C<rules>, which is a pathname to a Paice/Husk rules file in classic
format (the revised C format is not allowed).

=cut

sub new
{
  my ($class, %opts) = @_;
  
  my $self = bless {}, $class;
  
  my $ruleset;
  $ruleset = &LoadRules($opts{'rules'}) if $opts{'rules'};
  $ruleset = &GetRuleset() unless $ruleset;
  $self->{'rules'} = $ruleset;
  
  return $self;
} # end new

=head2 stem

  @stems = stem(@words);
  @stems = $stemmer->stem(@words);
  $stem = stem($word);
  
Return lowercased and stemmed output. If the word cannot be stemmed,
C<undef> is returned in the output. Returns the first stem in scalar
context.

=cut

sub stem
{
  my $obj = shift if ref $_[0];
  my (@words) = @_;
  
  my $rules = $obj ? $obj->{'rules'} : &GetRuleset();
  my @stems = ();
  foreach my $raw (@words)
  {
    my $stem = undef;
    if ($raw =~ /([A-Za-z]+)/)
    {
      my $word = lc($1);
      if (&IsValid($word))
      {
        $stem = &StemWord($word, $rules);
      }
    }
    push(@stems, $stem);
  }
  return wantarray ? @stems : $stems[0];
} # end stem


######################################
## LoadRules reads a rules file and
## produces the ruleset structure.
######################################

sub LoadRules
{
  my ($rulepath) = @_;
  my %rules;
  
  my $rulefile;
  open($rulefile, $rulepath) or return undef;
  my $i = 0;
  foreach my $line (<$rulefile>)
  {
    $i++;
    if ($line =~ /^\s*([A-Za-z]+)(\*?)(\d+)([A-Za-z]*)([>.])/)
    {
      my %rule;
      $rule{'suffix'} = reverse $1;
      $rule{'intact'} = ($2 eq '*' ? 1 : 0);
      $rule{'remove'} = 1 + $3 - 1;
      $rule{'append'} = $4;
      $rule{'restem'} = ($5 eq '>' ? 1 : 0);
      $rule{'id'} = "($i:$1$2$3$4$5)";
      
      if ($rule{'id'} eq "($i:end0.)")
      {
        # encountered pseudo-rule: stop
        close($rulefile);
        return \%rules;
      }
      my $letter = substr($1, 0, 1);
      $rules{$letter} = [] unless $rules{$letter};
      push(@{ $rules{$letter} }, \%rule);
    }
  }
  close($rulefile);
  return \%rules;
} # end LoadRules


######################################
## IsValid returns 1 if the parameter
## is an acceptable stem, or 0 if not.
## This prevents over-stemming by
## limiting the shortest final stem.
######################################

sub IsValid
{
  my ($stem) = @_;
  
  if ($stem =~ /^[aeiou]/)
  {
    return (length($stem) >= 2);
  }
  elsif ($stem =~ /[aeiouy]/)
  {
    return (length($stem) >= 3);
  }
  return 0;
} # end IsValid


######################################
## RuleMatches returns 1 if the
## rule can be applied to the stem,
## and 0 if the rule doesn't match.
######################################

sub RuleMatches
{
  my ($rule, $stem, $intact) = @_;

  return 0 if (!$intact && $rule->{'intact'});
  my $suffix = $rule->{'suffix'};
  return ($stem =~ /$suffix$/);
} # end RuleMatches


######################################
## ApplyRule takes a rule and stem,
## and produces the new stem created
## by applying the remove and append
## parts of the rule.
######################################

sub ApplyRule
{
  my ($rule, $stem) = @_;
  
  my $result = $stem;
  my $remove = $rule->{'remove'};
  $result = substr($result, 0, -$remove) if $remove;
  $result .= $rule->{'append'};
  
  return $result;
} # end ApplyRule


######################################
## StemWord is the main entry point
## for the stemmer. It takes a word
## and a reference to a ruleset
## structure (see LoadRules).
######################################

sub StemWord
{
  my ($stem, $rules, $debug) = @_;
  
  $$debug = '' if $debug;
  
  # only stem if word passes acceptability rules
  return $stem unless &IsValid($stem);
  
  $$debug = $stem if $debug;
  my $intact = 1;
  my $restem = 1;
  while ($restem)
  {
    # exit loop unless we apply a continuing rule
    $restem = 0;
    
    # try each rule for stem's last letter
    my $last = substr($stem, -1);
    my $ruleset = $rules->{$last};
    last unless $ruleset;
    
    foreach my $rule (@$ruleset)
    {
      # make sure this rule matches
      next unless &RuleMatches($rule, $stem, $intact);
      
      # apply the rule, check if result is acceptable
      my $result = &ApplyRule($rule, $stem);
      next unless &IsValid($result);
      
      # rule matched, replace stem and continue or exit
      $stem = $result;
      $intact = 0;
      $$debug .= " =" . $rule->{'id'} . "=> $result" if $debug;
      $restem = $rule->{'restem'};
      last;  # kick out to outer loop
    }
  }
  return $stem;
} # end StemWord


######################################
## GetRuleset returns the default
## Paice/Husk rules as a HoAoH data
## structure.
######################################

sub GetRuleset
{
  my $r = {
    'r' => [
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'er',
        'id' => '(61:re2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 'ear',
        'id' => '(62:rae0.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'ar',
        'id' => '(63:ra2.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'or',
        'id' => '(64:ro2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'ur',
        'id' => '(65:ru2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'rr',
        'id' => '(66:rr1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 1,
        'suffix' => 'tr',
        'id' => '(67:rt1>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ier',
        'id' => '(68:rei3y>)',
        'append' => 'y',
        'intact' => 0
      }
    ],
    'a' => [
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'ia',
        'id' => '(1:ai*2.)',
        'append' => '',
        'intact' => 1
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'a',
        'id' => '(2:a*1.)',
        'append' => '',
        'intact' => 1
      }
    ],
    'd' => [
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'dd',
        'id' => '(7:dd1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ied',
        'id' => '(8:dei3y>)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'ceed',
        'id' => '(9:deec2ss.)',
        'append' => 'ss',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'eed',
        'id' => '(10:dee1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'ed',
        'id' => '(11:de2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 4,
        'suffix' => 'hood',
        'id' => '(12:dooh4>)',
        'append' => '',
        'intact' => 0
      }
    ],
    'j' => [
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'ij',
        'id' => '(25:ji1d.)',
        'append' => 'd',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'fuj',
        'id' => '(26:juf1s.)',
        'append' => 's',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'uj',
        'id' => '(27:ju1d.)',
        'append' => 'd',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'oj',
        'id' => '(28:jo1d.)',
        'append' => 'd',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'hej',
        'id' => '(29:jeh1r.)',
        'append' => 'r',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'verj',
        'id' => '(30:jrev1t.)',
        'append' => 't',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'misj',
        'id' => '(31:jsim2t.)',
        'append' => 't',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'nj',
        'id' => '(32:jn1d.)',
        'append' => 'd',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'j',
        'id' => '(33:j1s.)',
        'append' => 's',
        'intact' => 0
      }
    ],
    'y' => [
      {
        'restem' => 1,
        'remove' => 1,
        'suffix' => 'bly',
        'id' => '(97:ylb1>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ily',
        'id' => '(98:yli3y>)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 'ply',
        'id' => '(99:ylp0.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'ly',
        'id' => '(100:yl2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'ogy',
        'id' => '(101:ygo1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'phy',
        'id' => '(102:yhp1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'omy',
        'id' => '(103:ymo1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'opy',
        'id' => '(104:ypo1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ity',
        'id' => '(105:yti3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ety',
        'id' => '(106:yte3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'lty',
        'id' => '(107:ytl2.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 5,
        'suffix' => 'istry',
        'id' => '(108:yrtsi5.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ary',
        'id' => '(109:yra3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ory',
        'id' => '(110:yro3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 3,
        'suffix' => 'ify',
        'id' => '(111:yfi3.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'ncy',
        'id' => '(112:ycn2t>)',
        'append' => 't',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'acy',
        'id' => '(113:yca3>)',
        'append' => '',
        'intact' => 0
      }
    ],
    'u' => [
      {
        'restem' => 0,
        'remove' => 3,
        'suffix' => 'iqu',
        'id' => '(92:uqi3.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'ogu',
        'id' => '(93:ugo1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'h' => [
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'th',
        'id' => '(20:ht*2.)',
        'append' => '',
        'intact' => 1
      },
      {
        'restem' => 0,
        'remove' => 5,
        'suffix' => 'guish',
        'id' => '(21:hsiug5ct.)',
        'append' => 'ct',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ish',
        'id' => '(22:hsi3>)',
        'append' => '',
        'intact' => 0
      }
    ],
    'g' => [
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ing',
        'id' => '(16:gni3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 3,
        'suffix' => 'iag',
        'id' => '(17:gai3y.)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'ag',
        'id' => '(18:ga2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'gg',
        'id' => '(19:gg1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'f' => [
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'lief',
        'id' => '(14:feil1v.)',
        'append' => 'v',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'if',
        'id' => '(15:fi2>)',
        'append' => '',
        'intact' => 0
      }
    ],
    't' => [
      {
        'restem' => 0,
        'remove' => 4,
        'suffix' => 'plicat',
        'id' => '(78:tacilp4y.)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'at',
        'id' => '(79:ta2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 4,
        'suffix' => 'ment',
        'id' => '(80:tnem4>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ent',
        'id' => '(81:tne3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ant',
        'id' => '(82:tna3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'ript',
        'id' => '(83:tpir2b.)',
        'append' => 'b',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'orpt',
        'id' => '(84:tpro2b.)',
        'append' => 'b',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'duct',
        'id' => '(85:tcud1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'sumpt',
        'id' => '(86:tpmus2.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'cept',
        'id' => '(87:tpec2iv.)',
        'append' => 'iv',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'olut',
        'id' => '(88:tulo2v.)',
        'append' => 'v',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 'sist',
        'id' => '(89:tsis0.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ist',
        'id' => '(90:tsi3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'tt',
        'id' => '(91:tt1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'i' => [
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'i',
        'id' => '(23:i*1.)',
        'append' => '',
        'intact' => 1
      },
      {
        'restem' => 1,
        'remove' => 1,
        'suffix' => 'i',
        'id' => '(24:i1y>)',
        'append' => 'y',
        'intact' => 0
      }
    ],
    'e' => [
      {
        'restem' => 1,
        'remove' => 1,
        'suffix' => 'e',
        'id' => '(13:e1>)',
        'append' => '',
        'intact' => 0
      }
    ],
    'n' => [
      {
        'restem' => 1,
        'remove' => 4,
        'suffix' => 'sion',
        'id' => '(51:nois4j>)',
        'append' => 'j',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 4,
        'suffix' => 'xion',
        'id' => '(52:noix4ct.)',
        'append' => 'ct',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ion',
        'id' => '(53:noi3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ian',
        'id' => '(54:nai3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'an',
        'id' => '(55:na2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 'een',
        'id' => '(56:nee0.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'en',
        'id' => '(57:ne2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'nn',
        'id' => '(58:nn1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'v' => [
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'siv',
        'id' => '(94:vis3j>)',
        'append' => 'j',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 'eiv',
        'id' => '(95:vie0.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'iv',
        'id' => '(96:vi2>)',
        'append' => '',
        'intact' => 0
      }
    ],
    'm' => [
      {
        'restem' => 0,
        'remove' => 3,
        'suffix' => 'ium',
        'id' => '(47:mui3.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'um',
        'id' => '(48:mu*2.)',
        'append' => '',
        'intact' => 1
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ism',
        'id' => '(49:msi3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'mm',
        'id' => '(50:mm1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    's' => [
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ies',
        'id' => '(69:sei3y>)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'sis',
        'id' => '(70:sis2.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'is',
        'id' => '(71:si2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 4,
        'suffix' => 'ness',
        'id' => '(72:ssen4>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 'ss',
        'id' => '(73:ss0.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ous',
        'id' => '(74:suo3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'us',
        'id' => '(75:su*2.)',
        'append' => '',
        'intact' => 1
      },
      {
        'restem' => 1,
        'remove' => 1,
        'suffix' => 's',
        'id' => '(76:s*1>)',
        'append' => '',
        'intact' => 1
      },
      {
        'restem' => 0,
        'remove' => 0,
        'suffix' => 's',
        'id' => '(77:s0.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'l' => [
      {
        'restem' => 0,
        'remove' => 6,
        'suffix' => 'ifiabl',
        'id' => '(34:lbaifi6.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 4,
        'suffix' => 'iabl',
        'id' => '(35:lbai4y.)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'abl',
        'id' => '(36:lba3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 3,
        'suffix' => 'ibl',
        'id' => '(37:lbi3.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'bil',
        'id' => '(38:lib2l>)',
        'append' => 'l',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'cl',
        'id' => '(39:lc1.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 4,
        'suffix' => 'iful',
        'id' => '(40:lufi4y.)',
        'append' => 'y',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ful',
        'id' => '(41:luf3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 2,
        'suffix' => 'ul',
        'id' => '(42:lu2.)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ial',
        'id' => '(43:lai3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 3,
        'suffix' => 'ual',
        'id' => '(44:lau3>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'al',
        'id' => '(45:la2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'll',
        'id' => '(46:ll1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'c' => [
      {
        'restem' => 0,
        'remove' => 3,
        'suffix' => 'ytic',
        'id' => '(4:city3s.)',
        'append' => 's',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'ic',
        'id' => '(5:ci2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 1,
        'remove' => 1,
        'suffix' => 'nc',
        'id' => '(6:cn1t>)',
        'append' => 't',
        'intact' => 0
      }
    ],
    'p' => [
      {
        'restem' => 1,
        'remove' => 4,
        'suffix' => 'ship',
        'id' => '(59:pihs4>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'pp',
        'id' => '(60:pp1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'b' => [
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'bb',
        'id' => '(3:bb1.)',
        'append' => '',
        'intact' => 0
      }
    ],
    'z' => [
      {
        'restem' => 1,
        'remove' => 2,
        'suffix' => 'iz',
        'id' => '(114:zi2>)',
        'append' => '',
        'intact' => 0
      },
      {
        'restem' => 0,
        'remove' => 1,
        'suffix' => 'yz',
        'id' => '(115:zy1s.)',
        'append' => 's',
        'intact' => 0
      }
    ]
  };
  return $r;
} # end GetRuleset



=head1 VERSION HISTORY

=over 4

=item Version 1.01 - 3 July 2006

Documentation cleanup, expanded object-oriented syntax.

=item Version 1.00 - 28 December 2005

Initial release.

=back

=head1 AUTHOR

Jeremiah Morris, jm@whpress.com

=head1 COPYRIGHT

Copyright 2005-2006

This software may be freely copied and distributed under the same terms and
conditions as Perl.
  
=head1 ACKNOWLEDGEMENTS

Christopher Paice, for his work and support.

Mary Taffett, for the initial Perl implementation of this algorithm.

=head1 SEE ALSO

Lingua::Stem, Lingua::Stem::Snowball, http://www.comp.lancs.ac.uk/computing/research/stemming/

=cut


1;
