with Humanize.Contexts;

--  Default localization facade for files.
package Files.Localization is

   --  Normalize an operating-system locale name to the catalog locale form.
   --
   --  @param Value Locale text such as da_DK.UTF-8.
   --  @return Normalized locale such as da-DK, or en for empty, C, or POSIX.
   function Normalize_Locale (Value : String) return String;

   --  Return the process locale inferred from the environment.
   --
   --  @return Normalized locale from LC_ALL, LC_MESSAGES, or LANG; en when none is usable.
   function System_Locale return String;

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

end Files.Localization;
