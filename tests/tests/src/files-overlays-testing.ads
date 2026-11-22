--  Test-only queries of Files.Overlays, kept out of the program.
package Files.Overlays.Testing is

   --  How many times Fields was built.
   --
   --  @param Fields A fields cache.
   --  @return Builds so far.
   function Builds (Fields : Settings_Fields_Cache) return Natural;

end Files.Overlays.Testing;
