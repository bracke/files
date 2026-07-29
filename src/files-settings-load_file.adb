separate (Files.Settings)
   function Load_File
     (Path : String)
      return Settings_Parse_Result
   is
      File : Ada.Text_IO.File_Type;
      Text : Unbounded_String := Null_Unbounded_String;
   begin
      if Path = "" then
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

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Append (Text, Ada.Text_IO.Get_Line (File));
         Append (Text, ASCII.LF);
      end loop;
      Safe_Close (File);

      return Parse (To_String (Text));
   exception
      when others =>
         Safe_Close (File);

         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
   end Load_File;
