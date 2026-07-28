separate (Files.Controller)
   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Updated   : Files.Settings.Settings_Model := Settings;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      --  Cycle the field through free -> used -> bar -> free.
      if Updated.Show_Space_Bar then
         Updated.Show_Space_Bar := False;
         Updated.Show_Used_Space := False;
      elsif Updated.Show_Used_Space then
         Updated.Show_Space_Bar := True;
      else
         Updated.Show_Used_Space := True;
      end if;

      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Updated));
      if not Saved.Success then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result
           (Controller_Command_Executed, Files.Commands.Toggle_Free_Space_Display_Command, Operation);
      end if;

      --  Display-only setting: the item list is unchanged, so there is no
      --  directory reload. The next Build_Snapshot carries the new flag, which
      --  differs from the cached snapshot and rebuilds the frame on its own.
      Settings := Updated;
      Files.Model.Set_Error (Model, "");
      Operation.Status := Files.Operations.Operation_Success;
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Null_Unbounded_String;

      return Make_Result
        (Controller_Command_Executed, Files.Commands.Toggle_Free_Space_Display_Command, Operation);
   end Toggle_Free_Space_Display;
