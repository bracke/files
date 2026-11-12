separate (Files.File_System.Thumbnails)
procedure Prune_Thumbnail_Cache
  (Cache_Directory : String;
   Budget_Bytes    : Long_Long_Integer;
   Max_Entries     : Positive := Max_Cache_Prune_Entries)
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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         return False;
   end Is_Thumbnail_Name;

   package Sorting is new Cached_File_Vectors.Generic_Sorting ("<" => Older);

   Cap         : constant Natural := Max_Entries;
   Files_Found : Cached_File_Vectors.Vector;
   Total       : Long_Long_Integer := 0;
   Count       : Natural := 0;
   --  Thumbnails past the cap: counted by name only, never collected.
   Uncollected : Natural := 0;
   Overflowed  : Boolean := False;

   procedure Collect (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean) is
      pragma Unreferenced (Stop);
      use type Hostkit.Fs.Entry_Kind;
   begin
      if Kind /= Hostkit.Fs.Ordinary_File_Entry or else not Is_Thumbnail_Name (Name) then
         return;
      elsif Count >= Cap then
         if Uncollected < Natural'Last then
            Uncollected := Uncollected + 1;
         end if;
         return;
      end if;
      Count := Count + 1;

      declare
         Full : constant String := Hostkit.Fs.Join (Cache_Directory, Name);
         Size : constant Long_Long_Integer := Long_Long_Integer (Files.Fs_Primitives.Size (Full));
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
                  Modified => Files.Fs_Primitives.Modification_Time (Full)));
            Total := Total + Size;
         end if;
      end;
   exception
      --  A file that vanished mid-scan, or whose size the host will not
      --  report, simply is not counted. Pruning is housekeeping: it must
      --  never be the reason a thumbnail fails to be written.
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
   end Collect;
begin
   --  A cache path may have been replaced with a directory symlink since it
   --  was configured.  Pruning is destructive, so never follow that link
   --  and evict ordinary files from an unrelated target directory.
   if Hostkit.Fs.Is_Link (Cache_Directory)
     or else not Files.Fs_Primitives.Directory_Exists (Cache_Directory)
   then
      return;
   end if;

   Files.Fs_Primitives.For_Each_Listed (Cache_Directory, Collect'Access);
   if Overflowed or else (Uncollected = 0 and then Total <= Budget_Bytes) then
      return;
   end if;

   Sorting.Sort (Files_Found);

   declare
      --  Past the cap, the uncollected thumbnails' sizes are unknown, so the
      --  budget cannot be judged: evict the oldest collected until what was
      --  collected is within it and enough are gone (the overflow and a
      --  tenth of the cap more) that the next pass collects them all.
      Must_Remove : constant Natural :=
        (if Uncollected = 0 then 0
         else Natural'Min (Natural (Files_Found.Length),
                           Natural'Min (Natural'Last - Natural'Max (1, Cap / 10), Uncollected)
                           + Natural'Max (1, Cap / 10)));
      Removed     : Natural := 0;
   begin
      for Candidate of Files_Found loop
         exit when Total <= Budget_Bytes and then Removed >= Must_Remove;

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
               Files.Fs_Primitives.Delete_File (To_String (Candidate.Path));
               Total := Total - Candidate.Size;
               Removed := Removed + 1;
            end if;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         end;
      end loop;
   end;
exception
   when Failure : others =>
      Files.Diagnostics.Note (Failure, "Files.File_System.Thumbnails");
end Prune_Thumbnail_Cache;
