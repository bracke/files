--  The roots a window offers: the host's filesystems, mounts, drives and
--  the user's places, and the label and name each is shown with. Clients
--  with this, not the whole of Files.File_System.
package Files.File_System.Roots is

   --  Return available filesystem root locations with labels and source kind.
   --
   --  @return Root entries available on the host platform.
   function Available_Root_Entries return Root_Entry_Vectors.Vector;

   --  Return the label of a root location: a localization key (e.g.
   --  "root.home", or "root.mount", whose pattern takes Root_Name as {name}),
   --  or, for a plain filesystem root, its path.
   --
   --  @param Path Root path.
   --  @param Kind Root classification.
   --  @return Label key or literal text.
   function Root_Label (Path : String; Kind : Root_Kind) return String;

   --  Return the {name} a root's label pattern takes: a mount's or a
   --  favorite's leaf name, a drive's path; empty for kinds with no name.
   --
   --  @param Path Root path.
   --  @param Kind Root classification.
   --  @return The name, which may hold any character a file name can.
   function Root_Name (Path : String; Kind : Root_Kind) return String;
end Files.File_System.Roots;
