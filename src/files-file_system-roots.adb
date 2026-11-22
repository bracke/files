with Files.IO.Fs_Primitives;
with Files.Diagnostics;
with Ada.Strings.Unbounded;

with Hostkit.Metadata;
with Hostkit.Fs;
with Hostkit.Host;
with Files.Name_Parts;

package body Files.File_System.Roots is

   use Ada.Strings.Unbounded;

   function Available_Root_Entries return Root_Entry_Vectors.Vector
     is separate;

   function Root_Label (Path : String; Kind : Root_Kind) return String
     is separate;

   function Root_Name (Path : String; Kind : Root_Kind) return String
     is separate;

   function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean
     is separate;

end Files.File_System.Roots;
