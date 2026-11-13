with Ada.Strings.Unbounded;
with Humanize.Contexts;

--  Default localization facade for files.
package Files.Localization is

   --  Normalize an operating-system locale name to the catalog locale form.
   --
   --  @param Value Locale text such as da_DK.UTF-8.
   --  @return Normalized locale such as da-DK, or en for empty, C, or POSIX.
   function Normalize_Locale (Value : String) return String;

   --  Return the process locale inferred from the environment. The answer is
   --  remembered until LC_ALL, LC_MESSAGES or LANG changes; with none of them
   --  set, the host's native locale is therefore asked once, not per call.
   --
   --  @return Normalized locale from LC_ALL, LC_MESSAGES, or LANG; en when none is usable.
   function System_Locale return String;

   --  The message locale as the environment spells it: the first of LC_ALL,
   --  LC_MESSAGES and LANG that is set, trimmed but not normalized, so
   --  POSIX modifiers (sr_RS@latin) survive for desktop-entry keys. One
   --  order for the interface (System_Locale) and those keys alike.
   --
   --  @return That value, or "" when none of them is set.
   function Message_Locale_Variable return String;

   --  Return the process date/time locale inferred from the environment.
   --
   --  @return Normalized locale from LC_ALL, LC_TIME, or LANG; en when none is usable.
   function System_Time_Locale return String;

   --  Return the process numeric locale inferred from the environment.
   --
   --  @return Normalized locale from LC_ALL, LC_NUMERIC, or LANG; en when none is usable.
   function System_Number_Locale return String;

   --  Render the localized text for Key.
   --
   --  @param Key Stable localization key.
   --  @param Locale Requested locale identifier, or empty to use System_Locale.
   --  @return Localized text when known, otherwise Key.
   function Text
     (Key    : String;
      Locale : String := "")
      return String;

   --  A named value a message pattern fills in: {Name} in the pattern.
   type Argument is record
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      Value : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Argument_List is array (Positive range <>) of Argument;

   --  Key's message pattern with Arguments filled in, in Locale's wording and
   --  punctuation ("{label}: {value}" in English, "{label} : {value}" in
   --  French). A locale without the message takes the default locale's.
   --
   --  @param Key Stable localization key of a message pattern.
   --  @param Arguments The values its placeholders name.
   --  @param Locale Requested locale identifier, or empty to use System_Locale.
   --  @return The rendered message, or Key when it cannot be rendered.
   function Text
     (Key       : String;
      Arguments : Argument_List;
      Locale    : String := "")
      return String;

   --  "Label: Value" in the locale's punctuation ("Label : Value" in French).
   --
   --  @param Label The label, already localized.
   --  @param Value Its value.
   --  @param Locale Requested locale identifier, or empty to use System_Locale.
   --  @return The pair as the locale writes it.
   function Label_Value
     (Label  : String;
      Value  : String;
      Locale : String := "")
      return String;

   --  Text (Key, Arguments) for a pattern with one placeholder.
   --
   --  @param Key Stable localization key of a message pattern.
   --  @param Name The placeholder's name: {Name} in the pattern.
   --  @param Value Its value.
   --  @param Locale Requested locale identifier, or empty to use System_Locale.
   --  @return The rendered message, or Key when it cannot be rendered.
   function Text
     (Key    : String;
      Name   : String;
      Value  : String;
      Locale : String := "")
      return String;

   --  A humanize context for Locale (the system locale when empty), over the
   --  same message runtime as Text: humanize's catalog is loaded into it, so
   --  sizes, times and counts read in CLDR's wording for every locale.
   --  @param Locale Locale identifier, or "" for the system locale.
   --  @return A context over files' message runtime.
   function Humanize_Context (Locale : String := "") return Humanize.Contexts.Context;

   --  Whether humanize's catalog loaded beside files' own; without it a
   --  caller keeps files' wording.
   --  @return True when humanize's catalog is loaded.
   function Humanize_Available return Boolean;

   --  Key's message rendered with Count as its plural operand, in Locale (the
   --  system locale when empty) -- or "" when neither Locale nor its language
   --  has the message, so that a caller keeps its own wording rather than
   --  borrow another language's.
   --  @param Key Catalog key of a plural message over a "count" argument.
   --  @param Count The count.
   --  @param Locale Locale identifier, or "" for the system locale.
   --  @return The rendered message, or "" as described above.
   function Count_Text
     (Key    : String;
      Count  : Natural;
      Locale : String := "")
      return String;

private

   --  The value of Key in the configuration file at Path: in its Section
   --  ([Section] header), or before any section when Section is "". A value
   --  in one matching pair of quotes (" or ', as locale.conf's shell syntax
   --  allows) is returned without them.
   --
   --  @param Path Configuration file to read.
   --  @param Section Section to look in, or "".
   --  @param Key Key to look up.
   --  @return The value, or "" when the file or the key is missing.
   function Locale_Config_Value
     (Path    : String;
      Section : String;
      Key     : String)
      return String;

end Files.Localization;
