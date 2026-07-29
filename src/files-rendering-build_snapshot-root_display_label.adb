separate (Files.Rendering.Build_Snapshot)
   function Root_Display_Label
     (Path  : String;
      Label : String)
      return String is
   begin
      declare
         Separator : constant Natural := Ada.Strings.Fixed.Index (Label, "|");
      begin
         if Separator > Label'First then
            declare
               Key       : constant String := Label (Label'First .. Separator - 1);
               Tail      : constant String := Label (Separator + 1 .. Label'Last);
               Second    : constant Natural := Ada.Strings.Fixed.Index (Tail, "|");
               Value_End : constant Natural :=
                 (if Second = 0 then Tail'Last else Second - 1);
               Value     : constant String := Tail (Tail'First .. Value_End);
            begin
               if Second = 0 then
                  return
                    Files.Localization.Text (Key & ".prefix")
                    & Value
                    & Files.Localization.Text (Key & ".suffix");
               else
                  declare
                     Detail : constant String := Tail (Second + 1 .. Tail'Last);
                  begin
                     return
                       Files.Localization.Text (Key & ".prefix")
                       & Value
                       & Files.Localization.Text ("root.detail.prefix")
                       & Detail
                       & Files.Localization.Text ("root.detail.suffix")
                       & Files.Localization.Text (Key & ".suffix");
                  end;
               end if;
            end;
         end if;
      end;

      if Label'Length >= 5
        and then Label (Label'First .. Label'First + 4) = "root."
      then
         return Files.Localization.Text (Label);
      elsif Label /= "" then
         return Label;
      else
         return Path;
      end if;
   end Root_Display_Label;
