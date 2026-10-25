separate (Files_Suite.Interaction)
   procedure Test_Breadcrumb_Click_Navigates (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Deep     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "deep");
      Leaf     : constant String := Files_Suite.Support.Join (Deep, "leaf");
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Leaf);
      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Leaf, Settings);
      begin
         Files.Model.Initialize
           (Model,
            Directory_Path    => Leaf,
            Items             => Load.Items,
            Home_Path         => "/home/test");
      end;

      declare
         Breadcrumb_Width : constant Positive := Window_W * 2;
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Breadcrumb_Width, Window_H, Line);
         Rows     : constant Files.Rendering.Breadcrumb_Segment_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Breadcrumb_Layout (Snapshot, Breadcrumb_Width, Line);
         Action   : Files.Events.Input_Action;
         X, Y     : Natural := 0;
         Found    : Boolean := False;
      begin
         Assert (not Rows.Is_Empty, "an unfocused path bar lays out clickable breadcrumb segments");
         for Row of Rows loop
            if Row.Clickable
              and then Row.Segment_Index /= 0
              and then To_String
                         (Snapshot.Breadcrumb_Segments.Element (Row.Segment_Index).Ancestor_Path)
                       = Deep
            then
               X := Row.X + Row.Width / 2;
               Y := Row.Y + Row.Height / 2;
               Found := True;
            end if;
         end loop;
         Assert (Found, "the breadcrumb for the parent directory is laid out");
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Breadcrumb_Width, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Breadcrumb_Click_Input_Action,
            "a breadcrumb coordinate translates to a breadcrumb click");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      declare
         Expected : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Deep);
      begin
         Files_Suite.Support.Assert_Equal
           (Files.Model.Current_Path (Model),
            To_String (Expected.Directory_Path),
            "clicking the parent breadcrumb navigates to the parent directory");
      end;
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed
         and then Result.Command_Executed,
         "breadcrumb navigation reports the controller command execution");
      Assert
        (Result.Directory_Reloaded,
         "breadcrumb navigation reports the installed directory listing");
   end Test_Breadcrumb_Click_Navigates;
