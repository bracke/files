--  Test-only access to private subprograms of Files.Localization, kept out of the program.
package Files.Localization.Testing is

   --  Files.Localization.Locale_Config_Value.
   --
   --  @param Path Configuration file to read.
   --  @param Section Section to look in, or "".
   --  @param Key Key to look up.
   --  @return The value, without one matching pair of surrounding quotes.
   function Config_Value
     (Path    : String;
      Section : String;
      Key     : String)
      return String;

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

end Files.Localization.Testing;
