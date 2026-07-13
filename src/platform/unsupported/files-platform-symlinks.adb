package body Files.Platform.Symlinks is

   --  No symbolic links here.

   function Create (Target : String; Link_Path : String) return Boolean is
      pragma Unreferenced (Target, Link_Path);
   begin
      return False;
   end Create;

end Files.Platform.Symlinks;
