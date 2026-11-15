--  The process environment as files reads it: one answer for every unit,
--  asked of Hostkit, which owns how a host keeps its environment.
package Files.Environment is

   --  @param Name The variable.
   --  @return Its value, or "" when it is unset (or Name is empty).
   function Value (Name : String) return String;

   --  @param Name The variable.
   --  @return Whether it is set, even to nothing (a host where setting a
   --  variable to "" removes it never answers that).
   function Is_Set (Name : String) return Boolean;

   --  Set Name for this process and the programs it starts.
   --
   --  @param Name The variable.
   --  @param Value Its new value.
   procedure Set (Name : String; Value : String);

   --  The locale messages are shown in, as the environment spells it: the
   --  first of LC_ALL, LC_MESSAGES and LANG that is set, trimmed but not
   --  normalized, so POSIX modifiers (sr_RS@latin) survive. Hostkit's one
   --  reading, which a Desktop Entry's localized keys follow too.
   --
   --  @return That value, or "" when none of them is set.
   function Message_Locale return String;

   --  Which variable decides a locale category: the first of LC_ALL,
   --  Category and LANG that is set. Hostkit's one reading of POSIX's
   --  precedence, which Message_Locale follows for LC_MESSAGES.
   --
   --  @param Category The category's variable ("LC_TIME", "LC_NUMERIC").
   --  @return "LC_ALL", Category or "LANG", or "" when none of them is set.
   function Locale_Variable (Category : String) return String;

   --  Remove Name from this process's environment.
   --
   --  @param Name The variable.
   procedure Clear (Name : String);

end Files.Environment;
