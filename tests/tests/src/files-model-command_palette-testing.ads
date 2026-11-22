--  Test-only queries of Files.Model.Command_Palette, kept out of the program.
package Files.Model.Command_Palette.Testing is

   --  @param Model Model to inspect.
   --  @return The palette's current query text.
   function Query (Model : Window_Model) return String;

end Files.Model.Command_Palette.Testing;
