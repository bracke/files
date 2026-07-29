separate (Files.File_System)
   function Directory_State
     (Path : String)
      return Directory_Signature
   is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
      Result    : Directory_Signature :=
        (Path                  => To_Unbounded_String (Path),
         Exists                => False,
         Entry_Count           => 0,
         Entry_State_Checksum  => 0,
         Latest_Modified       => Ada.Calendar.Time_Of (1901, 1, 1),
         Latest_Modified_Known => False);

      function Entry_Checksum
        (Name : String;
         Kind : Ada.Directories.File_Kind;
         Size : Long_Long_Integer)
         return Natural
      is
         Modulus : constant Long_Long_Integer := 1_000_000_007;
         Value   : Long_Long_Integer := Long_Long_Integer (Ada.Directories.File_Kind'Pos (Kind) + 1);
      begin
         for Character_Value of Name loop
            Value :=
              (Value * 131 + Long_Long_Integer (Character'Pos (Character_Value))) mod Modulus;
         end loop;

         Value := (Value * 131 + Long_Long_Integer'Max (0, Size)) mod Modulus;
         return Natural (Value);
      end Entry_Checksum;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return Result;
      end if;

      Result.Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
      Result.Exists := True;
      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Result.Entry_Count := Result.Entry_Count + 1;
               declare
                  Full     : constant String := Ada.Directories.Full_Name (Dir_Entry);
                  Kind     : Ada.Directories.File_Kind := Ada.Directories.Special_File;
                  Size     : Long_Long_Integer := 0;
                  Modified : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
               begin
                  begin
                     Kind := Ada.Directories.Kind (Dir_Entry);
                  exception
                     when others =>
                        null;
                  end;

                  if Kind = Ada.Directories.Ordinary_File then
                     begin
                        Size := Long_Long_Integer (Ada.Directories.Size (Full));
                     exception
                        when others =>
                           Size := 0;
                     end;
                  end if;

                  Result.Entry_State_Checksum :=
                    (Result.Entry_State_Checksum + Entry_Checksum (Name, Kind, Size)) mod 1_000_000_007;

                  begin
                     Modified := Ada.Directories.Modification_Time (Full);
                     if not Result.Latest_Modified_Known
                       or else Modified > Result.Latest_Modified
                     then
                        Result.Latest_Modified := Modified;
                        Result.Latest_Modified_Known := True;
                     end if;
                  exception
                     when others =>
                        null;
                  end;
               exception
                  when others =>
                     Result.Entry_State_Checksum :=
                       (Result.Entry_State_Checksum
                        + Entry_Checksum (Name, Ada.Directories.Special_File, 0)) mod 1_000_000_007;
               end;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
      return Result;
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return Result;
   end Directory_State;
