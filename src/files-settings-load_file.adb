with Files.Diagnostics;
separate (Files.Settings)
   function Load_File
     (Path : String)
      return Settings_Parse_Result
   is
      use type Ada.Streams.Stream_Element_Offset;
      use type GNAT.OS_Lib.File_Descriptor;

      --  This file is loaded during startup and can contain paths and commands,
      --  but a legitimate configuration remains far below this size.  Read in
      --  bounded chunks so a corrupt file (including one enormous physical
      --  line) cannot make Text_IO allocate an attacker-selected amount first.
      File       : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);
      Bytes_Read : Integer;
      Text       : Unbounded_String := Null_Unbounded_String;
      Total      : Natural := 0;

      procedure Close_File is
      begin
         if File /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (File);
            File := GNAT.OS_Lib.Invalid_FD;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Settings.Load_File");
      end Close_File;
   begin
      if Path = "" or else Contains_Nul (Path) then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
      elsif not Ada.Directories.Exists (Path) then
         return
           (Success   => True,
            Settings  => Default_Settings,
            Error_Key => Null_Unbounded_String);
      elsif Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      File := Files.Fs.Open_Regular_Read_Following_Links (Path);
      if File = GNAT.OS_Lib.Invalid_FD then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
      end if;

      loop
         Bytes_Read := GNAT.OS_Lib.Read
           (File, Buffer'Address, Integer (Buffer'Length));
         if Bytes_Read < 0 then
            raise Ada.Directories.Use_Error;
         end if;
         exit when Bytes_Read = 0;

         declare
            Chunk_Length : constant Natural :=
              Natural (Bytes_Read);
            Chunk : String (1 .. Chunk_Length);
         begin
            if Chunk_Length > Max_Settings_Text_Bytes - Total then
               Close_File;
               return
                 (Success   => False,
                  Settings  => Default_Settings,
                  Error_Key => To_Unbounded_String ("error.settings.load"));
            end if;

            for Index in Chunk'Range loop
               Chunk (Index) :=
                 Character'Val
                   (Buffer
                      (Ada.Streams.Stream_Element_Offset (Index)
                       + Buffer'First - 1));
            end loop;

            Append (Text, Chunk);
            Total := Total + Chunk_Length;
         end;
      end loop;
      Close_File;

      return Parse (To_String (Text));
   exception
      when others =>
         Close_File;

         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
   end Load_File;
