--  Test-only views of where Files.Resources finds the installed resources.
package Files.Resources.Testing is

   --  Return the absolute share directory belonging to this executable.
   --
   --  @return The located directory, or an executable-relative default when
   --          the installation is incomplete; never a current-directory path.
   function Share_Root return String;

end Files.Resources.Testing;
