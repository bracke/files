with Files.Items;
with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
separate (Files_Suite.Commands)
   --  What the controller cannot finish without the settings path it answers
   --  for its caller to complete, and says so: a settings command it only
   --  reports, and Enter on an overlay whose click runs through the
   --  interaction layer. Nothing is half-done in between.
   procedure Test_Controller_Leaves_Completion_To_Caller (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Controller.Controller_Status;
      use type Files.Controller.Overlay_Activation;
      use type Files.Types.Color_Label;
      use type Files.Commands.Command_Id;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.Items.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Items.Append (Files.File_System.Make_Item (Root, "a.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Selection.Select_Visible (Model, 1);

      --  A settings command without the path: reported, nothing applied ...
      declare
         Hidden_Before : constant Boolean := Settings.Show_Hidden_Files;
      begin
         Result := Files.Controller.Execute_Non_Settings_Command
           (Files.Commands.Toggle_Hidden_Files_Command, Model, Settings);
         Assert
           (Result.Status = Files.Controller.Controller_Needs_Settings_Path
            and then Result.Command = Files.Commands.Toggle_Hidden_Files_Command,
            "a settings command reached without the path asks for it, not 'executed'");
         Assert (Settings.Show_Hidden_Files = Hidden_Before, "the reported settings command changed nothing");
         --  ... until the caller completes it with the path.
         Result := Files.Controller.Complete_Settings_Command (Result, Model, Settings, "");
         Assert
           (Result.Status = Files.Controller.Controller_Command_Executed
            and then Settings.Show_Hidden_Files /= Hidden_Before,
            "completing it with the path applies the settings command");
         Result := Files.Controller.Complete_Settings_Command (Result, Model, Settings, "");
         Assert
           (Settings.Show_Hidden_Files /= Hidden_Before,
            "completing a result that asks for nothing changes nothing");
      end;

      --  Enter on the label picker asks for its highlighted swatch to be applied.
      Files.Model.Label_Picker.Open (Model);
      --  From the clear swatch (the last) onto a colour.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert
        (Result.Status = Files.Controller.Controller_Activation_Requested
         and then Result.Activation = Files.Controller.Choose_Label
         and then Result.Label = Files.Model.Label_Picker.Highlight_Color (Model)
         and then Result.Label /= Files.Types.No_Label,
         "Enter on the label picker asks for the highlighted label");
      Assert (Files.Model.Label_Picker.Is_Open (Model), "the picker stays open until the label is applied");
      Files.Model.Label_Picker.Close (Model);

      --  Enter on a highlighted context-menu row asks for that row to be run.
      Files.Model.Context_Menu.Open (Model, 10, 10, Files.Types.Context_Menu_Item);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      declare
         Rows : constant Files.Commands.Context_Menu_Rows :=
           Files.Commands.Context_Menu_Rows_For (Files.Model.Context_Menu.Target_Of (Model));
         Row  : constant Positive := Files.Model.Context_Menu.Highlight (Model);
      begin
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
         Assert
           (Result.Status = Files.Controller.Controller_Activation_Requested
            and then Result.Activation = Files.Controller.Run_Menu_Row
            and then Result.Command = Rows.Rows (Row).Command,
            "Enter on the context menu asks for the highlighted row's command");
         Assert (Files.Model.Context_Menu.Is_Open (Model), "the menu stays open until its row runs");
      end;

      --  With nothing highlighted, Enter only dismisses the menu.
      Files.Model.Context_Menu.Close (Model);
      Files.Model.Context_Menu.Open (Model, 10, 10, Files.Types.Context_Menu_Item);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert
        (Result.Activation = Files.Controller.No_Activation
         and then not Files.Model.Context_Menu.Is_Open (Model),
         "Enter on a menu with nothing highlighted closes it and runs nothing");
   end Test_Controller_Leaves_Completion_To_Caller;
