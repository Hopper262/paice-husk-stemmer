#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define SHORTSTR  63
#define LONGSTR  255
#define HUGESTR 4095


/* rules are stored as a singly linked list */
typedef struct rule
{
  int  intact;
  int  remove;
  int  restem;
  char suffix[SHORTSTR];
  char append[SHORTSTR];
  char id[SHORTSTR];
  
  struct rule * next;
} rule_t;

/* function definitions */
void ReverseString(char * str);
rule_t ** LoadRules(const char * rulepath);
int IsValid(const char * stem);
void ApplyRule(const rule_t * rule, const char * stem, char * new_stem);
void StemWord(const char * word, char * stem, rule_t ** rules, char * debug);


/* To run as a program:
 *  paice <rulefile> <wordfile>
 * Stems are output to stdout.
 * Stems and rule info are output to stderr.
 */

int main(int argc, const char **argv)
{
  rule_t ** rules;
  FILE *    wordfile;
  char      line[HUGESTR];
  char      stem[LONGSTR];
  char      debug[HUGESTR];
  char *    strbegin;
  char *    strend;
  char *    origend;
  
  if (argc < 3)
  {
    perror("Usage: paicehusk_ansic <rulefile> <wordfile>\n");
    exit(1);
  }
  
  rules = LoadRules(argv[1]);
  if (!rules)
    exit(1);
  
  wordfile = fopen(argv[2], "r");
  if (!wordfile)
  {
    perror("Cannot open word file");
    exit(1);
  }
  
  while (fscanf(wordfile, "%4095s", line) == 1)
  {
    origend = &line[strlen(line)];
    
    /* process each word in line */
    strbegin = line;
    while (strbegin < origend)
    {
      /* find first letter */
      while (*strbegin && !isalpha(*strbegin))
        strbegin++;
        
      /* find last letter, converting to lowercase along the way */
      strend = strbegin;
      while (*strend && isalpha(*strend))
      {
        if (isupper(*strend))
          *strend = tolower(*strend);
        strend++;
      }
      
      if (strbegin < strend)
      {
        *strend = '\0';
        StemWord(strbegin, stem, rules, debug);
        printf("%s\n", stem);
        fprintf(stderr, "%s (%s)\n", stem, debug);
      }
      strbegin = strend + 1;
    }
  }
  close(wordfile);
} /* end main */
  

/* ReverseString reverses a string in
 * place -- useful while reading the
 * rules.
 */

void ReverseString(char * str)
{
  int  last;
  int  half;
  int  i;
  char ch;
  
  last = strlen(str) - 1;
  half = (last + 1) / 2;
  for (i = 0; i < half; ++i)
  {
    ch = str[last - i];
    str[last - i] = str[i];
    str[i] = ch;
  }
} /* end ReverseString */


/* LoadRules reads a rules file and
 * produces the ruleset structure.
 */

rule_t ** LoadRules(const char * rulepath)
{
  rule_t ** rules;
  rule_t *  rule;
  rule_t *  tmp_rule;
  char      file_ch;
  char      tmp_str[SHORTSTR];
  int       str_idx;
  int       line;
  int       tmp_idx;
  int       rule_idx;
  int       id_idx;
  FILE *    rulefile;
  
  rulefile = fopen(rulepath, "r");
  if (!rulefile)
  {
    perror("Cannot open rule file");
    return NULL;
  }
  
  rules = (rule_t **)calloc(26, sizeof(rule_t *));
  
  line = 0;
  while (file_ch = fgetc(rulefile))
  {
    if (isspace(file_ch))
      continue;
    
    /* start rule */
    line++;
    rule_idx = file_ch - 97;
    
    if (rule_idx < 0 || rule_idx > 25)
    {
      perror("Invalid rule encountered");
      return NULL;
    }
    rule = (rule_t *)calloc(1, sizeof(rule_t));
    sprintf(rule->id, "(%d:", line);
    id_idx = strlen(rule->id);
    
    /* get suffix string */
    str_idx = 0;
    while (isalpha(file_ch))
    {
      rule->suffix[str_idx++] = file_ch;
      rule->id[id_idx++] = file_ch;
      file_ch = fgetc(rulefile);
    }
    rule->suffix[str_idx] = '\0';
    ReverseString(rule->suffix);
    
    /* check for intact flag */
    if (file_ch == '*')
    {
      rule->intact = 1;
      rule->id[id_idx++] = file_ch;
      file_ch = fgetc(rulefile);
    }
    
    /* get remove count */
    str_idx = 0;
    while (isdigit(file_ch))
    {
      tmp_str[str_idx++] = file_ch;
      rule->id[id_idx++] = file_ch;
      file_ch = fgetc(rulefile);
    }
    tmp_str[str_idx] = '\0';
    if (str_idx)
      rule->remove = atoi(tmp_str);
    
    /* get append string */
    str_idx = 0;
    while (isalpha(file_ch))
    {
      rule->append[str_idx++] = file_ch;
      rule->id[id_idx++] = file_ch;
      file_ch = fgetc(rulefile);
    }
    rule->append[str_idx] = '\0';
    
    /* get continue/stop character */
    if (file_ch == '>')
    {
      rule->restem = 1;
    }
    else if (file_ch != '.')
    {
      perror("Invalid rule encountered");
      return NULL;
    }
    rule->id[id_idx++] = file_ch;
    rule->id[id_idx++] = ')';
    rule->id[id_idx] = '\0';
    
    if (strstr(rule->id, ":end0.)"))
    {
      /* encountered pseudo-rule: stop */
      fclose(rulefile);
      return rules;
    }
    
    /* add rule to ruleset */
    if (rules[rule_idx] == NULL)
    {
      /* first rule for this letter */
      rules[rule_idx] = rule;
    }
    else
    {
      /* walk the list and add rule at the end */
      tmp_rule = rules[rule_idx];
      while (tmp_rule->next != NULL)
        tmp_rule = tmp_rule->next;
      tmp_rule->next = rule;
    }
    
    /* skip comments, etc. to end of line */
    while (file_ch && file_ch != '\n')
      file_ch = fgetc(rulefile);
  }
  fclose(rulefile);
  return rules;
} /* end LoadRules */


/* IsValid returns 1 if the parameter
 * is an acceptable stem, or 0 if not.
 * This prevents over-stemming by
 * limiting the shortest final stem.
 */

int IsValid(const char * stem)
{
  switch (stem[0])
  {
    case 'a':
    case 'e':
    case 'i':
    case 'o':
    case 'u':
      return (strlen(stem) >= 2);
  }
  return (strlen(stem) >= 3 &&
          (strchr(stem, 'a') ||
           strchr(stem, 'e') ||
           strchr(stem, 'i') ||
           strchr(stem, 'o') ||
           strchr(stem, 'u') ||
           strchr(stem, 'y')));
} /* end IsValid */


/* RuleMatches returns 1 if the
 * rule can be applied to the stem,
 * and 0 if the rule doesn't match.
 */

int RuleMatches(const rule_t * rule, const char * stem, int intact)
{
  if (!intact && rule->intact)
    return 0;
  if (strlen(rule->suffix) > strlen(stem))
    return 0;
  if (strcmp(rule->suffix, &stem[strlen(stem) - strlen(rule->suffix)]))
    return 0;
  return 1;
} /* end RuleMatches */


/* ApplyRule takes a rule and stem,
 * and produces the new stem created
 * by applying the remove and append
 * parts of the rule.
 */

void ApplyRule(const rule_t * rule, const char * stem, char * new_stem)
{
  int newlen;
  
  strncpy(new_stem, stem, LONGSTR - 1);
  new_stem[LONGSTR - 1] = '\0';
  if (rule->remove)
  {
    newlen = strlen(new_stem) - rule->remove;
    if (newlen < 0)
      newlen = 0;
    new_stem[newlen] = 0;
  }
  strncat(new_stem, rule->append, LONGSTR - 1 - strlen(new_stem));
} /* end ApplyRule */



/* StemWord is the main entry point
 * for the stemmer. It takes a word
 * and a reference to a ruleset
 * structure (see LoadRules).
 */

void StemWord(const char * word, char * stem, rule_t ** rules, char * debug)
{
  int     intact;
  int      restem;
  char     last_letter;
  char     result[LONGSTR];
  rule_t * rule;
  
  if (debug)
    debug[0] = '\0';
  
  strncpy(stem, word, LONGSTR - 1);
  stem[LONGSTR - 1] = '\0';
  
  /* only stem if word passes acceptability rules */
  if (!IsValid(stem))
    return;
  
  if (debug)
    strcpy(debug, stem);
  
  intact = 1;
  restem = 1;
  while (restem)
  {
    /* exit loop unless we apply a continuing rule */
    restem = 0;
    
    /* try each rule for stem's last letter */
    last_letter = stem[strlen(stem) - 1];
    for (rule = rules[last_letter - 97]; rule; rule = rule->next)
    {
      /* make sure this rule matches */
      if (!RuleMatches(rule, stem, intact))
        continue;
      
      /* apply the rule, check if result is acceptable */
      ApplyRule(rule, stem, result);
      if (!IsValid(result))
        continue;
      
      /* rule matched, replace stem and continue or exit */
      strncpy(stem, result, LONGSTR - 1);
      stem[LONGSTR - 1] = '\0';
      intact = 0;
      if (debug)
      {
        strcat(debug, " =");
        strcat(debug, rule->id);
        strcat(debug, "=> ");
        strcat(debug, stem);
      }
      restem = rule->restem;
      break;  /* kick out to outer loop */
    }
  }
} /* end StemWord */

