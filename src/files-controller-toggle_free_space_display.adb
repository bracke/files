separate (Files.Controller)
   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Updated : Files.Settings.Settings_Model := Settings;
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

      --  Display-only setting: the item list is unchanged, so there is no
      --  directory reload. The next Build_Snapshot carries the new flag, which
      --  differs from the cached snapshot and rebuilds the frame on its own.
      return
        Apply_Settings_Change
          (Files.Commands.Toggle_Free_Space_Display_Command, Model, Settings, Updated, Settings_Path);
   end Toggle_Free_Space_Display;
