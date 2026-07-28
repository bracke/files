separate (Files.Rendering.Build_Frame_Commands)
   function Fitted_Text_For
     (Text     : UString;
      Capacity : Natural)
      return UString
   is
      Raw : constant String := To_String (Text);
   begin
      if Capacity = 0 then
         return Null_Unbounded_String;
      elsif Files.UTF8.Display_Units (Raw) <= Capacity then
         return Text;
      elsif Capacity < 2 then
         return To_Unbounded_String (Files.UTF8.Prefix_By_Units (Raw, Capacity));
      else
         declare
            Prefix  : constant String := Files.UTF8.Prefix_By_Units (Raw, Capacity - 1);
            Trimmed : constant String :=
              (if Prefix'Length > 0
                 and then (Prefix (Prefix'Last) = '.'
                           or else Prefix (Prefix'Last) = ' ')
               then Prefix (Prefix'First .. Prefix'Last - 1)
               else Prefix);
         begin
            if Trimmed = "" then
               return To_Unbounded_String (Files.UTF8.Prefix_By_Units (Raw, Capacity));
            else
               return To_Unbounded_String (Trimmed & Ellipsis_Text);
            end if;
         end;
      end if;
   end Fitted_Text_For;
