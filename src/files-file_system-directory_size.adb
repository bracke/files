separate (Files.File_System)
function Directory_Size
  (Path        : String;
   Max_Entries : Natural := 50_000;
   Max_Depth   : Natural := 64)
   return Directory_Size_Result
is
   Result  : Directory_Size_Result;
   Visited : Natural := 0;

   function Saturating_Long_Add
     (Left  : Long_Long_Integer;
      Right : Long_Long_Integer)
      return Long_Long_Integer is
   begin
      if Right > 0 and then Left > Long_Long_Integer'Last - Right then
         return Long_Long_Integer'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Long_Add;

   function Is_Symlink (Candidate : String) return Boolean is
   begin
      return Hostkit.Fs.Is_Link (Candidate);
   exception
      when others =>
         --  Link classification is a safety boundary: an unknown entry must
         --  be skipped, never treated as a directory that is safe to enter.
         return True;
   end Is_Symlink;

   function Walk (Directory : String; Depth : Natural) return Boolean is

      procedure Visit (Name : String) is
         Full : constant String := Join_Path (Directory, Name);
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
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Directory then
            declare
               Descended : constant Boolean := Walk (Full, Depth + 1);
               pragma Unreferenced (Descended);
            begin
               null;
            end;
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Ordinary_File then
            Result.File_Count := Result.File_Count + 1;
            Result.Total_Bytes :=
              Saturating_Long_Add (Result.Total_Bytes, Long_Long_Integer (Ada.Directories.Size (Full)));
         end if;
      exception
         when others =>
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
      when others =>
         --  An unreadable subdirectory is skipped rather than failing the
         --  whole measurement.  The caller distinguishes that case from an
         --  unreadable root, whose result must remain unavailable.
         return False;
   end Walk;
begin
   if Path = ""
     or else not Ada.Directories.Exists (Path)
     or else Hostkit.Fs.Is_Link (Path)
     or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory
   then
      return Result;
   end if;

   if not Walk (Path, 0) then
      return (others => <>);
   end if;
   Result.Available := True;
   return Result;
exception
   when others =>
      return Result;
end Directory_Size;
