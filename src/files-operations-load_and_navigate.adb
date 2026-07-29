separate (Files.Operations)
   function Load_And_Navigate
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Path           : String;
      Close_Selector : Boolean := False)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Path);
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result
           (Operation_Failed, To_String (Path_Result.Error_Key), Path);
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return Make_Result
              (Operation_Failed,
               To_String (Load.Error_Key),
               To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Load.Path)));
         if Close_Selector then
            Files.Model.Close_Root_Selector (Model);
         end if;
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
      end;
   end Load_And_Navigate;
