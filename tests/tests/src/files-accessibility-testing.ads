--  Test-only views of the application's accessibility tree.
package Files.Accessibility.Testing is

   --  How many windows the application's tree holds now.
   --
   --  @return The number of windows published and not forgotten since Stop.
   function Published_Windows return Natural;

end Files.Accessibility.Testing;
