separate (Files.File_System)
   function Parent_Block_Device_Name (Device : String) return String is
      Last : Natural := Device'Last;
   begin
      if Device = "" then
         return "";
      end if;

      while Last >= Device'First and then Device (Last) in '0' .. '9' loop
         Last := Last - 1;
      end loop;

      if Last >= Device'First and then Device (Last) = 'p' then
         Last := Last - 1;
      end if;

      if Last < Device'First then
         return Device;
      end if;

      return Device (Device'First .. Last);
   end Parent_Block_Device_Name;
