separate (Files_Suite.Interaction)
   procedure Test_Tree_Toggle_Command_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Folder_Tree_Command,
         Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Tree_Panel_Is_Open (Model), "the toggle command opens the folder tree");
      Assert (Files.Model.Tree_Node_Count (Model) > 0, "opening the tree seeds it with root nodes");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Panel    : constant Files.Rendering.Tree_Panel_Layout :=
           Files.Rendering.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line);
         Rows     : constant Files.Rendering.Tree_Row_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Tree_Row_Layout (Snapshot, Panel, Line);
         Target   : constant String := Files.Model.Tree_Node_Path (Model, 1);
         Expected : constant Files.File_System.Path_Result :=
           Files.File_System.Normalize_Path (Target);
         Action   : Files.Events.Input_Action;
         X, Y     : Natural := 0;
      begin
         Assert (not Rows.Is_Empty, "the open tree lays out at least one row");
         declare
            Row : constant Files.Rendering.Tree_Row_Layout := Rows.Element (1);
         begin
            X := Row.Triangle_X + Line + 2;
            Y := Row.Y + Row.Height / 2;
         end;
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Tree_Click_Input_Action,
            "a tree label coordinate translates to a tree click");
         Assert (not Action.Toggle_Selection, "clicking the label navigates rather than toggles");

         --  A tree action queued before another overlay opens must not navigate
         --  through that top-most surface.
         Files.Model.Open_Context_Menu
           (Model, X, Y, Files.Model.Context_Menu_Empty);
         declare
            Path_Before : constant String := Files.Model.Current_Path (Model);
            Revision    : constant Natural := Files.Model.Revision (Model);
         begin
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Base_Font,
               Guikit.Input.No_Modifiers, Result);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Current_Path (Model), Path_Before,
               "a delayed tree-row click is contained by the context menu (path)");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Revision (Model), Revision,
               "a delayed tree-row click is contained by the context menu (revision)");
            Assert
              (Files.Model.Context_Menu_Is_Open (Model),
               "a delayed tree-row click is contained by the context menu (menu open)");
            Files_Suite.Support.Assert_Equal
              (Result.Status, Files.Controller.Controller_Ignored,
               "a delayed tree-row click is contained by the context menu (status)");
         end;
         Files.Model.Close_Context_Menu (Model);

         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert
           (Expected.Status = Files.File_System.Path_Valid
              and then Files.Model.Current_Path (Model) = To_String (Expected.Directory_Path),
            "clicking a tree label navigates to that directory; node 1 was """
            & Target & """, which normalized to """
            & To_String (Expected.Directory_Path) & """, and we landed on """
            & Files.Model.Current_Path (Model) & """");
      end;

      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Folder_Tree_Command,
         Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "toggling again closes the folder tree");
   end Test_Tree_Toggle_Command_And_Click;
