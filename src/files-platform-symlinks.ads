package Files.Platform.Symlinks is

   --  Creating a symbolic link.
   --
   --  The body is selected per platform by the project file: Linux and macOS use
   --  symlink(2), Windows uses CreateSymbolicLink, and the unsupported stub
   --  always declines.
   --
   --  Windows is allowed to decline for a reason that is not an error: creating a
   --  symbolic link there needs either Developer Mode or the "create symbolic
   --  link" privilege, neither of which an ordinary process can assume. Callers
   --  must therefore treat False as "this machine will not make one", not as a
   --  failure -- which is exactly how the test suite already uses it.

   function Create (Target : String; Link_Path : String) return Boolean;
   --  Create a symbolic link at Link_Path pointing at Target.
   --  @param Target    what the link should point at
   --  @param Link_Path where the link itself goes
   --  @return True when the link was created; False when the platform cannot or
   --          will not make one

end Files.Platform.Symlinks;
