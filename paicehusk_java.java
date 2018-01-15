import java.io.*;
import java.util.*;

class PaiceHusk
{
  // each rule is an instance of the PaiceRule class
  static class PaiceRule
  {
    public char letter;
    public boolean intact;
    public boolean restem;
    public int remove;
    public String suffix;
    public String append;
    public String id;
    
    // The constructor takes a line
    // and line number, and fills out
    // the members for the new instance.
    
    public PaiceRule(String line, int idnumber)
    {
      if (!line.matches("\\s*[a-z]+\\*?\\d+[a-z]*[>.].*"))
      {
        throw new RuntimeException("Invalid rule: " + line);
      }
      
      String rule = line.replaceFirst("\\s*([a-z]+\\*?\\d+[a-z]*[>.]).*",
                                      "$1");
      id = new String("(" + idnumber + ":" + rule + ")");
      
      letter = rule.charAt(0);
      rule = rule.replaceFirst("([a-z]+)(\\*?)(\\d+)([a-z]*)([>.])",
                               "$1 $2 $3 $4 $5");
      
      String parts[] = rule.split(" ", -1);
      suffix = new StringBuffer(parts[0]).reverse().toString();
      intact = parts[1].equals("*");
      remove = Integer.parseInt(parts[2]);
      append = parts[3];
      restem = parts[4].equals(">");
    } /* end PaiceRule(String) */
    
    
    // matches returns true if the
    // rule can be applied to the
    // supplied stem.
    
    public boolean ruleMatches(String stem, boolean stemIntact)
    {
      if (!stemIntact && intact)
        return false;
      return stem.endsWith(suffix);
    } // end matches
    
    
    // applyRule takes a rule and stem,
    // and produces the new stem created
    // by applying the remove and append
    // parts of the rule.

    public String applyRule(String stem)
    {
      StringBuffer newstem = new StringBuffer(stem);
      newstem.setLength(newstem.length() - remove);
      newstem.append(append);
      return newstem.toString();
    } // end apply
    
  } // end class PaiceRule


  // To run:
  //   java PaiceHusk <rulefile> <wordfile>
  // Stems are output to stdout.
  // Stems and rule info are output to stderr.

  public static void main(String argv[]) throws Exception
  {
    // check command line arguments
    if (argv.length < 2)
    {
      System.err.println("Usage: java PaiceHusk <rulefile> <wordfile>");
      return;
    }
    
    HashMap rules = loadRules(argv[0]);
    if (rules == null)
      return;
    
    BufferedReader wordfile = new BufferedReader(
                                new FileReader(argv[1]));
    String line, stem;
    StringBuffer debug = new StringBuffer();
    while ((line = wordfile.readLine()) != null)
    {
      /* process each word in line */
      int strbegin = 0;
      int strend;
      while (strbegin < line.length())
      {
        /* find first letter */
        while (strbegin < line.length() &&
               !Character.isLetter(line.charAt(strbegin)))
          strbegin++;
        
        /* find last letter */
        strend = strbegin;
        while (strend < line.length() &&
               Character.isLetter(line.charAt(strend)))
          strend++;
        
        if (strbegin < strend)
        {
          stem = stemWord(line.substring(strbegin, strend).toLowerCase(),
                          rules, debug);
          System.out.println(stem);
          System.err.println(stem + " (" + debug + ")");
        }
        strbegin = strend + 1;
      }
    }
    wordfile.close();
    
  } // end main


  // loadRules reads a rules file and
  // produces the ruleset structure.

  static HashMap loadRules(String rulepath) throws IOException
  {
    HashMap rules = new HashMap();
    
    BufferedReader rulefile = new BufferedReader(
                                new FileReader(rulepath));
    String line;
    for (int i = 1; (line = rulefile.readLine()) != null; ++i)
    {
      PaiceRule rule = new PaiceRule(line, i);
      if (rule.id.endsWith("end0.)"))
      {
        // encountered pseudo-rule: stop
        rulefile.close();
        return rules;
      }
        
      Character letter = new Character(rule.letter);
      ArrayList ruleset;
      if (rules.containsKey(letter))
      {
        ruleset = (ArrayList)rules.get(letter);
      }
      else
      {
        ruleset = new ArrayList();
        rules.put(letter, ruleset);
      }
      ruleset.add(rule);
    }
    rulefile.close();
    return rules;
  } // end loadRules
  
    
  // isValid returns 1 if the parameter
  // is an acceptable stem, or 0 if not.
  // This prevents over-stemming by
  // limiting the shortest final stem.

  static boolean isValid(String stem)
  {
    if (stem.matches("[aeiou].*"))
    {
      return (stem.length() >= 2);
    }
    if (stem.matches(".*[aeiouy].*"))
    {
      return (stem.length() >= 3);
    }
    return false;
  } // end isValid

  // stemWord is the main entry point
  // for the stemmer. It takes a word
  // and a reference to a ruleset
  // structure (see loadRules).

  static String stemWord(String word, HashMap rules, StringBuffer debug)
  {
    if (debug != null)
      debug.setLength(0);
    
    String stem = word;
    
    // only stem if word passes acceptability rules
    if (!isValid(stem))
      return stem;
    
    if (debug != null)
      debug.append(stem);

    boolean intact = true;
    boolean restem = true;
    while (restem)
    {
      // exit loop unless we apply a continuing rule
      restem = false;
      
      // try each rule for stem's last letter
      Character letter = new Character(stem.charAt(stem.length() - 1));
      ArrayList ruleset = (ArrayList)rules.get(letter);
      if (ruleset == null)
        break;
      
      ListIterator iter = ruleset.listIterator();
      while (iter.hasNext())
      {
        PaiceRule rule = (PaiceRule)iter.next();
        
        // make sure this rule matches
        if (!rule.ruleMatches(stem, intact))
          continue;
        
        // apply the rule, check if result is acceptable
        String result = rule.applyRule(stem);
        if (!isValid(result))
          continue;
        
        // rule matched, replace stem and continue or exit
        stem = result;
        intact = false;
        if (debug != null)
          debug.append(" =" + rule.id + "=> " + result);
        restem = rule.restem;
        break;  // kick out to outer loop
      }
    }
    return stem;
  } // end stemWord
  
} // end class PaiceHusk

