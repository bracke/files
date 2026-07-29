separate (Files.Settings)
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
   is
      File   : Ada.Text_IO.File_Type;
      Parent : constant String := Parent_Directory (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      if Parent /= "" then
         if Ada.Directories.Exists (Parent) then
            if Ada.Directories.Kind (Parent) /= Ada.Directories.Directory then
               return
                 (Success   => False,
                  Path      => To_Unbounded_String (Path),
                  Error_Key => To_Unbounded_String ("error.settings.not_file"));
            end if;
         else
            Ada.Directories.Create_Path (Parent);
         end if;
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
      return
        (Success   => True,
         Path      => To_Unbounded_String (Path),
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);

         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Save_Text;
