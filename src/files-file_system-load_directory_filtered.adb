separate (Files.File_System)
function Load_Directory_Filtered
  (Path     : String;
   Settings : Files.Settings.Settings_Model;
   Options  : Files.Types.Listing_Options;
   Include  : access function
     (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
   Generate_Thumbnails : Boolean := False;
   With_Signature      : Boolean := False)
   return Directory_Load_Result
is
   Items : Item_Vectors.Vector;
   Normalized_Path : Unbounded_String;
   --  Signing: Path's own entries are being read (not a volume trash's).
   Signature : Directory_Signature;
   Signing   : Boolean := False;
   Signed    : Boolean := True;
   Cached : Cache_Index :=
     Index_Thumbnail_Cache (Default_Thumbnail_Cache_Directory (Path));

   procedure Add_Entry (Name : String) is
      Full : constant String := Join_Path (To_String (Normalized_Path), Name);
      --  Whether the entry passed the hidden and Include filters before
      --  anything failed; the handler lists only an entry the caller wants.
      Admitted : Boolean := False;
   begin
      if Signing then
         begin
            Add_To_Signature (Signature, Name);
         exception
            when Swallowed : others =>
               --  As Directory_State: a partial signature is no signature.
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Directory");
               Signed := False;
         end;
      end if;
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
                 (Directory_Item'(Name           => To_Unbounded_String (Name),
                                  Full_Path      => To_Unbounded_String (Full),
                                  Parent_Path    => Normalized_Path,
                                  Hidden         => Name (Name'First) = '.',
                                  Filetype       => To_Unbounded_String ("application/octet-stream"),
                                  Icon_Id        => To_Unbounded_String ("unknown"),
                                  Metadata_Error => True,
                                  Error_Key      => To_Unbounded_String ("error.metadata.read"),
                                  others         => <>));
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
              Items => Items, Error_Key => To_Unbounded_String ("error.directory.load"), Signature => <>);
   end if;
   Cached.Generate := Generate_Thumbnails;
   Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
   Signature := (Path => Normalized_Path, Exists => True, others => <>);
   Signing := With_Signature;
   Support.For_Each_Entry (Path, Add_Entry'Access);
   Signing := False;
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
           Items => Items, Error_Key => Null_Unbounded_String,
           Signature =>
             (if With_Signature and then Signed then Signature
              else Directory_Signature'(Path => Normalized_Path, others => <>)));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return (Success => False, Path => To_Unbounded_String (Path),
              Items => Items, Error_Key => To_Unbounded_String ("error.directory.load"), Signature => <>);
end Load_Directory_Filtered;
