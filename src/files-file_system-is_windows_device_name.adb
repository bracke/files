separate (Files.File_System)
function Is_Windows_Device_Name (Name : String) return Boolean is
   Base : constant String := Windows_Device_Basename (Name);

   --  COM and LPT take a digit, 0 included, or a superscript one, two or
   --  three (UTF-8 C2 B9, C2 B2, C2 B3): Windows reserves them all.
   function Is_Port_Number (Suffix : String) return Boolean is
     ((Suffix'Length = 1 and then Suffix (Suffix'First) in '0' .. '9')
      or else
        (Suffix'Length = 2
         and then Character'Pos (Suffix (Suffix'First)) = 16#C2#
         and then Character'Pos (Suffix (Suffix'Last)) in 16#B2# | 16#B3# | 16#B9#));
begin
   return Base = "CON"
     or else Base = "PRN"
     or else Base = "AUX"
     or else Base = "NUL"
     or else Base = "CONIN$"
     or else Base = "CONOUT$"
     or else
       (Base'Length in 4 .. 5
        and then (Base (Base'First .. Base'First + 2) = "COM"
                  or else Base (Base'First .. Base'First + 2) = "LPT")
        and then Is_Port_Number (Base (Base'First + 3 .. Base'Last)));
end Is_Windows_Device_Name;
