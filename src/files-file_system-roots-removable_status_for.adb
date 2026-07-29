separate (Files.File_System.Roots)
   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean
   is
      Device : constant String := Simple_Device_Name (Source);
      Parent : constant String := Parent_Block_Device_Name (Device);
      Value  : Unbounded_String;
   begin
      Known := False;
      if Device = "" or else Ada.Strings.Fixed.Index (Source, "/dev/") /= Source'First then
         return False;
      end if;

      Value := To_Unbounded_String (Read_First_Line ("/sys/block/" & Device & "/removable"));
      if To_String (Value) = "" and then Parent /= Device then
         Value := To_Unbounded_String (Read_First_Line ("/sys/block/" & Parent & "/removable"));
      end if;

      if To_String (Value) = "" then
         return False;
      end if;

      Known := True;
      return To_String (Value) = "1";
   end Removable_Status_For;
