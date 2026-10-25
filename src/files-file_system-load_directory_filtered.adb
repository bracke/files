separate (Files.File_System)
function Load_Directory_Filtered
  (Path     : String;
   Settings : Files.Settings.Settings_Model;
   Options  : Files.Types.Listing_Options;
   Include  : access function
     (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
   Generate_Thumbnails : Boolean := False)
   return Directory_Load_Result
is
   Items : Item_Vectors.Vector;
   Normalized_Path : Unbounded_String;
   Cached : Cache_Index :=
     Index_Thumbnail_Cache (Default_Thumbnail_Cache_Directory (Path));

   procedure Add_Entry (Name : String) is
      Full : constant String := Join_Path (To_String (Normalized_Path), Name);
      --  Whether the entry passed the hidden and Include filters before
      --  anything failed; the handler lists only an entry the caller wants.
      Admitted : Boolean := False;
   begin
      declare
         --  Inside the handled body, so a failing hidden-attribute query is
         --  caught below like any other per-entry failure.
         Hidden : constant Boolean := Name (Name'First) = '.' or else Hostkit.Fs.Is_Hidden (Full);
      begin
         if Options.Show_Hidden or else not Hidden then
            declare
               Kind : constant Files.Types.Item_Kind := Kind_From_Path (Full);
            begin
               if Include = null or else Include (Name, Kind) then
                  Admitted := True;
                  declare
                     Item : Directory_Item :=
                       Item_For_Path (Full, Name, To_String (Normalized_Path), Kind, Settings, Cached);
                  begin
                     Item.Hidden := Hidden;
                     Items.Append (Item);
                  end;
               end if;
            end;
         end if;
      end;
   exception
      when Failure : others =>
         --  A failure for one entry must not hide it, nor the folder: list the
         --  entry by name as an unknown item flagged with the same metadata
         --  error Item_For_Path records, so the user still sees it is there.
         --  One that failed before the filters ran is listed only by a plain
         --  listing, and only if its name does not mark it hidden.
         Files.Diagnostics.Note (Failure, "Files.File_System.Directory");
         begin
            if not Admitted then
               Admitted := Include = null
                 and then (Options.Show_Hidden or else Name (Name'First) /= '.');
            end if;
            if Admitted then
               Items.Append
                 (Directory_Item'(Name => To_Unbounded_String (Name),
                   Full_Path          => To_Unbounded_String (Full),
                   Parent_Path        => Normalized_Path,
                   Hidden             => Name (Name'First) = '.',
                   Kind               => Files.Types.Unknown_Item,
                   Filetype           => To_Unbounded_String ("application/octet-stream"),
                   Icon_Id            => To_Unbounded_String ("unknown"),
                   Size_Available     => False,
                   Size               => 0,
                   Creation_Available => False,
                   Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                   Modified_Available => False,
                   Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                   Permissions        => Null_Unbounded_String,
                   Mode_Available     => False,
                   Mode_Bits          => 0,
                   Ownership_Available => False,
                   Owner_Id           => 0,
                   Group_Id           => 0,
                   Filetype_Extra     => Null_Unbounded_String,
                   Filetype_Extra_Loaded => False,
                   Thumbnail_Available => False,
                   Thumbnail_Path      => Null_Unbounded_String,
                   Thumbnail_Width     => 0,
                   Thumbnail_Height    => 0,
                   Thumbnail_Pixels    => Files.Shared_Bytes.Empty,
                   Metadata_Error     => True,
                   Error_Key          => To_Unbounded_String ("error.metadata.read")));
            end if;
         exception
            when Fallback_Failure : others =>
               --  Out of memory or the like: the entry is lost, the folder is not.
               Files.Diagnostics.Note (Fallback_Failure, "Files.File_System.Directory");
         end;
   end Add_Entry;
begin
   if not Files.Fs_Primitives.Directory_Exists (Path) then
      return (Success => False, Path => To_Unbounded_String (Path),
              Items => Items, Error_Key => To_Unbounded_String ("error.directory.load"));
   end if;
   Cached.Generate := Generate_Thumbnails;
   Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
   Support.For_Each_Entry (Path, Add_Entry'Access);
   --  The trash view is the home trash and every volume's trash together:
   --  an item trashed on a USB stick stays there, and is listed here.
   if Is_Trash_Files_Directory (Path) then
      for Base of Volume_Trash_Bases loop
         declare
            Volume_Files : constant String := Join_Path (To_String (Base), "files");
         begin
            Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Volume_Files));
            Support.For_Each_Entry (Volume_Files, Add_Entry'Access);
         exception
            when Swallowed : others =>
               --  An unreadable volume trash hides its items, not the trash.
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Trash");
         end;
      end loop;
      Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
   end if;
   Sort_Items (Items, Options.Sort_Field, Options.Sort_Ascending);
   return (Success => True, Path => Normalized_Path,
           Items => Items, Error_Key => Null_Unbounded_String);
exception
   when others =>
      return (Success => False, Path => To_Unbounded_String (Path),
              Items => Items, Error_Key => To_Unbounded_String ("error.directory.load"));
end Load_Directory_Filtered;
