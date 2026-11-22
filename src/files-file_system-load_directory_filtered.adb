with Files.Name_Parts;

separate (Files.File_System)
function Load_Directory_Filtered
  (Path     : String;
   Classes  : Files.File_Types.Classification;
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

   --  The Windows Recycle Bin: its folder holds $R items beside $I records,
   --  so the view lists the records' items under their original names
   --  instead of the folder's own entries (which are still what is signed).
   Recycle_Bin : constant Boolean :=
     Trash.Trash_Backend_Of_Current_Environment = Trash_Windows_Recycle_Bin
     and then Trash.Is_Trash_Files_Directory (Path);

   --  A freedesktop trash's files/ (the home trash's, with every volume's
   --  added below): its payloads are named for the trash ("notes.txt.2",
   --  a long name cut), so the view lists each under the name it had, as
   --  its .trashinfo records it, and its type and icon follow that name.
   --  Everything done to it still addresses the payload's own path.
   Trash_View : constant Boolean := not Recycle_Bin and then Trash.Is_Trash_Files_Directory (Path);

   --  List the entry at Full under Name, Normalized_Path being its folder.
   procedure Add_Named (Name : String; Full : String);

   --  The name a trash payload at Full had, or Name when its record does
   --  not say (the macOS home trash keeps none).
   function Shown_Name (Name : String; Full : String) return String is
      Original : constant String := Trash.Trash_Original_Path (Full);
      Leaf     : constant String := (if Original = "" then "" else Files.Name_Parts.Leaf_Of (Original));
   begin
      return (if Leaf = "" then Name else Leaf);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return Name;
   end Shown_Name;

   procedure Add_Entry (Name : String) is
   begin
      if Signing then
         begin
            Add_To_Signature (Signature, Name);
         exception
            when Swallowed : others =>
               --  As Directory_State: a partial signature is no signature.
               Files.Diagnostics.Note (Swallowed, "Files.File_System");
               Signed := False;
         end;
      end if;
      if not Recycle_Bin then
         declare
            Full : constant String := Hostkit.Fs.Join (To_String (Normalized_Path), Name);
         begin
            Add_Named ((if Trash_View then Shown_Name (Name, Full) else Name), Full);
         end;
      end if;
   end Add_Entry;

   procedure Add_Named (Name : String; Full : String) is
      --  Whether the entry passed the hidden and Include filters before
      --  anything failed; the handler lists only an entry the caller wants.
      Admitted : Boolean := False;
   begin
      declare
         Hidden : constant Boolean := Entry_Is_Hidden (Name, Full);
      begin
         if Options.Show_Hidden or else not Hidden then
            declare
               Kind : constant Files.Types.Item_Kind := Kind_From_Path (Full);
            begin
               if Include = null or else Include (Name, Kind) then
                  Admitted := True;
                  declare
                     Item : constant Directory_Item :=
                       Item_For_Path (Full, Name, To_String (Normalized_Path), Kind, Classes, Cached, Hidden);
                  begin
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
         --  listing, and only if it is not hidden.
         Files.Diagnostics.Note (Failure, "Files.File_System");
         begin
            if not Admitted then
               Admitted := Include = null
                 and then (Options.Show_Hidden or else not Entry_Is_Hidden (Name, Full));
            end if;
            if Admitted then
               Items.Append
                 (Directory_Item'(Name           => To_Unbounded_String (Name),
                                  Full_Path      => To_Unbounded_String (Full),
                                  Parent_Path    => Normalized_Path,
                                  Hidden         => Entry_Is_Hidden (Name, Full),
                                  Filetype       => To_Unbounded_String ("application/octet-stream"),
                                  Icon_Id        => To_Unbounded_String ("unknown"),
                                  Metadata_Error => True,
                                  Error_Key      => To_Unbounded_String ("error.metadata.read"),
                                  others         => <>));
            end if;
         exception
            when Fallback_Failure : others =>
               --  Out of memory or the like: the entry is lost, the folder is not.
               Files.Diagnostics.Note (Fallback_Failure, "Files.File_System");
         end;
   end Add_Named;
begin
   if not Files.IO.Fs_Primitives.Directory_Exists (Path) then
      return (Success => False, Path => To_Unbounded_String (Path),
              Items => Items, Error_Key => To_Unbounded_String (Files.IO.Errors.Directory_Load_Key), Signature => <>);
   end if;
   Cached.Generate := Generate_Thumbnails;
   Normalized_Path := To_Unbounded_String (Files.IO.Fs_Primitives.Full_Name (Path));
   Signature := (Path => Normalized_Path, Taken => True, Exists => True, others => <>);
   Signing := With_Signature;
   Support.For_Each_Entry (Path, Add_Entry'Access);
   Signing := False;
   --  Every fixed drive's Recycle Bin is one trash view, as in Explorer:
   --  each item under the name it had, its $R path its own.
   if Recycle_Bin then
      for Recycled of Hostkit.Trash.Recycle_Bin_Entries loop
         declare
            Item_Path : constant String := To_String (Recycled.Recycled_Path);
         begin
            Normalized_Path := To_Unbounded_String (Files.IO.Fs_Primitives.Parent_Directory (Item_Path));
            Add_Named (Files.Name_Parts.Leaf_Of (To_String (Recycled.Original_Path)), Item_Path);
         exception
            when Swallowed : others =>
               --  One unreadable record hides its item, not the bin.
               Files.Diagnostics.Note (Swallowed, "Files.File_System");
         end;
      end loop;
      Normalized_Path := To_Unbounded_String (Files.IO.Fs_Primitives.Full_Name (Path));
   --  The trash view is the home trash and every volume's trash together:
   --  an item trashed on a USB stick stays there, and is listed here.
   elsif Trash.Is_Trash_Files_Directory (Path) then
      for Items_Directory of Trash.Volume_Trash_Item_Directories loop
         declare
            Volume_Files : constant String := To_String (Items_Directory);
         begin
            Normalized_Path := To_Unbounded_String (Files.IO.Fs_Primitives.Full_Name (Volume_Files));
            Support.For_Each_Entry (Volume_Files, Add_Entry'Access);
         exception
            when Swallowed : others =>
               --  An unreadable volume trash hides its items, not the trash.
               Files.Diagnostics.Note (Swallowed, "Files.File_System");
         end;
      end loop;
      Normalized_Path := To_Unbounded_String (Files.IO.Fs_Primitives.Full_Name (Path));
   end if;
   Files.Item_Lists.Sort_Items (Items, Options.Sort_Field, Options.Sort_Ascending);
   return (Success => True, Path => Normalized_Path,
           Items => Items, Error_Key => Null_Unbounded_String,
           Signature =>
             (if With_Signature and then Signed then Signature
              else Unknown_Signature (To_String (Normalized_Path))));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return (Success => False, Path => To_Unbounded_String (Path),
              Items => Items, Error_Key => To_Unbounded_String (Files.IO.Errors.Directory_Load_Key), Signature => <>);
end Load_Directory_Filtered;
