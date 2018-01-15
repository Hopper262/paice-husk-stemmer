#!/usr/bin/perl
use strict;
use warnings;

######################################
## To run:
##   paice.pl <rulefile> <wordfile>
## Stems are output to stdout.
## Stems and rule info are output to
##  stderr.
######################################

if (scalar @ARGV < 2)
{
  die "Usage: paicehusk_perl.pl <rulefile> <wordfile>";
}

my $ruleset = &LoadRules($ARGV[0]);
unless ($ruleset)
{
  die "Could not open rules file: $ARGV[0]";
}

my $wordfile;
open($wordfile, $ARGV[1]) or die "Could not open words file: $ARGV[1]";
foreach my $line (<$wordfile>)
{
  # process each word in line
  while ($line =~ s/([A-Za-z]+)//)
  {
    my $debug = '';
    my $stem = &StemWord(lc($1), $ruleset, \$debug);
    print "$stem\n";
    print STDERR "$stem ($debug)\n";
  }
}
close($wordfile);



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


