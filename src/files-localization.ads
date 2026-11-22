with Ada.Strings.Unbounded;
with Humanize.Contexts;
private with Messages.Runtime;

--  Default localization facade for files.
package Files.Localization is

   --  Normalize an operating-system locale name to the catalog locale form.
   --  A glibc modifier naming a script (@latin, @cyrillic, @devanagari)
   --  becomes the script subtag after the language, and @valencia the
   --  variant at the end: sr_RS@latin is sr-Latn-RS. Other modifiers go.
   --
   --  @param Value Locale text such as da_DK.UTF-8.
   --  @return Normalized locale such as da-DK, or en for empty, C, or POSIX.
   function Normalize_Locale (Value : String) return String;

   --  Return the process locale inferred from the environment. The answer is
   --  worked out once and remembered (a test rereads it through
   --  Files.Localization.Testing): files never changes its own locale
   --  variables, and the label of every frame asks.
   --
   --  @return Normalized locale from LC_ALL, LC_MESSAGES, or LANG; en when none is usable.
   function System_Locale return String;

   --  Whether the interface reads right to left: System_Locale is Arabic,
   --  Persian, Urdu, Hebrew, Yiddish or another locale I18N.Locales calls
   --  right to left. The window is then drawn mirrored.
   --
   --  @return True for a right-to-left interface locale.
   function Layout_Is_Right_To_Left return Boolean;

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

   --  Forget the remembered System_Locale, System_Time_Locale and
   --  System_Number_Locale, so the next call reads LC_ALL, LC_MESSAGES,
   --  LC_TIME, LC_NUMERIC, LANG and the desktop's configuration under HOME
   --  again. For a caller that changed them (a test, through Files.Localization.Testing).
   procedure Reread_Locale_Environment;

   --  Text's answer from Item for an already normalized locale whose
   --  catalogs are loaded: the regional message, else its language's, else
   --  Key.
   --
   --  Which catalog defines the key decides, never what the text says: a
   --  regional value that happens to equal the English one is still the
   --  region's own and must win over the language's.
   --
   --  @param Item The runtime holding the catalogs.
   --  @param Key The message key.
   --  @param Locale The normalized locale.
   --  @return The rendered text, or Key.
   function Regional_Text
     (Item   : Messages.Runtime.Runtime;
      Key    : String;
      Locale : String)
      return String;

   --  Add the locale catalog shard at Path to Item without risking it: one
   --  that does not load -- malformed, or repeating a key already loaded --
   --  is skipped with a trace (Files.Diagnostics), and Item stays as it was,
   --  rather than one bad shard making every text render as its raw key.
   --
   --  @param Item The runtime, already holding the base catalog.
   --  @param Path The locale catalog to add.
   --  @return True when the shard was loaded.
   function Load_Locale_Shard
     (Item : in out Messages.Runtime.Runtime;
      Path : String)
      return Boolean;

end Files.Localization;
