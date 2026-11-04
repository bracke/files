with Hostkit.Metadata;
with Interfaces;

separate (Files.File_System)
function Load_Subdirectories
  (Path     : String;
   Settings : Files.Settings.Settings_Model;
   Options  : Files.Types.Listing_Options)
   return Directory_Load_Result
is
   use type Interfaces.Unsigned_64;
   Items      : Item_Vectors.Vector;
   Normalized : Unbounded_String;
   --  The file-type bits of a native mode, and a directory's.
   Type_Mask  : constant Interfaces.Unsigned_64 := 8#170000#;
   Directory  : constant Interfaces.Unsigned_64 := 8#040000#;

   --  A directory itself, not a link to one: from one no-follow stat where
   --  the mode is the host's, else asked in two steps.
   function Is_Subdirectory (Full : String) return Boolean is
   begin
      if Hostkit.Metadata.Mode_Bits_Are_Native then
         declare
            Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Full);
         begin
            return Revision.Available and then (Revision.Mode and Type_Mask) = Directory;
         end;
      end if;
      return not Hostkit.Fs.Is_Link (Full) and then GNAT.OS_Lib.Is_Directory (Full);
   end Is_Subdirectory;

   procedure Add_Entry (Name : String) is
      Full : constant String := Join_Path (To_String (Normalized), Name);
   begin
      if (Options.Show_Hidden or else Name (Name'First) /= '.')
        and then Is_Subdirectory (Full)
      then
         declare
            Hidden   : constant Boolean := Name (Name'First) = '.' or else Hostkit.Fs.Is_Hidden (Full);
            Filetype : constant String :=
              Files.File_Types.Detect_Filetype (Settings, Files.Types.Directory_Item, Name);
            Item     : Directory_Item :=
              (Name        => To_Unbounded_String (Name),
               Full_Path   => To_Unbounded_String (Full),
               Parent_Path => Normalized,
               Hidden      => Hidden,
               Kind        => Files.Types.Directory_Item,
               Filetype    => To_Unbounded_String (Filetype),
               Icon_Id     =>
                 To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Files.Types.Directory_Item, Filetype)),
               others      => <>);
         begin
            if Options.Show_Hidden or else not Hidden then
               begin
                  Item.Modified_Time := Ada.Directories.Modification_Time (Full);
                  Item.Modified_Available := True;
               exception
                  when Swallowed : others =>
                     --  Undated, it still sorts and opens.
                     Files.Diagnostics.Note (Swallowed, "Files.File_System.Directory");
               end;
               Item.Creation_Time := Hostkit.Metadata.File_Creation_Time (Full, Item.Creation_Available);
               Items.Append (Item);
            end if;
         end;
      end if;
   exception
      when Failure : others =>
         --  One unreadable entry is left out of the tree, not the folder.
         Files.Diagnostics.Note (Failure, "Files.File_System.Directory");
   end Add_Entry;
begin
   if not Files.Fs_Primitives.Directory_Exists (Path) then
      return (Success => False, Path => To_Unbounded_String (Path), Items => Items,
              Error_Key => To_Unbounded_String ("error.directory.load"), Signature => <>);
   end if;
   Normalized := To_Unbounded_String (Ada.Directories.Full_Name (Path));
   Support.For_Each_Entry (Path, Add_Entry'Access);
   Sort_Items (Items, Options.Sort_Field, Options.Sort_Ascending);
   return (Success => True, Path => Normalized, Items => Items, Error_Key => Null_Unbounded_String,
           Signature => <>);
exception
   when others =>
      return (Success => False, Path => To_Unbounded_String (Path), Items => Items,
              Error_Key => To_Unbounded_String ("error.directory.load"), Signature => <>);
end Load_Subdirectories;
