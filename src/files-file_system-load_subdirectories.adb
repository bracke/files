with Hostkit.Directory_Listing;
with Hostkit.Metadata;
with Interfaces;

separate (Files.File_System)
function Load_Subdirectories
  (Path     : String;
   Classes  : Files.File_Types.Classification;
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
      return not Hostkit.Fs.Is_Link (Full) and then Files.IO.Fs_Primitives.Directory_Exists (Full);
   end Is_Subdirectory;

   --  Only what the sort reads: a folder has no size, so by name or size
   --  nothing is asked of it beyond whether it is one.
   use type Files.Types.Sort_Field;
   Needs_Type     : constant Boolean := Options.Sort_Field = Files.Types.Sort_Type;
   Needs_Modified : constant Boolean := Options.Sort_Field = Files.Types.Sort_Changed;
   Needs_Created  : constant Boolean := Options.Sort_Field = Files.Types.Sort_Created;

   procedure Add_Entry (Name : String; Kind : Hostkit.Directory_Listing.Entry_Kind) is
      use type Hostkit.Directory_Listing.Entry_Kind;
      Full : constant String := Hostkit.Fs.Join (To_String (Normalized), Name);
   begin
      --  The listing says what an entry is where the directory records it
      --  (a link as a link): only an entry it cannot name is asked.
      if (Options.Show_Hidden or else Name (Name'First) /= '.')
        and then (Kind = Hostkit.Directory_Listing.Directory
                  or else (Kind = Hostkit.Directory_Listing.Unknown and then Is_Subdirectory (Full)))
      then
         declare
            Hidden   : constant Boolean := Entry_Is_Hidden (Name, Full);
            Filetype : constant String :=
              (if Needs_Type then Files.File_Types.Detect_Filetype (Classes, Files.Types.Directory_Item, Name)
               else "");
            Item     : Directory_Item :=
              (Name        => To_Unbounded_String (Name),
               Full_Path   => To_Unbounded_String (Full),
               Parent_Path => Normalized,
               Hidden      => Hidden,
               Kind        => Files.Types.Directory_Item,
               Filetype    => To_Unbounded_String (Filetype),
               Icon_Id     =>
                 (if Needs_Type
                  then To_Unbounded_String
                    (Files.File_Types.Icon_Id_For (Classes, Files.Types.Directory_Item, Filetype))
                  else Null_Unbounded_String),
               others      => <>);
         begin
            if Options.Show_Hidden or else not Hidden then
               if Needs_Modified then
                  begin
                     Item.Modified_Time := Files.IO.Fs_Primitives.Modification_Time (Full);
                     Item.Modified_Available := True;
                  exception
                     when Swallowed : others =>
                        --  Undated, it still sorts and opens.
                        Files.Diagnostics.Note (Swallowed, "Files.File_System");
                  end;
               end if;
               if Needs_Created then
                  Item.Creation_Time := Hostkit.Metadata.File_Creation_Time (Full, Item.Creation_Available);
               end if;
               Items.Append (Item);
            end if;
         end;
      end if;
   exception
      when Failure : others =>
         --  One unreadable entry is left out of the tree, not the folder.
         Files.Diagnostics.Note (Failure, "Files.File_System");
   end Add_Entry;

   Entries : Hostkit.Directory_Listing.Entry_Vectors.Vector;
begin
   if not Files.IO.Fs_Primitives.Directory_Exists (Path) then
      return (Success => False, Path => To_Unbounded_String (Path), Items => Items,
              Error_Key => To_Unbounded_String (Files.IO.Errors.Directory_Load_Key), Signature => <>);
   end if;
   Normalized := To_Unbounded_String (Files.IO.Fs_Primitives.Full_Name (Path));
   --  The entry cap a listing has (Max_Directory_Entries) stops a
   --  pathological directory here too.
   if not Hostkit.Directory_Listing.List (Path, Entries)
     or else Natural (Entries.Length) > Support.Max_Directory_Entries
   then
      raise Ada.Directories.Use_Error;
   end if;
   for Listed of Entries loop
      Add_Entry (Listed.Name, Listed.Kind);
   end loop;
   Files.Item_Lists.Sort_Items (Items, Options.Sort_Field, Options.Sort_Ascending);
   return (Success => True, Path => Normalized, Items => Items, Error_Key => Null_Unbounded_String,
           Signature => <>);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return (Success => False, Path => To_Unbounded_String (Path), Items => Items,
              Error_Key => To_Unbounded_String (Files.IO.Errors.Directory_Load_Key), Signature => <>);
end Load_Subdirectories;
