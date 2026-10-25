separate (Files_Suite.Commands)
   procedure Test_Copy_Path_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model      : Files.Model.Window_Model := Sample_Model;
      Empty      : Files.File_System.Item_Vectors.Vector;
      Pair       : Files.File_System.Item_Vectors.Vector;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result     : Files.Controller.Controller_Result;
      Alpha_Path : constant String := Join (Root, "Alpha.txt");
      Beta_Path  : constant String := Join (Root, "Beta.txt");
      Gamma_Path : constant String := Join (Root, "Gamma.md");
   begin
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;

      --  Pure, filesystem-free join seam.
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Joined_Full_Paths (Empty),
         "",
         "an empty selection joins to empty text");
      Pair.Append (Files.File_System.Make_Item (Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
      Pair.Append (Files.File_System.Make_Item (Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Joined_Full_Paths (Pair),
         Alpha_Path & ASCII.LF & Beta_Path,
         "full paths join one per line in item order");

      --  Enablement follows the selection.
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Copy_Path_Command, Model),
         "copy-path is disabled with no selection");
      Files.Model.Select_All_Visible (Model);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Copy_Path_Command, Model),
         "copy-path is enabled with a real selection");

      --  Executing records the system-clipboard request without touching disk.
      Assert
        (not Files.Model.System_Clipboard_Request_Pending (Model),
         "no clipboard request is pending before copy-path runs");
      Files_Suite.Support.Run_Command (Files.Commands.Copy_Path_Command, Model);
      Assert
        (Files.Model.System_Clipboard_Request_Pending (Model),
         "copy-path records a pending system-clipboard request");
      Files_Suite.Support.Assert_Equal
        (Files.Model.System_Clipboard_Request_Text (Model),
         Alpha_Path & ASCII.LF & Beta_Path & ASCII.LF & Gamma_Path,
         "copy-path stores the newline-joined selection paths");
      Files.Model.Clear_System_Clipboard_Request (Model);
      Assert
        (not Files.Model.System_Clipboard_Request_Pending (Model),
         "the shell clears the request once consumed");

      --  Control+Shift+C routes to the command through the controller.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_C, Ctrl_Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Copy_Path_Command,
         "Control+Shift+C routes to copy-path");
   end Test_Copy_Path_Command;
