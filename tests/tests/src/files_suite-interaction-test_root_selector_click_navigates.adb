separate (Files_Suite.Interaction)
   procedure Test_Root_Selector_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Roots    : Files.Types.String_Vectors.Vector;
      Root_A   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "root-a");
      Root_B   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "root-b");
      X, Y     : Natural := 0;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Root_A);
      Ada.Directories.Create_Path (Root_B);
      Roots.Append (Ada.Strings.Unbounded.To_Unbounded_String (Root_A));
      Roots.Append (Ada.Strings.Unbounded.To_Unbounded_String (Root_B));
      Files.Model.Open_Root_Selector (Model, Roots);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Selector : constant Files.Rendering.Root_Selector_Layout :=
           Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line);
         Rows     : constant Files.Rendering.Root_Path_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Selector);
         Action   : Files.Events.Input_Action;
      begin
         for Row of Rows loop
            if Row.Root_Index = 2 then
               X := Row.X + Row.Width / 2;
               Y := Row.Y + Row.Height / 2;
            end if;
         end loop;
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Root_Path_At (Rows, X, Y),
            2,
            "the derived coordinate hit-tests back to the second root row");
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Root_Click_Input_Action,
            "a root-row coordinate translates to a root click");
         Files_Suite.Support.Assert_Equal (Action.Root_Index, 2, "the root click carries the second root index");

         --  The command palette may be stacked above the root selector. A root
         --  row action translated before that transition must not navigate
         --  through the newer top-most overlay.
         declare
            Path_Before : constant String := Files.Model.Current_Path (Model);
         begin
            Files.Model.Open_Command_Palette (Model);
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Base_Font,
               Guikit.Input.No_Modifiers, Result);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Current_Path (Model), Path_Before,
               "a delayed root-row click is contained by the stacked palette (path)");
            Assert
              (Files.Model.Root_Selector_Is_Open (Model),
               "a delayed root-row click is contained by the stacked palette (root selector open)");
            Assert
              (Files.Model.Command_Palette_Is_Open (Model),
               "a delayed root-row click is contained by the stacked palette (palette open)");
            Files_Suite.Support.Assert_Equal
              (Result.Status, Files.Controller.Controller_Ignored,
               "a delayed root-row click is contained by the stacked palette (status)");
            Files.Model.Close_Command_Palette (Model);
         end;

         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      Files_Suite.Support.Assert_Equal

        (Files.Model.Current_Path (Model),

         Root_B,

         "the root click navigates to the chosen root");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "selecting a root closes the root selector");
   end Test_Root_Selector_Click_Navigates;
