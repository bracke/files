separate (Files.File_System)
   function Is_Windows_Device_Name (Name : String) return Boolean is
      Base : constant String := Windows_Device_Basename (Name);
   begin
      return Base = "CON"
        or else Base = "PRN"
        or else Base = "AUX"
        or else Base = "NUL"
        or else Base = "CONIN$"
        or else Base = "CONOUT$"
        or else
          (Base'Length = 4
           and then (Base (Base'First .. Base'First + 2) = "COM"
                     or else Base (Base'First .. Base'First + 2) = "LPT")
           and then Base (Base'Last) in '1' .. '9');
   end Is_Windows_Device_Name;
