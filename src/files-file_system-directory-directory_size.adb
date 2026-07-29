separate (Files.File_System.Directory)
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
         return Files.Platform.Metadata.Symlink_Target_Token (Candidate) /= "";
      exception
         when others =>
            return False;
      end Is_Symlink;

      procedure Walk (Directory : String; Depth : Natural) is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
      begin
         if Depth > Max_Depth then
            Result.Capped := True;
            return;
         end if;

         Ada.Directories.Start_Search
           (Search    => Search,
            Directory => Directory,
            Pattern   => "",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => True]);

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Item);
               Full : constant String := Ada.Directories.Full_Name (Item);
            begin
               if Name /= "." and then Name /= ".." then
                  Visited := Visited + 1;
                  if Visited > Max_Entries then
                     Result.Capped := True;
                     Ada.Directories.End_Search (Search);
                     return;
                  end if;

                  Result.Item_Count := Result.Item_Count + 1;

                  if Is_Symlink (Full) then
                     null;
                  elsif Ada.Directories.Kind (Item) = Ada.Directories.Directory then
                     Walk (Full, Depth + 1);
                     exit when Result.Capped;
                  elsif Ada.Directories.Kind (Item) = Ada.Directories.Ordinary_File then
                     Result.File_Count := Result.File_Count + 1;
                     Result.Total_Bytes :=
                       Saturating_Long_Add
                         (Result.Total_Bytes,
                          Long_Long_Integer (Ada.Directories.Size (Item)));
                  end if;
               end if;
            exception
               when others =>
                  --  Skip individual entries that cannot be classified or sized
                  --  (races, permission denials) without aborting the walk.
                  null;
            end;
         end loop;

         Ada.Directories.End_Search (Search);
      exception
         when others =>
            --  An unreadable subdirectory is skipped rather than failing the
            --  whole measurement.
            null;
      end Walk;
   begin
      if Path = ""
        or else not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory
      then
         return Result;
      end if;

      Walk (Path, 0);
      Result.Available := True;
      return Result;
   exception
      when others =>
         return Result;
   end Directory_Size;
