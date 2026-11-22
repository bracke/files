with Files.Text_Basics;
separate (Files.File_System)
function Directory_Size
  (Path        : String;
   Max_Entries : Natural := 50_000;
   Max_Depth   : Natural := 64)
   return Directory_Size_Result
is
   Result  : Directory_Size_Result;
   Visited : Natural := 0;

   function Is_Symlink (Candidate : String) return Boolean is
   begin
      return Hostkit.Fs.Is_Link (Candidate);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         --  Link classification is a safety boundary: an unknown entry must
         --  be skipped, never treated as a directory that is safe to enter.
         return True;
   end Is_Symlink;

   function Walk (Directory : String; Depth : Natural) return Boolean is

      procedure Visit (Name : String) is
         Full : constant String := Hostkit.Fs.Join (Directory, Name);
      begin
         if Result.Capped then
            return;
         end if;
         Visited := Visited + 1;
         if Visited > Max_Entries then
            Result.Capped := True;
            return;
         end if;

         --  Every entry counts, a dangling link included: the folder lists it.
         Result.Item_Count := Result.Item_Count + 1;

         if Is_Symlink (Full) then
            null;
         elsif Files.IO.Fs_Primitives.Kind (Full) = Ada.Directories.Directory then
            declare
               Descended : constant Boolean := Walk (Full, Depth + 1);
               pragma Unreferenced (Descended);
            begin
               null;
            end;
         elsif Files.IO.Fs_Primitives.Kind (Full) = Ada.Directories.Ordinary_File then
            Result.File_Count := Result.File_Count + 1;
            Result.Total_Bytes :=
              Files.Text_Basics.Saturating_Add
                (Result.Total_Bytes, Long_Long_Integer (Files.IO.Fs_Primitives.Size (Full)));
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
            --  Skip individual entries that cannot be classified or sized
            --  (races, permission denials) without aborting the walk.
            null;
      end Visit;
   begin
      if Depth > Max_Depth then
         Result.Capped := True;
         return True;
      end if;

      --  Ada.Directories' search drops a dangling link; this enumeration
      --  neither follows nor drops links.
      Support.For_Each_Entry (Directory, Visit'Access);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         --  An unreadable subdirectory is skipped rather than failing the
         --  whole measurement.  The caller distinguishes that case from an
         --  unreadable root, whose result must remain unavailable.
         return False;
   end Walk;
begin
   --  refusal-safe: a root not seen measures nothing; the result stays
   --  unavailable (Available False), never a size of 0.
   if Path = ""
     --  refusal-safe: as above.
     or else not Files.IO.Fs_Primitives.Exists (Path)
     or else Hostkit.Fs.Is_Link (Path)
     or else Files.IO.Fs_Primitives.Kind (Path) /= Ada.Directories.Directory
   then
      return Result;
   end if;

   if not Walk (Path, 0) then
      return (others => <>);
   end if;
   Result.Available := True;
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Result;
end Directory_Size;
