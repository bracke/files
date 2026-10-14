--  Location of immutable resources installed with the running executable.
package Files.Resources is

   --  Return the absolute share directory belonging to this executable.
   --  The normal installed layout is bin/<program> beside share/, while the
   --  nested test layout is tests/bin/<program> beside ../../share/.
   --  @return The located directory, or an executable-relative default when
   --          the installation is incomplete; never a current-directory path.
   function Share_Root return String;

   --  Resolve a path below Share_Root, or return "" when the host cannot
   --  identify its own executable.
   --  @param Relative_Path Resource path relative to the installed share root.
   --  @return Absolute resource path, or "" when no executable root is known.
   function Share_Path (Relative_Path : String) return String;

end Files.Resources;
