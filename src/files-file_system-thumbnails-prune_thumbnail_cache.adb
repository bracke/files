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

   package Sorting is new Cached_File_Vectors.Generic_Sorting ("<" => Older);

   Cap         : constant Natural := Max_Entries;
   --  The oldest Cap thumbnails seen so far, as a binary max-heap on
   --  modification time: the newest of them at the root, the first to go
   --  when an older one is found. Sorted oldest first once the scan ends.
   Files_Found : Cached_File_Vectors.Vector;
   --  Every thumbnail's bytes, collected or not.
   Total       : Long_Long_Integer := 0;
   --  Thumbnails seen but not (or no longer) collected: newer than all kept.
   Uncollected : Natural := 0;
   Overflowed  : Boolean := False;

   procedure Swap (Left, Right : Positive) is
      Held : constant Cached_File := Files_Found (Left);
   begin
      Files_Found.Replace_Element (Left, Files_Found (Right));
      Files_Found.Replace_Element (Right, Held);
   end Swap;

   procedure Sift_Up (Start : Positive) is
      Index : Positive := Start;
   begin
      while Index > 1 and then Older (Files_Found (Index / 2), Files_Found (Index)) loop
         Swap (Index, Index / 2);
         Index := Index / 2;
      end loop;
   end Sift_Up;

   procedure Sift_Down is
      Last  : constant Natural := Natural (Files_Found.Length);
      Index : Positive := 1;
   begin
      loop
         declare
            Left    : constant Natural := 2 * Index;
            Largest : Positive := Index;
         begin
            if Left <= Last and then Older (Files_Found (Largest), Files_Found (Left)) then
               Largest := Left;
            end if;
            if Left + 1 <= Last and then Older (Files_Found (Largest), Files_Found (Left + 1)) then
               Largest := Left + 1;
            end if;
            exit when Largest = Index;
            Swap (Index, Largest);
            Index := Largest;
         end;
      end loop;
   end Sift_Down;

   procedure Note_Uncollected is
   begin
      if Uncollected < Natural'Last then
         Uncollected := Uncollected + 1;
      end if;
   end Note_Uncollected;

   procedure Collect (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean) is
      pragma Unreferenced (Stop);
      use type Hostkit.Fs.Entry_Kind;
   begin
      if Kind /= Hostkit.Fs.Ordinary_File_Entry or else not Is_Thumbnail_Name (Name) then
         return;
      end if;

      declare
         Full     : constant String := Hostkit.Fs.Join (Cache_Directory, Name);
         Size     : constant Long_Long_Integer := Long_Long_Integer (Files.Fs_Primitives.Size (Full));
         Modified : constant Ada.Calendar.Time := Files.Fs_Primitives.Modification_Time (Full);
      begin
         if Size < 0 or else Total > Long_Long_Integer'Last - Size then
            Overflowed := True;
            return;
         end if;
         Total := Total + Size;
         if Natural (Files_Found.Length) < Cap then
            Files_Found.Append
              (Cached_File'
                 (Path     => To_Unbounded_String (Full),
                  Identity => To_Unbounded_String (Files.File_Identities.Token (Full)),
                  Size     => Size,
                  Modified => Modified));
            Sift_Up (Natural (Files_Found.Length));
         elsif Modified < Files_Found (1).Modified then
            --  Older than the newest kept: it takes that one's place, which
            --  joins the uncollected.
            Files_Found.Replace_Element
              (1,
               Cached_File'
                 (Path     => To_Unbounded_String (Full),
                  Identity => To_Unbounded_String (Files.File_Identities.Token (Full)),
                  Size     => Size,
                  Modified => Modified));
            Sift_Down;
            Note_Uncollected;
         else
            Note_Uncollected;
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
      --  Past the cap the cache is too large to list (see
      --  List_Thumbnail_Cache): evict the overflow and a tenth of the cap
      --  more, oldest first, so a later listing takes all of it. The
      --  collected are the oldest, so none newer goes before them; when the
      --  overflow outnumbers them, the next pass continues from the next
      --  oldest. The byte budget counts every thumbnail, collected or not.
      Margin      : constant Natural := Natural'Max (1, Cap / 10);
      Must_Remove : constant Natural :=
        (if Uncollected = 0 then 0
         else Natural'Min (Natural (Files_Found.Length),
                           Natural'Min (Natural'Last - Margin, Uncollected) + Margin));
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
