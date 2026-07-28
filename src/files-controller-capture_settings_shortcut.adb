separate (Files.Controller)
   function Capture_Settings_Shortcut
     (Model     : in out Files.Model.Window_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result is
   begin
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Settings_Cancel_Capture (Model);
         return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
      elsif Key = Guikit.Input.Key_Backspace and then Modifiers = Guikit.Input.No_Modifiers then
         --  Backspace clears the binding (unbind).
         Files.Model.Settings_Set_Captured_Shortcut (Model, "");
         return Applied_Settings_Change (Model);
      elsif Key = Guikit.Input.Key_Delete and then Modifiers = Guikit.Input.No_Modifiers then
         --  Delete resets the binding to its built-in default. The armed field's
         --  key is "shortcut.<identifier>"; feeding the default's Shortcut_Text
         --  makes Apply clear the override, so a default binding persists nothing.
         declare
            Field_Key : constant String := Files.Model.Settings_Capturing_Key (Model);
            Prefix    : constant String := "shortcut.";
            function Default_Text return String is
            begin
               if Field_Key'Length > Prefix'Length
                 and then Field_Key (Field_Key'First .. Field_Key'First + Prefix'Length - 1) = Prefix
               then
                  declare
                     Id : constant Files.Commands.Command_Id :=
                       Files.Commands.Id_For_Identifier
                         (Field_Key (Field_Key'First + Prefix'Length .. Field_Key'Last));
                  begin
                     if Id in Files.Commands.Registered_Command_Id then
                        return Files.Commands.Shortcut_Text (Files.Commands.Default_Shortcut_For (Id));
                     end if;
                  end;
               end if;
               return "";
            end Default_Text;
         begin
            Files.Model.Settings_Set_Captured_Shortcut (Model, Default_Text);
         end;
         return Applied_Settings_Change (Model);
      elsif Key = Guikit.Input.Key_Unknown then
         --  A key with no chord representation: ignore it and stay armed.
         return Make_Result (Controller_Ignored);
      else
         Files.Model.Settings_Set_Captured_Shortcut
           (Model,
            Files.Commands.Shortcut_Text
              (Files.Commands.Shortcut'(Present => True, Key => Key, Modifiers => Modifiers)));
         return Applied_Settings_Change (Model);
      end if;
   end Capture_Settings_Shortcut;
