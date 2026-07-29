separate (Files.File_System)
   function Normalize_Path
     (Path : String)
      return Path_Result
   is
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return
           (Status         => Path_Missing,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.missing"));
      end if;

      case Ada.Directories.Kind (Path) is
         when Ada.Directories.Directory =>
            return
              (Status         => Path_Valid,
               Directory_Path => To_Unbounded_String (Ada.Directories.Full_Name (Path)),
               Error_Key      => Null_Unbounded_String);
         when Ada.Directories.Ordinary_File =>
            return
              (Status         => Path_Valid,
               Directory_Path =>
                 To_Unbounded_String (Ada.Directories.Containing_Directory (Ada.Directories.Full_Name (Path))),
               Error_Key      => Null_Unbounded_String);
         when Ada.Directories.Special_File =>
            return
              (Status         => Path_Inaccessible,
               Directory_Path => Null_Unbounded_String,
               Error_Key      => To_Unbounded_String ("error.path.inaccessible"));
      end case;
   exception
      when others =>
         return
           (Status         => Path_Inaccessible,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.inaccessible"));
   end Normalize_Path;
