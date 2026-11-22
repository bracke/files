with Hostkit.Metadata;
with Hostkit.Process;
with Hostkit.Fs;
with Hostkit.Mounts;
with Files.Name_Parts;
with Files.Text_Basics;
use Files.Text_Basics;

separate (Files.File_System.Roots)
function Available_Root_Entries return Root_Entry_Vectors.Vector is
   Roots : Root_Entry_Vectors.Vector;
   Max_Discovered_Roots : constant Natural := 1_024;
   Max_Root_Entries_Scanned : constant Natural := 4_096;
   Root_Entries_Scanned : Natural := 0;
   --  The folders the host's conventions give this user (the home, the
   --  Windows profile drive, share and OneDrive, where Linux mounts media).
   Places    : constant Hostkit.Fs.User_Place_List := Hostkit.Fs.User_Places;
   --  The account this process runs as, by the host's own records: the
   --  name a volumes folder (/media/<user>) is made for. Not $USER, which
   --  any parent can set and Windows does not set at all.
   function Account_Name return String is separate;
   User_Name : constant String := Account_Name;

   function Place_Of (Kind : Hostkit.Fs.User_Place_Kind) return String is
   begin
      for Place of Places loop
         if Hostkit.Fs."=" (Place.Kind, Kind) then
            return To_String (Place.Path);
         end if;
      end loop;
      return "";
   end Place_Of;

   Desktop_Mounts : constant String := Place_Of (Hostkit.Fs.Desktop_Mounts_Parent);
   --  What a mount point under Desktop_Mounts starts with: the folder and
   --  the host's separator after it.
   Mounts_Child   : constant String := Hostkit.Fs.Join (Desktop_Mounts, "x");
   Mounts_Prefix  : constant String := Mounts_Child (Mounts_Child'First .. Mounts_Child'Last - 1);

   function Is_Pseudo_Mount_Type (Filesystem_Type : String) return Boolean renames Hostkit.Mounts.Is_Pseudo;

   function Is_Network_Filesystem_Type (Filesystem_Type : String) return Boolean renames Hostkit.Mounts.Is_Network;

   function Root_Kind_For_Mount
     (Mount_Point     : String;
      Filesystem_Type : String)
      return Root_Kind is separate;

   function Is_User_Visible_Mount_Point (Mount_Point : String) return Boolean is
     (Is_User_Visible_Mount_Point
        (Mount_Point, Desktop_Mounts));

   function Is_Displayable_Root_Mount
     (Mount_Point     : String;
      Filesystem_Type : String)
      return Boolean is separate;

   --  The host's mount table, read once for the whole discovery.
   Mounts : constant Hostkit.Mounts.Mount_Vectors.Vector := Hostkit.Mounts.Table;

   function Filesystem_Type_For (Path : String) return String is separate;

   function Contains_Root (Path : String) return Boolean is separate;

   procedure Append_If_Directory
     (Path : String;
      Kind : Root_Kind)
   is separate;

   procedure Append_Children
     (Parent   : String;
      Kind     : Root_Kind;
      Per_User : Boolean := False)
   is separate;

   procedure Append_Mounts is separate;
begin
   --  The filesystem root where the host has one (Hostkit.Mounts says why
   --  Windows has none); there the drive loop below enumerates the roots.
   if Hostkit.Mounts.Filesystem_Root /= "" then
      Append_If_Directory (Hostkit.Mounts.Filesystem_Root, Root_Filesystem);
   end if;
   Append_Mounts;
   --  The home first, so it keeps its own kind should another place name it.
   for Place of Places loop
      if Hostkit.Fs."=" (Place.Kind, Hostkit.Fs.Home_Place) then
         Append_If_Directory (To_String (Place.Path), Root_Home);
      end if;
   end loop;
   Append_If_Directory (Hostkit.Fs.Current_Directory, Root_Current);
   --  Where this host mounts volumes, its own folders only: Linux no
   --  longer looks for /Volumes, nor tries 26 drive letters.
   for Place of Hostkit.Mounts.Volume_Places loop
      case Place.Kind is
         when Hostkit.Mounts.Drive_Root =>
            Append_If_Directory (To_String (Place.Path), Root_Windows_Drive);
         when Hostkit.Mounts.Volumes_Folder =>
            Append_Children (To_String (Place.Path), Root_Mount);
         when Hostkit.Mounts.User_Volumes_Folder =>
            Append_Children (To_String (Place.Path), Root_User_Mount, Per_User => True);
      end case;
   end loop;
   for Place of Places loop
      declare
         Path : constant String := To_String (Place.Path);
      begin
         case Place.Kind is
            when Hostkit.Fs.Home_Place =>
               null;
            when Hostkit.Fs.Drive_Place =>
               Append_If_Directory (Path, Root_Windows_Drive);
            when Hostkit.Fs.Profile_Place | Hostkit.Fs.Cloud_Place =>
               Append_If_Directory (Path, Root_User_Mount);
            when Hostkit.Fs.Network_Place =>
               Append_If_Directory (Path, Root_Network_Mount);
            when Hostkit.Fs.Desktop_Mounts_Parent =>
               Append_Children (Path, Root_Network_Mount);
         end case;
      end;
   end loop;

   if Roots.Is_Empty then
      declare
         Full : constant String := Files.IO.Fs_Primitives.Full_Name (Hostkit.Fs.Current_Directory);
      begin
         Roots.Append
           (Root_Entry'
              (Path  => To_Unbounded_String (Full),
               Label => To_Unbounded_String (Root_Label (Full, Root_Current)),
               Name  => Null_Unbounded_String,
               Detail => Null_Unbounded_String,
               Kind  => Root_Current,
               Volume_Name => To_Unbounded_String (Files.Name_Parts.Leaf_Of (Full)),
               Removable => False));
      end;
   end if;

   declare
      function Less (Left : Root_Entry; Right : Root_Entry) return Boolean is
      begin
         return To_String (Left.Path) < To_String (Right.Path);
      end Less;

      package Sorting is new Root_Entry_Vectors.Generic_Sorting ("<" => Less);
   begin
      Sorting.Sort (Roots);
   end;

   return Roots;
end Available_Root_Entries;
