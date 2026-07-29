separate (Files.Operations)
   function Navigate_History
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : History_Direction)
      return Operation_Result
   is
      Had_Temporary  : constant Boolean := Files.Model.Temporary_Item_Is_Active (Model);
      Temporary_Name : constant String := Files.Model.Temporary_Item_Name (Model);
      Had_Rename     : constant Boolean := Files.Model.Rename_Is_Active (Model);
      Rename_Text    : constant String := Files.Model.Rename_Text (Model);
      Rename_Source  : constant String := Files.Model.Selected_Name (Model);
      Available      : constant Boolean :=
        (if Direction = History_Back
         then Files.Model.Can_Go_Back (Model)
         else Files.Model.Can_Go_Forward (Model));
      Error_Key      : constant String :=
        (if Direction = History_Back
         then "error.history.back_unavailable"
         else "error.history.forward_unavailable");
   begin
      if not Available then
         return Disabled (Model, Error_Key);
      end if;

      if Direction = History_Back then
         Files.Model.Go_Back (Model);
      else
         Files.Model.Go_Forward (Model);
      end if;

      declare
         Reload : constant Operation_Result := Refresh (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            --  Undo the history move, then restore any interrupted rename/create.
            if Direction = History_Back then
               Files.Model.Go_Forward (Model);
            else
               Files.Model.Go_Back (Model);
            end if;
            if Had_Temporary then
               Files.Model.Begin_Create_File (Model, Temporary_Name);
            elsif Had_Rename then
               declare
                  Selection_Restored : constant Boolean :=
                    Files.Model.Select_By_Name (Model, Rename_Source);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
               Files.Model.Resume_Rename (Model, Rename_Text);
            end if;
         end if;

         return Reload;
      end;
   end Navigate_History;
