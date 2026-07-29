separate (Files.File_System)
   function Delete_Permanently
     (Path : String)
      return Mutation_Result
   is
      function Unsafe_Target return Boolean is
      begin
         if Path = ""
           or else Path = "/"
           or else (Path'Length = 3 and then Path (Path'First + 1 .. Path'First + 2) = ":\")
         then
            return True;
         end if;

         declare
            Full   : constant String := Ada.Directories.Full_Name (Path);
            Parent : constant String := Ada.Directories.Containing_Directory (Full);
         begin
            return Full = ""
              or else Full = Parent
              or else (Full'Length = 1 and then Full (Full'First) = '/');
         end;
      exception
         when others =>
            return True;
      end Unsafe_Target;
   begin
      if Unsafe_Target then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permanent_delete.refused"));
      elsif not Ada.Directories.Exists (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.source_missing"));
      end if;

      --  Files.Fs.Delete_Tree removes a directory tree; a single
      --  file must go through Delete_File.
      if Files.Fs.Directory_Exists (Path) then
         Files.Fs.Delete_Tree (Path);
      else
         Ada.Directories.Delete_File (Path);
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permanent_delete.failed"));
   end Delete_Permanently;
