separate (Check_All)
   function Spelled_Out (Name, Aliases : String) return String is
      Standard_Prefix : constant String := "standard.";
      --  Standard.Ada.Directories is Ada.Directories.
      Plain  : constant String :=
        (if Name'Length > Standard_Prefix'Length
           and then Name (Name'First .. Name'First + Standard_Prefix'Length - 1) = Standard_Prefix
         then Name (Name'First + Standard_Prefix'Length .. Name'Last)
         else Name);
      Result : Unbounded_String := To_Unbounded_String (Plain);

      procedure Try (Line : String; Number : Positive) is
         pragma Unreferenced (Number);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Equals = 0 or else To_String (Result) /= Plain then
            return;
         end if;
         declare
            Alias : constant String := Line (Line'First .. Equals - 1);
            Unit  : constant String := Line (Equals + 1 .. Line'Last);
         begin
            if Plain = Alias then
               Result := To_Unbounded_String (Unit);
            elsif Plain'Length > Alias'Length
              and then Plain (Plain'First .. Plain'First + Alias'Length) = Alias & "."
            then
               Result := To_Unbounded_String (Unit & Plain (Plain'First + Alias'Length .. Plain'Last));
            end if;
         end;
      end Try;
   begin
      For_Each_Line (Aliases, Try'Access);
      return To_String (Result);
   end Spelled_Out;
