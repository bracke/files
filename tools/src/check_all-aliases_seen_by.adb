separate (Check_All)
   function Aliases_Seen_By (Aliases, Unit : String) return String is
      Result : Unbounded_String;

      procedure Take (Line : String; Number : Positive) is
         pragma Unreferenced (Number);
         Colon : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
         Scope : constant String := Line (Line'First .. Colon - 1);
      begin
         if Unit = Scope
           or else (Unit'Length > Scope'Length
                    and then Unit (Unit'First .. Unit'First + Scope'Length) = Scope & ".")
         then
            Append (Result, Line (Colon + 1 .. Line'Last) & ASCII.LF);
         end if;
      end Take;
   begin
      For_Each_Line (Aliases, Take'Access);
      return To_String (Result);
   end Aliases_Seen_By;
