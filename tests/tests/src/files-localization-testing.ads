--  Test-only access to private subprograms of Files.Localization, kept out of the program.
package Files.Localization.Testing is

   --  Forget the remembered locales, so the next call reads the locale
   --  variables and the desktop's configuration again, for a test that
   --  changed them.
   procedure Reread_Locale_Environment;

   --  A runtime of the base catalog at Base with the locale shard at Shard
   --  added as Files.Localization adds one (Load_Locale_Shard), asked for
   --  Key in Locale.
   --
   --  @param Base The base catalog.
   --  @param Shard The locale catalog added to it.
   --  @param Locale The locale to render in.
   --  @param Key The key to render.
   --  @param Loaded Whether the shard was loaded.
   --  @return The text Key renders to, or "" when the runtime cannot render it.
   function Render_With_Shard
     (Base, Shard, Locale, Key : String;
      Loaded                   : out Boolean)
      return String;

   --  Files.Localization.Text's answer for Key in Locale from a runtime of
   --  the base catalog at Base with the locale shards at Language_Shard and
   --  Region_Shard added, so the region-over-language rule can be checked
   --  against catalogs the test writes.
   --
   --  @param Base The base catalog.
   --  @param Language_Shard The language's catalog.
   --  @param Region_Shard The region's catalog.
   --  @param Locale The locale to render in.
   --  @param Key The key to render.
   --  @return The text Key renders to, or "" when the runtime cannot render it.
   function Text_With_Shards
     (Base, Language_Shard, Region_Shard, Locale, Key : String)
      return String;

   --  Normalize an operating-system locale name to the catalog locale form.
   --  A glibc modifier naming a script (@latin, @cyrillic, @devanagari)
   --  becomes the script subtag after the language, and @valencia the
   --  variant at the end: sr_RS@latin is sr-Latn-RS. Other modifiers go.
   --
   --  @param Value Locale text such as da_DK.UTF-8.
   --  @return Normalized locale such as da-DK, or en for empty, C, or POSIX.
   function Normalize_Locale (Value : String) return String;

end Files.Localization.Testing;
