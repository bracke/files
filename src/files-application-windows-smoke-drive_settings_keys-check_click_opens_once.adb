separate (Files.Application.Windows.Smoke.Drive_Settings_Keys)
   procedure Check_Click_Opens_Once is
      Base  : constant String := Hostkit.Fs.Create_Temporary_Directory ("files-live-click");
      Inner : constant String := Hostkit.Fs.Join (Base, "inner");

      procedure Show (Path : String) is
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory
             (Path, Files.Settings.Classification_Of (Runtime.Settings),
              Files.Settings.Listing_Options_Of (Runtime.Settings));
      begin
         Files.Model.Navigate_To (Runtime.Model, Path, Load.Items);
         Render_Window (Runtime);
      end Show;

      procedure Click (Visible_Index : Positive) is
      begin
         Press_Item (Visible_Index);
         Release_Left;
         Handle_Mouse (Runtime);
         Render_Window (Runtime);
      end Click;
   begin
      if Base /= "" then
         Files.IO.Fs_Primitives.Create_Path (Hostkit.Fs.Join (Inner, "deeper"));
         Show (Base);
         Click (1);
         --  A frame between the clicks can take longer than a double
         --  click allows on a slow host: the step is about matching the
         --  clicks, not the host's speed.
         Runtime.Last_Click_Time := Ada.Real_Time.Clock;
         Click (1);
         Expect (Files.Model.Current_Path (Runtime.Model) = Files.IO.Fs_Primitives.Full_Name (Inner));
         Runtime.Last_Click_Time := Ada.Real_Time.Clock;
         Click (1);
         Expect (Files.Model.Current_Path (Runtime.Model) = Files.IO.Fs_Primitives.Full_Name (Inner));
         Runtime.Last_Click_Item := 0;
         Runtime.Last_Click_Path := Null_Unbounded_String;
         Files.Model.Replace_Items (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
         Files.IO.Fs_Primitives.Delete_Tree_If_Present (Base);
      end if;
   end Check_Click_Opens_Once;
