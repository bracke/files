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

   function Is_Link (Path : String) return Boolean;
   --  Is this path a symbolic link (on Windows, any reparse point)?
   --
   --  This cannot be asked portably. GNAT.OS_Lib.Is_Symbolic_Link is built on
   --  lstat, which mingw does not have, so on Windows it answers False for every
   --  path -- links included. It does not fail; it just always says no, which
   --  means a symlink is never recognised as one and a tree walk will happily
   --  descend into it.
   --
   --  @param Path the path to test
   --  @return True when Path is a symbolic link or reparse point

   function Create (Target : String; Link_Path : String) return Boolean;
   --  Create a symbolic link at Link_Path pointing at Target.
   --  @param Target    what the link should point at
   --  @param Link_Path where the link itself goes
   --  @return True when the link was created; False when the platform cannot or
   --          will not make one

end Files.Platform.Symlinks;
