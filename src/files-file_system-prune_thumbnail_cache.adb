separate (Files.File_System)
procedure Prune_Thumbnail_Cache
  (Cache_Directory : String;
   Budget_Bytes    : Long_Long_Integer)
is
   type Cached_File is record
      Path     : Unbounded_String;
      Identity : Unbounded_String;
      Size     : Long_Long_Integer := 0;
      Modified : Ada.Calendar.Time;
   end record;

   package Cached_File_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Cached_File);

   function Older (Left : Cached_File; Right : Cached_File) return Boolean is
     (Left.Modified < Right.Modified);

   function Is_Thumbnail_Name (Name : String) return Boolean is
      Prefix : constant String := "thumb_";
      Suffix : constant String := ".ppm";
      Digest_First : constant Integer := Name'Last - Suffix'Length - 63;
   begin
      return Name'Length >= Prefix'Length + 1 + 1 + 64 + Suffix'Length
        and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
        and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
        and then Name (Digest_First - 1) = '_'
        and then (for all Index in Digest_First .. Digest_First + 63 =>
          Name (Index) in '0' .. '9' | 'a' .. 'f');
   exception
      when others =>
         return False;
   end Is_Thumbnail_Name;

   package Sorting is new Cached_File_Vectors.Generic_Sorting ("<" => Older);

   Files_Found : Cached_File_Vectors.Vector;
   Total       : Long_Long_Integer := 0;
   Search      : Ada.Directories.Search_Type;
   Item        : Ada.Directories.Directory_Entry_Type;
   Started     : Boolean := False;
   Count       : Natural := 0;
   Overflowed  : Boolean := False;
begin
   --  A cache path may have been replaced with a directory symlink since it
   --  was configured.  Pruning is destructive, so never follow that link
   --  and evict ordinary files from an unrelated target directory.
   if Hostkit.Fs.Is_Link (Cache_Directory)
     or else not Files.Fs.Directory_Exists (Cache_Directory)
   then
      return;
   end if;

   Ada.Directories.Start_Search
     (Search, Cache_Directory, "*",
      Filter => [Ada.Directories.Ordinary_File => True, others => False]);
   Started := True;

   while Ada.Directories.More_Entries (Search) loop
      Ada.Directories.Get_Next_Entry (Search, Item);

      if not Is_Thumbnail_Name (Ada.Directories.Simple_Name (Item)) then
         goto Continue;
      elsif Count = Max_Cache_Prune_Entries then
         Ada.Directories.End_Search (Search);
         Started := False;
         return;
      end if;
      Count := Count + 1;

      begin
         declare
            Full : constant String := Ada.Directories.Full_Name (Item);
            Size : constant Long_Long_Integer :=
              Long_Long_Integer (Ada.Directories.Size (Item));
         begin
            if Size < 0 or else Total > Long_Long_Integer'Last - Size then
               Overflowed := True;
            else
               Files_Found.Append
                 (Cached_File'
                    (Path     => To_Unbounded_String (Full),
                     Identity => To_Unbounded_String
                       (Files.File_Identities.Token (Full)),
                     Size     => Size,
                     Modified => Ada.Directories.Modification_Time (Item)));
               Total := Total + Size;
            end if;
         end;
      exception
         --  A file that vanished mid-scan, or whose size the host will not
         --  report, simply is not counted. Pruning is housekeeping: it must
         --  never be the reason a thumbnail fails to be written.
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      end;
      <<Continue>>
   end loop;

   Ada.Directories.End_Search (Search);
   Started := False;

   if Overflowed or else Total <= Budget_Bytes then
      return;
   end if;

   Sorting.Sort (Files_Found);

   for Candidate of Files_Found loop
      exit when Total <= Budget_Bytes;

      begin
         --  The cache directory is private and owned by this app, so an
         --  identity-checked unlink is enough. The full recoverable-delete
         --  protocol cost a stage directory, sidecars and about eight fsyncs
         --  per evicted thumbnail, all on the directory-listing path.
         if Length (Candidate.Identity) > 0
           and then not Hostkit.Fs.Is_Link (To_String (Candidate.Path))
           and then Files.File_Identities.Token (To_String (Candidate.Path)) =
             To_String (Candidate.Identity)
         then
            Ada.Directories.Delete_File (To_String (Candidate.Path));
            Total := Total - Candidate.Size;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      end;
   end loop;
exception
   when others =>
      if Started then
         begin
            Ada.Directories.End_Search (Search);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         end;
      end if;
      null;
end Prune_Thumbnail_Cache;
