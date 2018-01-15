program Paice;

const
  SHORTSTR  =   64;
  LONGSTR   =  255;
  HUGESTR   = 4095;

type
  ShortString   = String(SHORTSTR);
  LongString    = String(LONGSTR);
  HugeString    = String(HUGESTR);
  StringPtr     = ^String;
  PaiceRulePtr  = ^PaiceRule;
  PaiceRule     = record
                    intact: Boolean;
                    remove: Integer;
                    restem: Boolean;
                    suffix: ShortString;
                    append: ShortString;
                    id:     Shortstring;
                    next:   PaiceRulePtr;
                  end;
  PaiceRuleSet  = array ['a'..'z'] of PaiceRulePtr;
  
var
  rulefile:   Text;
  wordfile:   Text;
  rules:      PaiceRuleSet;
  line:       HugeString;
  stem:       LongString;
  debug:      StringPtr;
  strbegin:   Integer;
  strend:     Integer;


{ ReverseString reverses a string in
  place -- useful while reading the
  rules.
}

procedure ReverseString(var str: String);
var
  last: Integer;
  half: Integer;
  i:    Integer;
  ch:   Char;

begin
  last := length(str);
  half := trunc(last / 2);
  
  for i := 1 to half do
  begin
    ch := str[last - i + 1];
    str[last - i + 1] := str[i];
    str[i] := ch;
  end;
end; { end ReverseString }


{ LoadRules reads a rules file and
  produces the ruleset structure.
}

procedure LoadRules(rulepath: String; var rules: PaiceRuleSet);
var
  rulefile:   Text;
  linenum:    Integer;
  line:       String(LONGSTR);
  rule_idx:   Char;
  rule:       PaiceRulePtr;
  tmp_rule:   PaiceRulePtr;
  i:          Integer;
  j:          Integer;
  ch:         Char;
  
begin
  { clear rules before starting }
  for ch := 'a' to 'z' do
    rules[ch] := nil;
  
  { read each line of rules file }
  Assign(rulefile, rulepath);
  Reset(rulefile);
  linenum := 0;
  while (not eoln(rulefile)) do
  begin
    
    linenum := linenum + 1;
    readln(rulefile, line);
    
    { trim spaces to left of line }
    i := 1;
    while (line[i] = ' ') do
      i := i + 1;
    if (i > 1) then
      line := substr(line, i);
    
    { trim everything after rule }
    if (index(line, ' ') > 0) then
      line := substr(line, 1, index(line, ' ') - 1)
    else
      line := substr(line, 1, length(line) - 1);  { remove newline }
   
    { encountered pseudo-rule: stop }
    if (line = 'end0.') then
      break;
    
    rule_idx := line[1];
    getmem(rule, sizeof(PaiceRule));
    rule^.next := nil;
    i := 1;
    writestr(rule^.id, "(", linenum, ":", line, ")");
    
    { suffix part }
    j := i;
    while (line[i] in ['a'..'z']) do
      i := i + 1;
    rule^.suffix := substr(line, j, i - j);
    ReverseString(rule^.suffix);
        
    { intact flag }
    if (line[i] = '*') then
    begin
      rule^.intact := True;
      i := i + 1;
    end
    else
      rule^.intact := False;
    
    { remove size }
    j := i;
    while (line[i] in ['0'..'9']) do
      i := i + 1;
    readstr(substr(line, j, i - j), rule^.remove);
    
    { append part }
    j := i;
    while (line[i] in ['a'..'z']) do
      i := i + 1;
    rule^.append := substr(line, j, i - j);
    
    { continue/stop flag }
    if (line[i] = '>') then
      rule^.restem := True
    else
      rule^.restem := False;
    
    
    { add rule to ruleset }
    if (rules[rule_idx] = nil) then
      { first rule for this letter }
      rules[rule_idx] := rule
    else
    begin
      { walk the list and add rule at the end }
      tmp_rule := rules[rule_idx];
      while (tmp_rule^.next <> nil) do
        tmp_rule := tmp_rule^.next;
      tmp_rule^.next := rule;
    end;
  end;
end; { LoadRules }


{ IsValid returns 1 if the parameter
  is an acceptable stem, or 0 if not.
  This prevents over-stemming by
  limiting the shortest final stem.
}

function IsValid(stem: String): Boolean;
var
  i:  Integer;
  
begin
  IsValid := False;
  
  if (length(stem) >= 2) then
    if (stem[1] in ['a', 'e', 'i', 'o', 'u']) then
      IsValid := True;
   
  if (length(stem) >= 3) then
    for i := 1 to length(stem) do
      if (stem[i] in ['a', 'e', 'i', 'o', 'u', 'y']) then
        IsValid := True;
end; { end IsValid }


{ RuleMatches returns 1 if the
  rule can be applied to the stem,
  and 0 if the rule doesn't match.
}

function RuleMatches(rule: PaiceRulePtr; stem: String; intact: Boolean): Boolean;
begin
  if (rule^.intact and not intact) then
    RuleMatches := False
  else
  if (length(rule^.suffix) > length(stem)) then
    RuleMatches := False
  else
  if (rule^.suffix <> substr(stem,
                             length(stem) - length(rule^.suffix) + 1,
                             length(rule^.suffix))) then
    RuleMatches := False
  else
    RuleMatches := True;
end; { end RuleMatches }


{ ApplyRule takes a rule and stem,
  and produces the new stem created
  by applying the remove and append
  parts of the rule.
}

function ApplyRule(rule: PaiceRulePtr; stem: String): LongString;
begin
  if (rule^.remove >= length(stem)) then
    ApplyRule := rule^.append
  else
    ApplyRule := concat(substr(stem, 1, length(stem) - rule^.remove),
                        rule^.append);
end; { end ApplyRule }


{ StemWord is the main entry point
  for the stemmer. It takes a word
  and a reference to a ruleset
  structure (see LoadRules).
}

procedure StemWord(word: String; var stem: String; rules: PaiceRuleSet; debug: StringPtr);
var
  intact:       Boolean;
  restem:       Boolean;
  result:       LongString;
  rule:         PaiceRulePtr;
  
begin
  stem := word;
  if (debug <> nil) then
    debug^ := '';
  
  { only stem if word passes acceptability rules }
  if (IsValid(stem)) then
  begin
    debug^ := stem;
    intact := True;
    restem := True;
    while (restem) do
    begin
      { exit loop unless we apply a continuing rule }
      restem := False;
      
      { try each rule for stem's last letter }
      rule := rules[stem[length(stem)]];
      while (rule <> nil) do
      begin
        { make sure this rule matches }
        if (not RuleMatches(rule, stem, intact)) then
        begin
          rule := rule^.next;
          continue;
        end;
        
        { apply the rule, check if result is acceptable }
        result := ApplyRule(rule, stem);
        if (not IsValid(result)) then
        begin
          rule := rule^.next;
          continue;
        end;
        
        { rule matched, replace stem and continue or exit }
        stem := result;
        intact := False;
        if (debug <> nil) then
          debug^ := concat(debug^, ' =', rule^.id, '=> ', stem);
        restem := rule^.restem;
        break;  { kick out to outer loop }
      end;
    end;
  end;
end; { end StemWord }


{ To run as a program:
    paice <rulefile> <wordfile>
  Stems are output to stdout.
  Stems and rule info are output to stderr.
}

begin
  if ParamCount < 2 then
  begin
    writeln('Usage: paicehusk_pascal <rulefile> <wordfile>');
  end
  else
  begin
    LoadRules(ParamStr(1), rules);
    
    New(debug, HUGESTR);
    Assign(wordfile, ParamStr(2));
    Reset(wordfile);
    while (not eoln(wordfile)) do
    begin
      readln(wordfile, line);
      
      { process all words in line }
      strbegin := 1;
      while (strbegin <= length(line)) do
      begin
        
        { find first letter }
        while (strbegin <= length(line)) and not
              (line[strbegin] in ['A'..'Z', 'a'..'z']) do
          strbegin := strbegin + 1;
        
        { find last letter, converting to lowercase along the way }
        strend := strbegin;
        while (strend <= length(line)) and
              (line[strend] in ['A'..'Z', 'a'..'z']) do
        begin
          if (line[strend] in ['A'..'Z']) then
            line[strend] := chr(ord(line[strend]) + 32);
          strend := strend + 1;
        end;
      
        if (strbegin < strend) then
        begin
          StemWord(line[strbegin..strend - 1], stem, rules, debug);
          writeln(stem);
          writeln(StdErr, stem, ' (', debug^, ')');
        end;
        strbegin := strend + 1;
      end;
    end;
  end;

end.
