separate (Files.Application.Windows.Smoke.Drive_Settings_Keys)
   procedure Check_List_Keys is
   begin
      Files.Model.Replace_Items (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
      Files.Model.Set_View_Mode (Runtime.Model, Files.Preference_Types.Details);
      Files.Model.Selection.Select_Visible (Runtime.Model, 1);
      Render_Window (Runtime);
      Press (Guikit.Input.Key_End);
      Expect (Files.Model.Main_View_Scroll_Lines (Runtime.Model) > 0 and then Selected_Shown);
      Press (Guikit.Input.Key_Home);
      Expect (Files.Model.Main_View_Scroll_Lines (Runtime.Model) = 0 and then Selected_Shown);
      Press (Guikit.Input.Key_Page_Down);
      Expect (Files.Model.Selection.Selected_Index (Runtime.Model) > 2 and then Selected_Shown);

      Press (Guikit.Input.Key_Home);
      Files.Model.Selection.Select_All_Visible (Runtime.Model);
      Press_Item (2);
      Expect (Files.Model.Selection.Selected_Count (Runtime.Model) = Files.Model.Visible_Count (Runtime.Model));
      Release_Left;
      Handle_Mouse (Runtime);
      Expect (Files.Model.Selection.Selected_Count (Runtime.Model) = 1
              and then Files.Model.Selection.Selected_Index (Runtime.Model) = 2);
      Runtime.Last_Click_Item := 0;
      Runtime.Last_Click_Path := Null_Unbounded_String;
   end Check_List_Keys;
