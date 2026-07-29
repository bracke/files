separate (Files.Settings)
   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result
   is
   begin
      if Path = "" then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif Ada.Directories.Exists (Path) then
         if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
            return
              (Success   => True,
               Path      => To_Unbounded_String (Path),
               Error_Key => Null_Unbounded_String);
         else
            return
              (Success   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => To_Unbounded_String ("error.settings.not_file"));
         end if;
      end if;

      return Save_Text (Path, Default_Settings_Text);
   exception
      when others =>
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Ensure_Default_File;
