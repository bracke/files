separate (Files.Controller)
   function Handle_Search_Scope_Toggle
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result
   is
      Next : constant Files.Types.Search_Scope :=
        Files.Types.Next_Scope (Files.Model.Search_Scope_Of (Model));
      Had_Results : constant Boolean := Files.Model.Search_Results_Are_Active (Model);
      Has_Query   : constant Boolean := Files.Model.Filter_Text (Model) /= "";
      Operation   : Files.Operations.Operation_Result;
   begin
      Files.Model.Set_Search_Scope (Model, Next);

      case Next is
         when Files.Types.Filter_Here =>
            --  Returning to live filtering: drop any recorded search results and
            --  reload the real directory so the plain listing comes back.
            Files.Model.Clear_Search_Results (Model);
            if Had_Results then
               Operation := Files.Operations.Refresh (Model, Settings);
               return Make_Result
                 (Controller_Command_Executed, Files.Commands.Clear_Filter_Command, Operation);
            end if;
            return Make_Result (Controller_Command_Executed, Files.Commands.Clear_Filter_Command);
         when Files.Types.Search_Names =>
            if Has_Query then
               Operation := Files.Operations.Run_Recursive_Search (Model, Settings);
            elsif Had_Results then
               Operation := Files.Operations.Refresh (Model, Settings);
               Files.Model.Clear_Search_Results (Model);
               Files.Model.Set_Search_Scope (Model, Next);
            end if;
            return Make_Result
              (Controller_Command_Executed, Files.Commands.Search_Recursive_Command, Operation);
         when Files.Types.Search_Contents =>
            if Has_Query then
               Operation := Files.Operations.Run_Content_Search (Model, Settings);
            elsif Had_Results then
               Operation := Files.Operations.Refresh (Model, Settings);
               Files.Model.Clear_Search_Results (Model);
               Files.Model.Set_Search_Scope (Model, Next);
            end if;
            return Make_Result
              (Controller_Command_Executed, Files.Commands.Search_Contents_Command, Operation);
      end case;
   end Handle_Search_Scope_Toggle;
