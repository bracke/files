separate (Files.File_System)
   function Parent_Directory (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      declare
         --  Containing_Directory resolves the parent cross-platform, trimming
         --  the final path component and handling trailing separators. It
         --  raises Use_Error at a filesystem root, where no parent exists.
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent = "" or else Parent = Path then
            return "";
         end if;

         return Parent;
      end;
   exception
      when others =>
         return "";
   end Parent_Directory;
