separate (Files.File_System)
   function Windows_Device_Basename (Name : String) return String is
      Result : Unbounded_String;
   begin
      for Character_Value of Name loop
         exit when Character_Value = '.';
         Append (Result, Ada.Characters.Handling.To_Upper (Character_Value));
      end loop;

      declare
         Text : constant String := To_String (Result);
         Last : Natural := Text'Last;
      begin
         while Last >= Text'First and then Text (Last) = ' ' loop
            Last := Last - 1;
         end loop;

         if Last < Text'First then
            return "";
         else
            return Text (Text'First .. Last);
         end if;
      end;
   end Windows_Device_Basename;
