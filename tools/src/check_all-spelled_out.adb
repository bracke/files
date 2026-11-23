separate (Check_All)
   function Spelled_Out (Name, Aliases : String) return String is
      Result : Unbounded_String := To_Unbounded_String (Name);

      procedure Try (Line : String; Number : Positive) is
         pragma Unreferenced (Number);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Equals = 0 or else To_String (Result) /= Name then
            return;
         end if;
         declare
            Alias : constant String := Line (Line'First .. Equals - 1);
            Unit  : constant String := Line (Equals + 1 .. Line'Last);
         begin
            if Name = Alias then
               Result := To_Unbounded_String (Unit);
            elsif Name'Length > Alias'Length
              and then Name (Name'First .. Name'First + Alias'Length) = Alias & "."
            then
               Result := To_Unbounded_String (Unit & Name (Name'First + Alias'Length .. Name'Last));
            end if;
         end;
      end Try;
   begin
      For_Each_Line (Aliases, Try'Access);
      return To_String (Result);
   end Spelled_Out;
