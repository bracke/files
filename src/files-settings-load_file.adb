with Files.Capped_Files;
separate (Files.Settings)
   function Load_File
     (Path : String)
      return Settings_Parse_Result
   is
      use type Files.Capped_Files.Read_Status;

      --  This file is loaded during startup and can contain paths and commands,
      --  but a legitimate configuration remains far below this size.  Read in
      --  bounded chunks so a corrupt file (including one enormous physical
      --  line) cannot make Text_IO allocate an attacker-selected amount first.
      Status : Files.Capped_Files.Read_Status;
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

      declare
         Text : constant String :=
           Files.Capped_Files.Read_Capped
             (Path, Max_Settings_Text_Bytes, Files.Capped_Files.Follow_Links, Status);
      begin
         if Status /= Files.Capped_Files.Read_Complete then
            return
              (Success   => False,
               Settings  => Default_Settings,
               Error_Key => To_Unbounded_String ("error.settings.load"));
         end if;

         return Parse (Text);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
   end Load_File;
