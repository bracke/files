separate (Files.Rendering.Build_Frame_Commands)
   function Command_Tooltip_Text
     (Command : Files.Commands.Command_Id)
      return UString
   is
      Primary   : constant String := Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Command));
      Secondary : constant String := Files.Commands.Shortcut_Text (Files.Commands.Secondary_Shortcut_For (Command));
      Result    : UString :=
        To_Unbounded_String (Files.Localization.Text (Files.Commands.Description_Key (Command)));
   begin
      if Primary /= "" and then Secondary /= "" then
         Result :=
           Result
           & To_Unbounded_String (" (")
           & To_Unbounded_String (Primary)
           & To_Unbounded_String (" / ")
           & To_Unbounded_String (Secondary)
           & To_Unbounded_String (")");
      elsif Primary /= "" then
         Result :=
           Result
           & To_Unbounded_String (" (")
           & To_Unbounded_String (Primary)
           & To_Unbounded_String (")");
      elsif Secondary /= "" then
         Result :=
           Result
           & To_Unbounded_String (" (")
           & To_Unbounded_String (Secondary)
           & To_Unbounded_String (")");
      end if;

      return Result;
   end Command_Tooltip_Text;
