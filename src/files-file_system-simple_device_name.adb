separate (Files.File_System)
   function Simple_Device_Name (Source : String) return String is
      Start : Natural := Source'First;
   begin
      for Index in reverse Source'Range loop
         if Source (Index) = '/' then
            Start := Index + 1;
            exit;
         end if;
      end loop;

      if Start > Source'Last then
         return "";
      end if;

      return Source (Start .. Source'Last);
   end Simple_Device_Name;
